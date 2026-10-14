import { boundedJSON, HttpError, json } from './http.ts';
import { reviewSchema, verificationSchema } from './schema.ts';
import { annotate, reportComparison } from './insights.ts';
import type { ReportRow } from './reports.ts';
import { findReport } from './reports.ts';

export async function reportList(env: Env, url: URL): Promise<Response> {
  const status = url.searchParams.get('status') ?? 'pending';
  if (!['pending', 'approved', 'rejected', 'all'].includes(status)) throw new HttpError(400, 'INVALID_FILTER');
  const model = (url.searchParams.get('model') ?? '').slice(0, 64);
  const version = (url.searchParams.get('appVersion') ?? '').slice(0, 40);
  const offset = Math.min(100000, Math.max(0, Math.floor(Number(url.searchParams.get('offset')) || 0)));
  const rows = await env.DB.prepare(`SELECT id, model_identifier, os_version, app_version, helper_version,
    publish_report, status, created_at, expires_at, payload FROM reports
    WHERE expires_at > ? AND (? = 'all' OR status = ?) AND (? = '' OR model_identifier = ?)
      AND (? = '' OR app_version = ?) ORDER BY created_at DESC, id LIMIT 51 OFFSET ?`)
    .bind(new Date().toISOString(), status, status, model, model, version, version, offset).all<Omit<ReportRow, 'payload_hash' | 'deletion_token_hash' | 'policy_version'>>();
  const page = rows.results.slice(0, 50);
  const annotations = await annotate(env, page);
  return json({ reports: page.map(({ payload, ...row }) => ({ ...row, ...annotations.get(row.id) })), hasMore: rows.results.length > 50, offset });
}
export async function reportDetail(env: Env, id: string): Promise<Response> {
  const row = await findReport(env, id);
  if (!row) throw new HttpError(404, 'REPORT_NOT_FOUND');
  const reviews = await env.DB.prepare("SELECT actor, status, reason, reviewed_at FROM reviews WHERE object_type = 'report' AND object_id = ? ORDER BY id DESC LIMIT 20")
    .bind(row.id).all();
  // Token/hash columns never leave D1, even in the admin API.
  return json({ report: JSON.parse(row.payload), status: row.status, publishReport: row.publish_report === 1,
    receivedAt: row.created_at, expiresAt: row.expires_at, reviews: reviews.results, comparison: await reportComparison(env, row) });
}
export async function reviewReport(request: Request, env: Env, id: string, actor: string): Promise<Response> {
  const row = await findReport(env, id);
  if (!row) throw new HttpError(404, 'REPORT_NOT_FOUND');
  const body = reviewSchema.safeParse(await boundedJSON(request, 2048));
  if (!body.success) throw new HttpError(400, 'INVALID_REVIEW');
  await env.DB.batch([
    env.DB.prepare('UPDATE reports SET status = ? WHERE id = ?').bind(body.data.status, row.id),
    env.DB.prepare(`INSERT INTO reviews (object_type, object_id, actor, status, reason, reviewed_at)
      VALUES ('report', ?, ?, ?, ?, ?)`).bind(row.id, actor, body.data.status, body.data.reason, new Date().toISOString()),
  ]);
  return json({ reportID: row.id, status: body.data.status });
}
export async function createVerification(request: Request, env: Env, actor: string): Promise<Response> {
  const body = verificationSchema.safeParse(await boundedJSON(request, 4096));
  if (!body.success || Number.isNaN(Date.parse(body.data.verifiedOn))
      || new Date(body.data.verifiedOn).toISOString().slice(0, 10) !== body.data.verifiedOn || body.data.verifiedOn > new Date().toISOString().slice(0, 10)) {
    throw new HttpError(400, 'INVALID_VERIFICATION');
  }
  const value = body.data;
  const id = crypto.randomUUID();
  await env.DB.batch([
    env.DB.prepare(`INSERT INTO verifications
      (id, model_identifier, os_version, app_version, helper_version, capability, status, notes, source_url, verified_on)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(model_identifier, os_version, app_version, helper_version, capability)
      DO UPDATE SET id = excluded.id, status = excluded.status, notes = excluded.notes,
        source_url = excluded.source_url, verified_on = excluded.verified_on`)
      .bind(id, value.modelIdentifier, value.macOSVersion, value.appVersion, value.helperVersion,
        value.capability, value.status, value.notes, value.sourceURL, value.verifiedOn),
    env.DB.prepare(`INSERT INTO reviews (object_type, object_id, actor, status, reason, reviewed_at)
      VALUES ('verification', ?, ?, ?, 'independentTest', ?)`)
      .bind(id, actor, value.status, new Date().toISOString()),
  ]);
  return json({ verificationID: id }, 201);
}
export async function deleteVerification(env: Env, id: string, actor: string): Promise<Response> {
  await env.DB.batch([
    env.DB.prepare('DELETE FROM verifications WHERE id = ?').bind(id),
    env.DB.prepare(`INSERT INTO reviews (object_type, object_id, actor, status, reason, reviewed_at)
      VALUES ('verification', ?, ?, 'removed', 'correction', ?)`).bind(id, actor, new Date().toISOString()),
  ]);
  return new Response(null, { status: 204 });
}
