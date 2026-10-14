import { z } from 'zod';
import { canonical, HttpError, json, reportToken, sameHash, sha256 } from './http.ts';
import { DIAGNOSTIC_MAXIMUM_BYTES, DIAGNOSTIC_POLICY_VERSION, DIAGNOSTIC_RETENTION_DAYS } from './policy.ts';
import { reportSchema } from './schema.ts';

export const DIAGNOSTIC_POLICY = DIAGNOSTIC_POLICY_VERSION;
/**
 * Global ceilings keep anonymous uploads from exhausting D1, which reports share.
 * Worst case stored: DIAGNOSTIC_STORED_LIMIT x 256 KiB (about 1.25 GiB).
 */
export const DIAGNOSTIC_DAILY_LIMIT = 200;
export const DIAGNOSTIC_STORED_LIMIT = 5000;
export function diagnosticPolicy(origin: string) {
  return { version: DIAGNOSTIC_POLICY, serviceOrigin: origin, retentionDays: DIAGNOSTIC_RETENTION_DAYS, maximumBytes: DIAGNOSTIC_MAXIMUM_BYTES,
    fields: ['schemaVersion', 'diagnosticID', 'capturedAt', 'device', 'helperState', 'thermal', 'fanCount', 'connectionErrorCode', 'probes', 'recentSamples', 'discovery', 'runtimeEvents', 'crashes', 'runtimeContext', 'helperLogAvailable', 'crashLogAvailable', 'helperStateSource'],
    excluded: ['serialNumber', 'hardwareUUID', 'userName', 'hostName', 'filePaths', 'processes', 'systemLogs'],
    visibility: 'administratorsOnly', contributesToCompatibilityStatistics: false, backupMaximumDays: 30,
  };
}
const temperature = z.number();
const thermalSchema = z.strictObject({
  sampledAt: z.iso.datetime(), cpuCelsius: temperature.optional(), gpuCelsius: temperature.optional(),
  ssdCelsius: temperature.optional(), batteryCelsius: temperature.optional(), hasBuiltInBattery: z.boolean().optional(),
});
const errorCode = z.number().int().min(-2147483648).max(2147483647);
export const diagnosticSchema = z.strictObject({
  schemaVersion: z.literal(1), diagnosticID: z.uuid(), capturedAt: z.iso.datetime(),
  device: reportSchema.shape.device,
  helperState: z.enum(['enabled', 'requiresApproval', 'notRegistered', 'unavailable']),
  thermal: thermalSchema.optional(),
  fanCount: z.number().int().min(0).max(8).optional(), connectionErrorCode: errorCode.optional(),
  probes: z.array(z.strictObject({
    sensor: z.enum(['cpu', 'gpu', 'ssd', 'battery', 'fan', 'unclassified']),
    key: z.string().regex(/^[A-Za-z0-9]{4}$/).optional(),
    result: z.enum(['available', 'outOfRange', 'unsupportedFormat', 'readFailed', 'serviceMissing', 'propertyMissing']),
    value: temperature.optional(), code: errorCode.optional(),
    source: z.enum(['smc', 'embeddedNVMe', 'nvmeSMART', 'smartBattery', 'batteryPack']).optional(),
    stage: z.enum(['keyInfo', 'readBytes', 'fallback', 'serviceMatch', 'propertyRead', 'decode']).optional(),
    dataType: z.string().regex(/^[0-9a-f]{8}$/).optional(), dataSize: z.number().int().min(0).max(4294967295).optional(),
    rawBytes: z.string().regex(/^(?:[0-9a-f]{2}){0,8}$/).optional(), recognized: z.boolean().optional(),
  })).max(256),
  helperStateSource: z.enum(['runtime', 'lastRecorded', 'unavailable']).optional(),
  helperLogAvailable: z.boolean().optional(), crashLogAvailable: z.boolean().optional(),
  runtimeContext: z.strictObject({
    appBuild: z.string().min(1).max(40).regex(/^[A-Za-z0-9._+-]+$/),
    osBuild: z.string().min(1).max(40).regex(/^[A-Za-z0-9._+-]+$/), architecture: z.enum(['arm64', 'x86_64']),
    bundleLocation: z.enum(['applications', 'translocated', 'other']), helperPresent: z.boolean(),
  }).optional(),
  runtimeEvents: z.array(z.strictObject({
    timestamp: z.iso.datetime(), sessionID: z.uuid(), requestID: z.uuid().optional(),
    component: z.enum(['app', 'service', 'xpc', 'control', 'helper']),
    action: z.enum(['startup', 'controllerReady', 'menuReady', 'shutdown', 'previousExitUnknown',
      'status', 'register', 'unregister', 'openSettings', 'connect', 'interrupted', 'invalidated', 'timeout',
      'fixedRPM', 'preset', 'curve', 'restoreAutomatic', 'fanCount', 'fanRead', 'readback', 'recovery', 'authorize']),
    outcome: z.enum(['observed', 'started', 'succeeded', 'failed', 'enabled', 'requiresApproval', 'notRegistered', 'unavailable', 'accepted', 'rejected']),
    code: z.number().int().optional(), value: z.number().optional(), durationMS: z.number().min(0).max(600000).optional(),
    fanIndex: z.number().int().min(0).max(7).optional(), manual: z.boolean().optional(),
  })).max(320).optional(),
  crashes: z.array(z.strictObject({
    recordedAt: z.iso.datetime(), process: z.enum(['FanBar', 'FanBarHelper', 'local.fanbar.helper']),
    exception: z.enum(['EXC_BAD_ACCESS', 'EXC_BAD_INSTRUCTION', 'EXC_CRASH', 'EXC_RESOURCE', 'EXC_BREAKPOINT', 'EXC_GUARD', 'EXC_SOFTWARE', 'other']),
    signal: z.enum(['SIGABRT', 'SIGSEGV', 'SIGBUS', 'SIGILL', 'SIGTRAP', 'SIGKILL', 'SIGTERM', 'other']),
    terminationNamespace: z.enum(['DYLD', 'SIGNAL', 'CODESIGNING', 'TCC', 'WATCHDOG', 'RUNNINGBOARD', 'LIBSYSTEM', 'other']),
    terminationCode: z.number().int().optional(),
    frames: z.array(z.strictObject({ image: z.enum(['FanBar', 'FanBarHelper', 'AppKit', 'SwiftUI', 'Foundation', 'CoreFoundation',
      'libswiftCore.dylib', 'libsystem_kernel.dylib', 'libsystem_pthread.dylib', 'libsystem_c.dylib', 'libdispatch.dylib', 'libobjc.A.dylib', 'libswift_Concurrency.dylib', 'local.fanbar.helper', 'dyld', 'other']), offset: z.number().min(0).max(1e12) })).max(20),
  })).max(3).optional(),
  recentSamples: z.array(z.strictObject({
    sampledAt: z.iso.datetime(), thermal: thermalSchema.optional(),
    fanCount: z.number().int().min(0).max(8).optional(), errorCode: errorCode.optional(),
    stage: z.enum(['connect', 'fanRead', 'sample']),
  })).max(30).optional(),
  discovery: z.strictObject({
    reportedKeyCount: z.number().int().min(0).max(4294967295).optional(),
    temperatureKeys: z.array(z.string().regex(/^T[A-Za-z0-9]{3}$/)).max(512).optional(),
    scannedKeyCount: z.number().int().min(0).max(4096), truncated: z.boolean(), errorCode: errorCode.optional(),
  }).optional(),
});
interface DiagnosticRow {
  id: string; payload: string; payload_hash: string; deletion_token_hash: string;
  model_identifier: string; created_at: string; expires_at: string;
}
async function find(env: Env, id: string) {
  return env.DB.prepare('SELECT * FROM diagnostics WHERE id = ? AND expires_at > ?')
    .bind(id.toLowerCase(), new Date().toISOString()).first<DiagnosticRow>();
}
export async function submitDiagnostic(request: Request, env: Env, body: unknown) {
  if (request.headers.get('X-FanBar-Policy-Version') !== DIAGNOSTIC_POLICY) throw new HttpError(409, 'POLICY_CHANGED');
  const parsed = diagnosticSchema.safeParse(body);
  if (!parsed.success) throw new HttpError(400, 'INVALID_DIAGNOSTIC');
  const payload = parsed.data;
  payload.diagnosticID = payload.diagnosticID.toLowerCase();
  const id = payload.diagnosticID;
  const text = canonical(payload);
  const hash = await sha256(text);
  const tokenHash = await sha256(reportToken(request));
  const idHash = await sha256(id);
  const now = new Date().toISOString();
  const dayAgo = new Date(Date.now() - 86400000).toISOString();
  const expires = new Date(Date.now() + DIAGNOSTIC_RETENTION_DAYS * 86400000).toISOString();
  // Capacity is checked inside the INSERT so concurrent uploads cannot overshoot it.
  // Retries of an already stored ID still succeed below once the ceiling is reached.
  const result = await env.DB.prepare(`INSERT INTO diagnostics
    (id, payload, payload_hash, deletion_token_hash, model_identifier, created_at, expires_at)
    SELECT ?, ?, ?, ?, ?, ?, ? WHERE NOT EXISTS
    (SELECT 1 FROM diagnostic_withdrawals WHERE id_hash = ? AND expires_at > ?)
      AND (SELECT COUNT(*) FROM diagnostics WHERE created_at > ?) < ?
      AND (SELECT COUNT(*) FROM diagnostics WHERE expires_at > ?) < ?
    ON CONFLICT(id) DO NOTHING`)
    .bind(id, text, hash, tokenHash, payload.device.modelIdentifier, now, expires, idHash, now,
      dayAgo, DIAGNOSTIC_DAILY_LIMIT, now, DIAGNOSTIC_STORED_LIMIT).run();
  const row = await find(env, id);
  if (!row) {
    const withdrawn = await env.DB.prepare('SELECT 1 FROM diagnostic_withdrawals WHERE id_hash = ? AND expires_at > ?')
      .bind(idHash, now).first();
    throw withdrawn ? new HttpError(409, 'DIAGNOSTIC_WITHDRAWN') : new HttpError(503, 'DIAGNOSTIC_CAPACITY_REACHED');
  }
  if (!sameHash(row.deletion_token_hash, tokenHash) || !sameHash(row.payload_hash, hash)) throw new HttpError(409, 'DIAGNOSTIC_ID_CONFLICT');
  return json({ reportID: id, status: 'received', receivedAt: row.created_at, expiresAt: row.expires_at,
    publishReport: false, policyVersion: DIAGNOSTIC_POLICY }, result.meta.changes === 1 ? 201 : 200);
}
export async function deleteDiagnostic(request: Request, env: Env, id: string) {
  const normalized = id.toLowerCase();
  const tokenHash = await sha256(reportToken(request));
  const idHash = await sha256(normalized);
  const row = await find(env, normalized);
  const marker = await env.DB.prepare('SELECT deletion_token_hash FROM diagnostic_withdrawals WHERE id_hash = ?')
    .bind(idHash).first<{ deletion_token_hash: string }>();
  if ((row && !sameHash(row.deletion_token_hash, tokenHash)) || (marker && !sameHash(marker.deletion_token_hash, tokenHash))) {
    throw new HttpError(404, 'DIAGNOSTIC_NOT_FOUND');
  }
  await env.DB.batch([
    env.DB.prepare(`INSERT INTO diagnostic_withdrawals (id_hash, deletion_token_hash, expires_at)
      VALUES (?, ?, ?) ON CONFLICT(id_hash) DO NOTHING`)
      .bind(idHash, tokenHash, new Date(Date.now() + DIAGNOSTIC_RETENTION_DAYS * 86400000).toISOString()),
    env.DB.prepare('DELETE FROM diagnostics WHERE id = ? AND deletion_token_hash = ?').bind(normalized, tokenHash),
  ]);
  return new Response(null, { status: 204 });
}
export async function diagnosticList(env: Env, url: URL) {
  const id = url.searchParams.get('id');
  if (id) {
    if (!z.uuid().safeParse(id).success) throw new HttpError(400, 'INVALID_DIAGNOSTIC_ID');
    const row = await find(env, id);
    if (!row) throw new HttpError(404, 'DIAGNOSTIC_NOT_FOUND');
    return json({ diagnostic: JSON.parse(row.payload), receivedAt: row.created_at, expiresAt: row.expires_at });
  }
  const rows = await env.DB.prepare(`SELECT id, model_identifier, created_at, expires_at FROM diagnostics
    WHERE expires_at > ? ORDER BY created_at DESC LIMIT 50`).bind(new Date().toISOString()).all();
  return json({ diagnostics: rows.results });
}
