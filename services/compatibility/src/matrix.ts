import type { Capability, Status } from './schema.ts';
import { json } from './http.ts';

interface Combination {
  model_identifier: string; os_version: string; app_version: string; helper_version: string; updated_at: string;
}
interface CountRow { capability: Capability; status: Status; count: number; userConfirmedWorking: number }
interface VerificationRow {
  id: string; capability: Capability; status: 'verifiedAvailable' | 'verifiedUnsupported';
  notes: string; source_url: string; verified_on: string;
}
/** Combinations per page; each costs two D1 queries, so pages stay small. */
export const MATRIX_PAGE_SIZE = 20;

/** `offset` pages through combinations, newest first; follow `nextOffset` until it is null. */
export async function publicMatrix(env: Env, model: string, offset = 0): Promise<Response> {
  const now = new Date().toISOString();
  const combinations = await env.DB.prepare(`SELECT model_identifier, os_version, app_version, helper_version,
    MAX(observed_at) AS updated_at FROM (
      SELECT model_identifier, os_version, app_version, helper_version, created_at AS observed_at
      FROM reports WHERE status = 'approved' AND expires_at > ?
      UNION ALL SELECT model_identifier, os_version, app_version, helper_version, verified_on AS observed_at FROM verifications
    ) WHERE (? = '' OR model_identifier = ?)
    GROUP BY model_identifier, os_version, app_version, helper_version
    ORDER BY updated_at DESC, model_identifier, os_version, app_version, helper_version LIMIT ? OFFSET ?`)
    .bind(now, model, model, MATRIX_PAGE_SIZE + 1, offset).all<Combination>();
  const groups = combinations.results.slice(0, MATRIX_PAGE_SIZE);
  const hasMore = combinations.results.length > MATRIX_PAGE_SIZE;
  const page = { truncated: hasMore, nextOffset: hasMore ? offset + MATRIX_PAGE_SIZE : null };
  if (groups.length === 0) return json({ schemaVersion: 1, generatedAt: now, groups: [], ...page });
  const statements = groups.flatMap(group => {
    const keys = [group.model_identifier, group.os_version, group.app_version, group.helper_version];
    return [
      env.DB.prepare(`SELECT json_extract(value, '$.capability') AS capability,
        json_extract(value, '$.status') AS status, COUNT(*) AS count,
        SUM(CASE WHEN json_extract(value, '$.userConfirmedWorking') = 1
          AND json_extract(value, '$.status') IN ('requestSucceeded', 'unverified') THEN 1 ELSE 0 END) AS userConfirmedWorking
        FROM reports, json_each(reports.payload, '$.capabilities')
        WHERE model_identifier = ? AND os_version = ? AND app_version = ? AND helper_version = ?
          AND reports.status = 'approved' AND expires_at > ? GROUP BY json_extract(value, '$.capability'), json_extract(value, '$.status')`)
        .bind(...keys, now),
      env.DB.prepare(`SELECT id, capability, status, notes, source_url, verified_on FROM verifications
        WHERE model_identifier = ? AND os_version = ? AND app_version = ? AND helper_version = ?`)
        .bind(...keys),
    ];
  });
  const data = await env.DB.batch<CountRow | VerificationRow>(statements);
  return json({ schemaVersion: 1, generatedAt: now, ...page,
    groups: groups.map((group, index) => ({
      modelIdentifier: group.model_identifier, macOSVersion: group.os_version,
      appVersion: group.app_version, helperVersion: group.helper_version, updatedOn: group.updated_at.slice(0, 10),
      community: data[index * 2].results,
      developerVerifications: data[index * 2 + 1].results,
    })),
  });
}
