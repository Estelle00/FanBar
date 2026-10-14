import { HttpError, json } from './http.ts';
import type { Capability, Status } from './schema.ts';

// Review aids derived only from data already stored. They are hints for administrators,
// never automatic decisions, and they use no device identity: none is collected.

/** A pending report whose content matches another one this closely is shown as a possible duplicate. */
export const DUPLICATE_WINDOW_MINUTES = 10;
/** Accepted control requests that justify scheduling an independent developer test. */
export const VERIFICATION_CANDIDATE_MINIMUM = 5;
const CONTROL_CAPABILITIES = ['manualControl', 'smartCooling'];

export type Flag = 'conflict' | 'duplicate' | 'newModel';
interface Combination { model_identifier: string; os_version: string; app_version: string; helper_version: string }
interface AnnotatedRow extends Combination { id: string; payload: string; status: string; created_at: string }
interface Distribution { capability: Capability; status: Status; count: number }
interface Annotation { flags: Flag[]; duplicateOf: string[]; conflicts: Capability[] }

const comboKey = (row: Combination) => [row.model_identifier, row.os_version, row.app_version, row.helper_version].join('\u0000');
const now = () => new Date().toISOString();
const placeholders = (count: number) => Array.from({ length: count }, () => '?').join(', ');
function chunks<T>(items: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let index = 0; index < items.length; index += size) result.push(items.slice(index, index + size));
  return result;
}
const capabilitiesOf = (row: AnnotatedRow) =>
  (JSON.parse(row.payload) as { capabilities: { capability: Capability; status: Status }[] }).capabilities;

/**
 * Approved, unexpired community evidence per combination: report count and status distribution.
 * Combinations are matched with row values in batches, keeping the query count small and bounded
 * (D1 limits queries per invocation and bound parameters per query).
 */
async function approvedEvidence(env: Env, combinations: Combination[]) {
  const unique = [...new Map(combinations.map(row => [comboKey(row), row])).values()];
  const result = new Map<string, { reports: number; distribution: Distribution[] }>(
    unique.map(row => [comboKey(row), { reports: 0, distribution: [] }]),
  );
  const time = now();
  for (const group of chunks(unique, 20)) {
    const tuples = group.map(() => '(?, ?, ?, ?)').join(', ');
    const keys = group.flatMap(row => [row.model_identifier, row.os_version, row.app_version, row.helper_version]);
    const where = `status = 'approved' AND expires_at > ?
      AND (model_identifier, os_version, app_version, helper_version) IN (VALUES ${tuples})`;
    const [counts, distribution] = await env.DB.batch<Combination & Record<string, unknown>>([
      env.DB.prepare(`SELECT model_identifier, os_version, app_version, helper_version, COUNT(*) AS count
        FROM reports WHERE ${where} GROUP BY model_identifier, os_version, app_version, helper_version`).bind(time, ...keys),
      env.DB.prepare(`SELECT model_identifier, os_version, app_version, helper_version,
          json_extract(value, '$.capability') AS capability, json_extract(value, '$.status') AS status, COUNT(*) AS count
        FROM reports, json_each(reports.payload, '$.capabilities') WHERE reports.${where}
        GROUP BY model_identifier, os_version, app_version, helper_version,
          json_extract(value, '$.capability'), json_extract(value, '$.status')`).bind(time, ...keys),
    ]);
    for (const row of counts.results) result.get(comboKey(row))!.reports = Number(row.count);
    for (const row of distribution.results) {
      result.get(comboKey(row))!.distribution.push({
        capability: row.capability as Capability, status: row.status as Status, count: Number(row.count),
      });
    }
  }
  return result;
}

/**
 * Compare one report with the other approved reports of the same combination.
 * The report's own contribution is removed when it is already approved.
 */
function compare(row: AnnotatedRow, evidence: { reports: number; distribution: Distribution[] } | undefined) {
  const self = row.status === 'approved' ? 1 : 0;
  const others = Math.max(0, (evidence?.reports ?? 0) - self);
  return capabilitiesOf(row).map(({ capability, status }) => {
    const existing = (evidence?.distribution ?? [])
      .filter(item => item.capability === capability)
      .map(item => ({ status: item.status, count: item.count - (self && item.status === status ? 1 : 0) }))
      .filter(item => item.count > 0)
      .sort((a, b) => b.count - a.count);
    const agrees = others === 0 ? null : existing.some(item => item.status === status);
    return { capability, status, existing, agrees };
  });
}

/** Flags for a page of reports: conflicting result, likely duplicate submission, first report for a model. */
export async function annotate(env: Env, rows: AnnotatedRow[]): Promise<Map<string, Annotation>> {
  const result = new Map<string, Annotation>(rows.map(row => [row.id, { flags: [], duplicateOf: [], conflicts: [] }]));
  if (rows.length === 0) return result;
  const time = now();

  const evidence = await approvedEvidence(env, rows);
  for (const row of rows) {
    const conflicts = compare(row, evidence.get(comboKey(row))).filter(item => item.agrees === false).map(item => item.capability);
    if (conflicts.length) Object.assign(result.get(row.id)!, { conflicts }).flags.push('conflict');
  }

  // D1 allows 100 bound parameters per statement; ids are queried in chunks.
  for (const ids of chunks(rows.map(row => row.id), 40)) {
    const duplicates = await env.DB.prepare(`SELECT r.id AS id, o.id AS other FROM reports r JOIN reports o
        ON o.id <> r.id AND o.model_identifier = r.model_identifier AND o.os_version = r.os_version
        AND o.app_version = r.app_version AND o.helper_version = r.helper_version AND o.expires_at > ?
        AND json_remove(o.payload, '$.reportID') = json_remove(r.payload, '$.reportID')
        AND abs(julianday(o.created_at) - julianday(r.created_at)) * 1440 <= ?
      WHERE r.id IN (${placeholders(ids.length)}) ORDER BY o.created_at`)
      .bind(time, DUPLICATE_WINDOW_MINUTES, ...ids).all<{ id: string; other: string }>();
    for (const item of duplicates.results) result.get(item.id)!.duplicateOf.push(item.other);
  }
  for (const [, annotation] of result) if (annotation.duplicateOf.length) annotation.flags.push('duplicate');

  const models = [...new Set(rows.map(row => row.model_identifier))];
  const known = new Set<string>();
  for (const group of chunks(models, 40)) {
    const found = await env.DB.prepare(`SELECT model_identifier FROM reports
        WHERE status = 'approved' AND expires_at > ? AND model_identifier IN (${placeholders(group.length)})
      UNION SELECT model_identifier FROM verifications WHERE model_identifier IN (${placeholders(group.length)})`)
      .bind(time, ...group, ...group).all<{ model_identifier: string }>();
    for (const item of found.results) known.add(item.model_identifier);
  }
  for (const row of rows) if (row.status === 'pending' && !known.has(row.model_identifier)) result.get(row.id)!.flags.push('newModel');
  return result;
}

/** Comparison with existing records for the admin report detail. */
export async function reportComparison(env: Env, row: AnnotatedRow) {
  const evidence = await approvedEvidence(env, [row]);
  const verifications = await env.DB.prepare(`SELECT id, capability, status, verified_on FROM verifications
    WHERE model_identifier = ? AND os_version = ? AND app_version = ? AND helper_version = ?`)
    .bind(row.model_identifier, row.os_version, row.app_version, row.helper_version)
    .all<{ id: string; capability: Capability; status: string; verified_on: string }>();
  const annotation = (await annotate(env, [row])).get(row.id)!;
  const self = row.status === 'approved' ? 1 : 0;
  return {
    otherApprovedReports: Math.max(0, (evidence.get(comboKey(row))?.reports ?? 0) - self),
    capabilities: compare(row, evidence.get(comboKey(row))).map(item => ({
      ...item, verification: verifications.results.find(verification => verification.capability === item.capability) ?? null,
    })),
    ...annotation,
  };
}

/** Combinations with enough accepted control requests and no independent test yet. */
async function verificationCandidates(env: Env, limit = 50) {
  const rows = await env.DB.prepare(`SELECT model_identifier AS modelIdentifier, os_version AS macOSVersion,
      app_version AS appVersion, helper_version AS helperVersion, json_extract(value, '$.capability') AS capability,
      COUNT(*) AS reports, MAX(created_at) AS lastReportAt
    FROM reports, json_each(reports.payload, '$.capabilities')
    WHERE reports.status = 'approved' AND expires_at > ?
      AND json_extract(value, '$.capability') IN (${placeholders(CONTROL_CAPABILITIES.length)})
      AND json_extract(value, '$.status') = 'requestSucceeded'
      AND NOT EXISTS (SELECT 1 FROM verifications v WHERE v.model_identifier = reports.model_identifier
        AND v.os_version = reports.os_version AND v.app_version = reports.app_version
        AND v.helper_version = reports.helper_version AND v.capability = json_extract(value, '$.capability'))
    GROUP BY model_identifier, os_version, app_version, helper_version, json_extract(value, '$.capability')
    HAVING COUNT(*) >= ? ORDER BY reports DESC, lastReportAt DESC LIMIT ?`)
    .bind(now(), ...CONTROL_CAPABILITIES, VERIFICATION_CANDIDATE_MINIMUM, limit).all();
  return rows.results;
}

export async function verificationList(env: Env): Promise<Response> {
  const verifications = await env.DB.prepare(`SELECT id, model_identifier AS modelIdentifier, os_version AS macOSVersion,
      app_version AS appVersion, helper_version AS helperVersion, capability, status, notes,
      source_url AS sourceURL, verified_on AS verifiedOn FROM verifications
    ORDER BY verified_on DESC, model_identifier, capability LIMIT 200`).all();
  return json({
    verifications: verifications.results,
    candidates: await verificationCandidates(env),
    candidateMinimum: VERIFICATION_CANDIDATE_MINIMUM,
  });
}

/* ---------- Audit ---------- */
async function auditEntries(env: Env, options: { type: string; offset: number; limit: number }) {
  const rows = await env.DB.prepare(`SELECT reviews.id AS id, object_type AS objectType, object_id AS objectID,
      actor, reviews.status AS status, reason, reviewed_at AS reviewedAt,
      COALESCE(reports.model_identifier, verifications.model_identifier) AS modelIdentifier
    FROM reviews
      LEFT JOIN reports ON object_type = 'report' AND reports.id = object_id
      LEFT JOIN verifications ON object_type = 'verification' AND verifications.id = object_id
    WHERE (? = 'all' OR object_type = ?)
    ORDER BY reviews.id DESC LIMIT ? OFFSET ?`)
    .bind(options.type, options.type, options.limit + 1, options.offset).all();
  return { entries: rows.results.slice(0, options.limit), hasMore: rows.results.length > options.limit };
}

export async function auditLog(env: Env, url: URL): Promise<Response> {
  const type = url.searchParams.get('type') ?? 'all';
  if (!['all', 'report', 'verification'].includes(type)) throw new HttpError(400, 'INVALID_FILTER');
  const offset = Math.min(100000, Math.max(0, Math.floor(Number(url.searchParams.get('offset')) || 0)));
  return json({ ...(await auditEntries(env, { type, offset, limit: 50 })), offset });
}

/* ---------- Overview ---------- */
export async function overview(env: Env): Promise<Response> {
  const time = new Date();
  const iso = time.toISOString();
  const day = 86400000;
  const weekAgo = new Date(time.getTime() - 7 * day).toISOString();
  const twoWeeksAgo = new Date(time.getTime() - 14 * day).toISOString();
  const firstDay = new Date(Date.UTC(time.getUTCFullYear(), time.getUTCMonth(), time.getUTCDate()) - 13 * day);

  const [queue, received, decisions, daily] = await env.DB.batch<Record<string, unknown>>([
    env.DB.prepare(`SELECT COUNT(*) AS pending, MIN(created_at) AS oldest FROM reports
      WHERE status = 'pending' AND expires_at > ?`).bind(iso),
    env.DB.prepare(`SELECT SUM(created_at > ?) AS thisWeek, SUM(created_at <= ? AND created_at > ?) AS previousWeek
      FROM reports WHERE expires_at > ? AND created_at > ?`).bind(weekAgo, weekAgo, twoWeeksAgo, iso, twoWeeksAgo),
    env.DB.prepare(`SELECT status, COUNT(*) AS count FROM reviews
      WHERE object_type = 'report' AND reviewed_at > ? AND status IN ('approved', 'rejected') GROUP BY status`).bind(weekAgo),
    env.DB.prepare(`SELECT substr(created_at, 1, 10) AS date, COUNT(*) AS count FROM reports
      WHERE expires_at > ? AND created_at >= ? GROUP BY substr(created_at, 1, 10)`).bind(iso, firstDay.toISOString()),
  ]);

  const counts = new Map((daily.results as { date: string; count: number }[]).map(item => [item.date, item.count]));
  const decided = new Map((decisions.results as { status: string; count: number }[]).map(item => [item.status, item.count]));

  // Review aids for the oldest pending reports; the queue is processed oldest first.
  const pending = await env.DB.prepare(`SELECT id, payload, status, created_at, model_identifier, os_version, app_version,
      helper_version FROM reports WHERE status = 'pending' AND expires_at > ? ORDER BY created_at, id LIMIT 100`)
    .bind(iso).all<AnnotatedRow>();
  const annotations = await annotate(env, pending.results);
  const attention = (flag: Flag) => pending.results
    .filter(row => annotations.get(row.id)!.flags.includes(flag))
    .slice(0, 10)
    .map(row => {
      const annotation = annotations.get(row.id)!;
      return {
        reportID: row.id, modelIdentifier: row.model_identifier, macOSVersion: row.os_version,
        appVersion: row.app_version, helperVersion: row.helper_version, receivedAt: row.created_at,
        ...(flag === 'duplicate' ? { duplicateOf: annotation.duplicateOf } : {}),
        ...(flag === 'conflict' ? { capabilities: annotation.conflicts } : {}),
      };
    });

  const candidates = await verificationCandidates(env, 10);
  const row = queue.results[0] as { pending: number; oldest: string | null };
  const week = received.results[0] as { thisWeek: number | null; previousWeek: number | null };
  return json({
    generatedAt: iso,
    queue: { pending: row.pending, oldestPendingAt: row.oldest, inspected: pending.results.length },
    week: {
      received: week.thisWeek ?? 0, receivedPrevious: week.previousWeek ?? 0,
      approved: decided.get('approved') ?? 0, rejected: decided.get('rejected') ?? 0,
    },
    daily: Array.from({ length: 14 }, (_, index) => {
      const date = new Date(firstDay.getTime() + index * day).toISOString().slice(0, 10);
      return { date, count: counts.get(date) ?? 0 };
    }),
    attention: {
      conflicts: attention('conflict'), duplicates: attention('duplicate'), newModels: attention('newModel'),
      verificationCandidates: candidates,
    },
    recent: (await auditEntries(env, { type: 'all', offset: 0, limit: 5 })).entries,
  });
}
