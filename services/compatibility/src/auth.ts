import { createRemoteJWKSet, jwtVerify } from 'jose';
import { HttpError, sameHash, sha256 } from './http.ts';

// One key set per isolate: jose caches and rotates the fetched keys itself, so
// admin requests don't each refetch the Access certificates.
const accessKeys = new Map<string, ReturnType<typeof createRemoteJWKSet>>();
function accessKeySet(teamDomain: string) {
  let keys = accessKeys.get(teamDomain);
  if (!keys) {
    keys = createRemoteJWKSet(new URL(`${teamDomain}/cdn-cgi/access/certs`));
    accessKeys.set(teamDomain, keys);
  }
  return keys;
}

export function localDevelopment(request: Request, env: Env): boolean {
  return env.ENVIRONMENT === 'development'
    && ['localhost', '127.0.0.1', '[::1]'].includes(new URL(request.url).hostname);
}
export async function administrator(request: Request, env: Env): Promise<string> {
  const candidate = request.headers.get('Authorization')?.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1] ?? '';
  if (env.ADMIN_TOKEN && sameHash(await sha256(candidate), await sha256(env.ADMIN_TOKEN))) {
    return 'administrator-key';
  }
  if (!env.ACCESS_AUD || !/^https:\/\/[a-z0-9-]+\.cloudflareaccess\.com$/.test(env.ACCESS_TEAM_DOMAIN)) {
    throw new HttpError(403, env.ADMIN_TOKEN ? 'ADMIN_AUTHENTICATION_REQUIRED' : 'ADMIN_ACCESS_NOT_CONFIGURED');
  }
  const token = request.headers.get('Cf-Access-Jwt-Assertion');
  if (!token) throw new HttpError(403, 'ADMIN_AUTHENTICATION_REQUIRED');
  try {
    const { payload } = await jwtVerify(token, accessKeySet(env.ACCESS_TEAM_DOMAIN), {
      issuer: env.ACCESS_TEAM_DOMAIN, audience: env.ACCESS_AUD, algorithms: ['RS256'],
    });
    if (!payload.sub) throw new Error('missing subject');
    return payload.sub;
  } catch { throw new HttpError(403, 'ADMIN_AUTHENTICATION_REQUIRED'); }
}
export function requireAdminMutation(request: Request): void {
  if (request.headers.get('X-FanBar-Admin') !== '1'
      || request.headers.get('Origin') !== new URL(request.url).origin) {
    throw new HttpError(403, 'SAME_ORIGIN_REQUIRED');
  }
}
export type Limiter = 'read' | 'write' | 'diagnostic';
export async function rateLimit(request: Request, env: Env, limiter: Limiter): Promise<void> {
  if (!env.LIMIT_SALT) throw new HttpError(503, 'SERVICE_NOT_CONFIGURED');
  const address = request.headers.get('CF-Connecting-IP') ?? (localDevelopment(request, env) ? 'local' : 'unknown');
  // This keyed daily value only reaches the short-lived limiter, never D1 or logs.
  const keyMaterial = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(env.LIMIT_SALT), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  const key = new Uint8Array(await crypto.subtle.sign(
    'HMAC', keyMaterial, new TextEncoder().encode(`${new Date().toISOString().slice(0, 10)}:${address}`)
  ));
  const binding = { read: env.READ_LIMIT, write: env.WRITE_LIMIT, diagnostic: env.DIAGNOSTIC_LIMIT }[limiter];
  const result = await binding.limit({
    key: Array.from(key, byte => byte.toString(16).padStart(2, '0')).join(''),
  });
  if (!result.success) throw new HttpError(429, 'RATE_LIMITED');
}
