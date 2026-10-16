import { MAXIMUM_REPORT_BYTES } from './policy.ts';

export class HttpError extends Error {
  constructor(readonly status: number, readonly code: string) { super(code); }
}
export const encoder = new TextEncoder();
export function json(value: unknown, status = 200): Response {
  return Response.json(value, { status, headers: { 'Cache-Control': 'no-store' } });
}
export async function boundedJSON(request: Request, maximum = MAXIMUM_REPORT_BYTES): Promise<unknown> {
  if (request.headers.get('Content-Type')?.split(';')[0].trim() !== 'application/json') {
    throw new HttpError(415, 'JSON_REQUIRED');
  }
  if (Number(request.headers.get('Content-Length')) > maximum) throw new HttpError(413, 'REPORT_TOO_LARGE');
  const reader = request.body?.getReader();
  if (!reader) throw new HttpError(400, 'BODY_REQUIRED');
  let size = 0;
  const chunks: Uint8Array[] = [];
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maximum) {
        await reader.cancel();
        throw new HttpError(413, 'REPORT_TOO_LARGE');
      }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const data = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { data.set(chunk, offset); offset += chunk.byteLength; }
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(data)); }
  catch { throw new HttpError(400, 'INVALID_JSON'); }
}
export async function sha256(value: string): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)));
  return Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('');
}
/**
 * Withdrawal markers are keyed by ID *and* credential, so only the owner's own
 * withdrawal blocks a late upload. A marker created with any other credential
 * cannot stop the owner from submitting or withdrawing.
 */
export function withdrawalKey(id: string, tokenHash: string): Promise<string> {
  return sha256(`${id.toLowerCase()}\n${tokenHash}`);
}
export function sameHash(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  return crypto.subtle.timingSafeEqual(encoder.encode(left), encoder.encode(right));
}
export function reportToken(request: Request): string {
  const token = request.headers.get('Authorization')?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1];
  if (!token) throw new HttpError(401, 'REPORT_CREDENTIAL_REQUIRED');
  return token;
}
export function secureResponse(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Referrer-Policy', 'no-referrer');
  headers.set('X-Frame-Options', 'DENY');
  headers.set('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'");
  return new Response(response.body, { status: response.status, headers });
}
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.entries(value).sort(([a], [b]) => a.localeCompare(b))
      .map(([key, child]) => `${JSON.stringify(key)}:${canonical(child)}`).join(',')}}`;
  }
  return JSON.stringify(value);
}
