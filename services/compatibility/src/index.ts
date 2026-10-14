import { administrator, localDevelopment, rateLimit, requireAdminMutation } from './auth.ts';
import { createVerification, deleteVerification, reportDetail, reportList, reviewReport } from './admin.ts';
import { boundedJSON, HttpError, json, secureResponse } from './http.ts';
import { publicMatrix } from './matrix.ts';
import { policy } from './policy.ts';
import { cleanup, deleteReport, ownerReceipt, publicReport, submitReport } from './reports.ts';

const reportPath = /^\/api\/reports\/([0-9a-f-]{36})(\/receipt)?$/i;
const adminReportPath = /^\/api\/admin\/reports\/([0-9a-f-]{36})(\/review)?$/i;
const verificationPath = /^\/api\/admin\/verifications\/([0-9a-f-]{36})$/i;
async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;
  if (path === '/api/policy' && request.method === 'GET') return json(policy(url.origin));
  if (path === '/api/reports' && request.method === 'POST') {
    await rateLimit(request, env, true);
    return submitReport(request, env, await boundedJSON(request));
  }
  const reportMatch = path.match(reportPath);
  if (reportMatch) {
    await rateLimit(request, env, request.method !== 'GET');
    if (request.method === 'DELETE' && !reportMatch[2]) return deleteReport(request, env, reportMatch[1]);
    if (request.method === 'GET') return reportMatch[2]
      ? ownerReceipt(request, env, reportMatch[1]) : publicReport(env, reportMatch[1]);
    throw new HttpError(405, 'METHOD_NOT_ALLOWED');
  }
  if (path === '/api/compatibility' && request.method === 'GET') {
    await rateLimit(request, env, false);
    const model = url.searchParams.get('model') ?? '';
    if (model.length > 64) throw new HttpError(400, 'INVALID_MODEL');
    return publicMatrix(env, model);
  }
  if (path.startsWith('/api/admin/')) {
    await rateLimit(request, env, request.method !== 'GET');
    const actor = await administrator(request, env);
    if (request.method !== 'GET') requireAdminMutation(request);
    if (path === '/api/admin/reports' && request.method === 'GET') return reportList(env, url);
    const match = path.match(adminReportPath);
    if (match && request.method === 'GET' && !match[2]) return reportDetail(env, match[1]);
    if (match && request.method === 'PUT' && match[2]) return reviewReport(request, env, match[1], actor);
    if (path === '/api/admin/verifications' && request.method === 'POST') return createVerification(request, env, actor);
    const verification = path.match(verificationPath);
    if (verification && request.method === 'DELETE') return deleteVerification(env, verification[1], actor);
    throw new HttpError(404, 'NOT_FOUND');
  }
  if (path.startsWith('/api/')) throw new HttpError(404, 'NOT_FOUND');
  if (path === '/admin' || path === '/admin/' || path === '/admin.html') {
    if (!env.ADMIN_TOKEN && !localDevelopment(request, env)) await administrator(request, env);
    const asset = new URL('/admin.html', request.url);
    const response = await env.ASSETS.fetch(new Request(asset, request));
    const headers = new Headers(response.headers);
    headers.set('Cache-Control', 'no-store');
    return new Response(response.body, { status: response.status, headers });
  }
  // HTML canonical redirects are disabled because admin routes resolve assets
  // internally. Resolve the root explicitly rather than relying on that behavior.
  if (path === '/') return env.ASSETS.fetch(new Request(new URL('/index.html', request.url), request));
  return env.ASSETS.fetch(request);
}
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try { return secureResponse(await route(request, env)); }
    catch (error) {
      if (error instanceof HttpError) {
        const response = json({ error: { code: error.code } }, error.status);
        if (error.status === 429) response.headers.set('Retry-After', '60');
        return secureResponse(response);
      }
      // Explicit logs contain no payload, credentials, request URL, IP or exception text.
      console.error(JSON.stringify({ event: 'requestFailed', code: 'INTERNAL_ERROR' }));
      return secureResponse(json({ error: { code: 'INTERNAL_ERROR' } }, 500));
    }
  },
  async scheduled(_event, env): Promise<void> { await cleanup(env); },
} satisfies ExportedHandler<Env>;
