import { canonical, HttpError, json, reportToken, sameHash, sha256 } from './http.ts';
import { POLICY_VERSION, RETENTION_DAYS } from './policy.ts';
import { reportSchema, validEvidence } from './schema.ts';

export interface ReportRow {
  id: string; payload: string; payload_hash: string; deletion_token_hash: string;
  publish_report: number; policy_version: string; status: string; created_at: string; expires_at: string;
}
export async function findReport(env: Env, id: string): Promise<ReportRow | null> {
  return env.DB.prepare('SELECT * FROM reports WHERE id = ? AND expires_at > ?')
    .bind(id.toLowerCase(), new Date().toISOString()).first<ReportRow>();
}
export async function submitReport(request: Request, env: Env, body: unknown): Promise<Response> {
  if (request.headers.get('X-FanBar-Policy-Version') !== POLICY_VERSION) throw new HttpError(409, 'POLICY_CHANGED');
  const visibility = request.headers.get('X-FanBar-Publish-Report');
  if (visibility !== '0' && visibility !== '1') throw new HttpError(400, 'PUBLICATION_CHOICE_REQUIRED');
  const parsed = reportSchema.safeParse(body);
  if (!parsed.success || !validEvidence(parsed.data)) throw new HttpError(400, 'INVALID_REPORT');
  const payload = parsed.data;
  payload.reportID = payload.reportID.toLowerCase();
  const id = payload.reportID;
  const text = canonical(payload);
  const hash = await sha256(canonical({ report: payload, publishReport: visibility === '1', policyVersion: POLICY_VERSION }));
  const tokenHash = await sha256(reportToken(request));
  const now = new Date();
  const expiry = new Date(now.getTime() + RETENTION_DAYS * 86400000).toISOString();
  const device = payload.device;
  const idHash = await sha256(id);
  const result = await env.DB.prepare(`INSERT INTO reports
    (id, payload, payload_hash, deletion_token_hash, model_identifier, os_version, app_version, helper_version,
     publish_report, policy_version, created_at, expires_at)
    SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
    WHERE NOT EXISTS (SELECT 1 FROM withdrawals WHERE report_id_hash = ? AND expires_at > ?)
    ON CONFLICT(id) DO NOTHING`)
    .bind(id, text, hash, tokenHash, device.modelIdentifier, device.macOSVersion, device.appVersion,
      device.helperVersion, visibility === '1' ? 1 : 0, POLICY_VERSION, now.toISOString(), expiry, idHash, now.toISOString()).run();
  const row = await findReport(env, id);
  if (!row) throw new HttpError(409, 'REPORT_WITHDRAWN');
  if (!sameHash(row.deletion_token_hash, tokenHash) || !sameHash(row.payload_hash, hash)) {
    throw new HttpError(409, 'REPORT_ID_CONFLICT');
  }
  return json(receipt(row), result.meta.changes === 1 ? 201 : 200);
}
export function receipt(row: ReportRow) {
  return { reportID: row.id, status: row.status, receivedAt: row.created_at,
    expiresAt: row.expires_at, publishReport: row.publish_report === 1, policyVersion: row.policy_version };
}
export async function ownerReceipt(request: Request, env: Env, id: string): Promise<Response> {
  const row = await findReport(env, id);
  const tokenHash = await sha256(reportToken(request));
  if (!row || !sameHash(row.deletion_token_hash, tokenHash)) throw new HttpError(404, 'REPORT_NOT_FOUND');
  return json(receipt(row));
}
export async function deleteReport(request: Request, env: Env, id: string): Promise<Response> {
  const normalized = id.toLowerCase();
  const tokenHash = await sha256(reportToken(request));
  const idHash = await sha256(normalized);
  const row = await findReport(env, normalized);
  const marker = await env.DB.prepare('SELECT deletion_token_hash FROM withdrawals WHERE report_id_hash = ?')
    .bind(idHash).first<{ deletion_token_hash: string }>();
  if ((row && !sameHash(row.deletion_token_hash, tokenHash))
      || (marker && !sameHash(marker.deletion_token_hash, tokenHash))) throw new HttpError(404, 'REPORT_NOT_FOUND');
  const expiresAt = new Date(Date.now() + RETENTION_DAYS * 86400000).toISOString();
  // Insert the marker and remove payload in one transaction; even a late POST cannot resurrect it.
  await env.DB.batch([
    env.DB.prepare(`INSERT INTO withdrawals (report_id_hash, deletion_token_hash, expires_at)
      VALUES (?, ?, ?) ON CONFLICT(report_id_hash) DO NOTHING`).bind(idHash, tokenHash, expiresAt),
    env.DB.prepare("DELETE FROM reviews WHERE object_type = 'report' AND object_id = ?").bind(normalized),
    env.DB.prepare('DELETE FROM reports WHERE id = ? AND deletion_token_hash = ?').bind(normalized, tokenHash),
  ]);
  return new Response(null, { status: 204 });
}

export async function publicReport(env: Env, id: string): Promise<Response> {
  const row = await findReport(env, id);
  if (!row || row.status !== 'approved' || row.publish_report !== 1) throw new HttpError(404, 'REPORT_NOT_FOUND');
  return json({ report: JSON.parse(row.payload), receivedOn: row.created_at.slice(0, 10), source: 'communityReport' });
}
export async function cleanup(env: Env): Promise<void> {
  const now = new Date().toISOString();
  const cutoff = new Date(Date.now() - RETENTION_DAYS * 86400000).toISOString();
  await env.DB.batch([
    env.DB.prepare(`DELETE FROM reviews WHERE (object_type = 'report' AND object_id IN
      (SELECT id FROM reports WHERE expires_at <= ?)) OR reviewed_at < ?`).bind(now, cutoff),
    env.DB.prepare('DELETE FROM reports WHERE expires_at <= ?').bind(now),
    env.DB.prepare('DELETE FROM withdrawals WHERE expires_at <= ?').bind(now),
  ]);
}
