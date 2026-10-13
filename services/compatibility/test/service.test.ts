import { env } from 'cloudflare:workers';
import { SELF } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';
import worker from '../src/index.ts';
import { cleanup } from '../src/reports.ts';
import { reportSchema, type Report } from '../src/schema.ts';
import { POLICY_VERSION } from '../src/policy.ts';
const token = 'A'.repeat(43);
function fixture(): Report {
  return {
    schemaVersion: 1, reportID: crypto.randomUUID(),
    device: { modelIdentifier: 'Mac14,13', processor: 'Test Chip', macOSVersion: '15.0.0', appVersion: '1.0', helperVersion: '10' },
    fanCount: 2, selectedTemperatureSource: 'maxChip',
    capabilities: [
      ...(['cpuTemperature', 'gpuTemperature', 'ssdTemperature', 'batteryTemperature'] as const).map(capability => ({
        capability, status: 'available' as const, reasonCode: 'SENSOR_READ_SUCCEEDED' as const,
      })),
      { capability: 'fanReadings', status: 'available', reasonCode: 'FAN_READ_SUCCEEDED' },
      { capability: 'manualControl', status: 'requestSucceeded', reasonCode: 'CONTROL_REQUEST_SUCCEEDED' },
      { capability: 'smartCooling', status: 'unverified', reasonCode: 'CONTROL_NOT_ATTEMPTED' },
    ],
  };
}
function request(path: string, method = 'GET', body?: unknown, headers: Record<string, string> = {}): Request {
  return new Request('http://localhost' + path, { method, headers: {
    'CF-Connecting-IP': crypto.randomUUID(), 'Content-Type': 'application/json', ...headers,
  }, ...(body === undefined ? {} : { body: typeof body === 'string' ? body : JSON.stringify(body) }) });
}
function submit(report: Report, publish = false, credential = token) {
  return SELF.fetch(request('/api/reports', 'POST', report, {
    Authorization: 'Bearer ' + credential, 'X-FanBar-Policy-Version': POLICY_VERSION,
    'X-FanBar-Publish-Report': publish ? '1' : '0',
  }));
}
function review(id: string, status = 'approved', origin = 'http://localhost') {
  return SELF.fetch(request('/api/admin/reports/' + id + '/review', 'PUT', { status, reason: 'reviewed' }, {
    Authorization: 'Bearer ' + env.ADMIN_TOKEN, 'X-FanBar-Admin': '1', Origin: origin,
  }));
}
async function matrix() {
  const response = await SELF.fetch(request('/api/compatibility'));
  expect(response.status).toBe(200);
  return response.json<{ groups: { community: { status: string; count: number }[]; developerVerifications: unknown[] }[] }>();
}
beforeEach(async () => { await env.DB.batch([
  env.DB.prepare('DELETE FROM reviews'), env.DB.prepare('DELETE FROM reports'), env.DB.prepare('DELETE FROM verifications'),
  env.DB.prepare('DELETE FROM withdrawals'),
]); });
describe('consent and closed schema', () => {
  it('serves every administrator entry without canonical redirect loops', async () => {
    for (const path of ['/admin', '/admin/', '/admin.html']) {
      const response = await SELF.fetch(request(path));
      expect(response.status).toBe(200);
      expect(response.headers.get('location')).toBeNull();
      expect(await response.text()).toContain('id="adminToken"');
    }
  });
  it('rejects hidden personal fields instead of silently stripping them', async () => {
    const report = fixture();
    const withSerial = { ...report, device: { ...report.device, serialNumber: 'private' } };
    expect(reportSchema.safeParse(withSerial).success).toBe(false);
    expect((await SELF.fetch(request('/api/reports', 'POST', withSerial, {
      Authorization: 'Bearer ' + token, 'X-FanBar-Policy-Version': POLICY_VERSION, 'X-FanBar-Publish-Report': '0',
    }))).status).toBe(400);
    expect(await env.DB.prepare('SELECT COUNT(*) AS count FROM reports').first('count')).toBe(0);
  });
  it('requires publication choice, current policy and owner credential', async () => {
    expect((await SELF.fetch(request('/api/reports', 'POST', fixture()))).status).toBe(409);
    expect((await SELF.fetch(request('/api/reports', 'POST', fixture(), { 'X-FanBar-Policy-Version': POLICY_VERSION }))).status).toBe(400);
    expect((await SELF.fetch(request('/api/reports', 'POST', fixture(), {
      'X-FanBar-Policy-Version': POLICY_VERSION, 'X-FanBar-Publish-Report': '0',
    }))).status).toBe(401);
  });
  it('rejects duplicate capabilities and inconsistent evidence', async () => {
    const report = fixture(); report.capabilities[0] = report.capabilities[1];
    expect((await submit(report)).status).toBe(400);
    const mismatch = fixture(); mismatch.capabilities[0].status = 'requestSucceeded';
    expect((await submit(mismatch)).status).toBe(400);
  });
  it('bounds payloads even when content length is misleading', async () => {
    const response = await SELF.fetch(request('/api/reports', 'POST', ' '.repeat(17000), {
      'Content-Length': '1', 'X-FanBar-Policy-Version': POLICY_VERSION, 'X-FanBar-Publish-Report': '0', Authorization: 'Bearer ' + token,
    }));
    expect(response.status).toBe(413);
  });
});
describe('publication and withdrawal', () => {
  it('makes retries idempotent and never returns credential hashes', async () => {
    const report = fixture(); expect((await submit(report)).status).toBe(201);
    const retry = await submit(report); expect(retry.status).toBe(200);
    const receipt = await retry.json<Record<string, unknown>>();
    expect(receipt.reportID).toBe(report.reportID);
    expect(Object.keys(receipt)).toEqual(['reportID', 'status', 'receivedAt', 'expiresAt', 'publishReport', 'policyVersion']);
    expect(await env.DB.prepare('SELECT COUNT(*) AS count FROM reports').first('count')).toBe(1);
    expect((await submit(report, true)).status).toBe(409);
    expect((await submit(report, false, 'B'.repeat(43))).status).toBe(409);
  });
  it('keeps private reports private after review while publishing aggregate evidence', async () => {
    const report = fixture(); await submit(report);
    expect((await SELF.fetch(request('/api/reports/' + report.reportID))).status).toBe(404);
    expect((await review(report.reportID)).status).toBe(200);
    expect((await SELF.fetch(request('/api/reports/' + report.reportID))).status).toBe(404);
    const data = await matrix(); expect(data.groups).toHaveLength(1);
    expect(data.groups[0].community.find(row => row.status === 'requestSucceeded')?.count).toBe(1);
    expect(data.groups[0].developerVerifications).toEqual([]);
    expect(JSON.stringify(data)).not.toContain(report.reportID);
    expect(JSON.stringify(data)).not.toContain('deletion_token');
    expect(JSON.stringify(data)).not.toContain(report.device.processor);
  });
  it('publishes opted-in reports only after review', async () => {
    const report = fixture(); await submit(report, true);
    expect((await SELF.fetch(request('/api/reports/' + report.reportID))).status).toBe(404);
    await review(report.reportID);
    const response = await SELF.fetch(request('/api/reports/' + report.reportID)); expect(response.status).toBe(200);
    expect((await response.json<{ report: Report }>()).report.reportID).toBe(report.reportID);
  });
  it('removes reports, audits and statistics only with the right credential', async () => {
    const report = fixture(); await submit(report, true); await review(report.reportID);
    expect((await SELF.fetch(request('/api/reports/' + report.reportID, 'DELETE', undefined, {
      Authorization: 'Bearer ' + 'B'.repeat(43),
    }))).status).toBe(404);
    expect((await matrix()).groups).toHaveLength(1);
    expect((await SELF.fetch(request('/api/reports/' + report.reportID, 'DELETE', undefined, { Authorization: 'Bearer ' + token }))).status).toBe(204);
    expect((await matrix()).groups).toHaveLength(0);
    expect(await env.DB.prepare('SELECT COUNT(*) AS count FROM reviews').first('count')).toBe(0);
    expect((await SELF.fetch(request('/api/reports/' + report.reportID))).status).toBe(404);
  });
  it('prevents late requests resurrecting a withdrawn report', async () => {
    const report = fixture();
    const deletion = await SELF.fetch(request('/api/reports/' + report.reportID, 'DELETE', undefined, {
      Authorization: 'Bearer ' + token,
    }));
    expect(deletion.status).toBe(204);
    expect((await submit(report)).status).toBe(409);
    expect(await env.DB.prepare('SELECT COUNT(*) AS count FROM reports').first('count')).toBe(0);
    const marker = await env.DB.prepare('SELECT * FROM withdrawals').first<Record<string, string>>();
    expect(JSON.stringify(marker)).not.toContain(report.reportID);
    expect(JSON.stringify(marker)).not.toContain(token);
  });
  it('excludes expired reports before cleanup', async () => {
    const report = fixture(); await submit(report); await review(report.reportID);
    await env.DB.prepare('UPDATE reports SET expires_at = ?').bind('2000-01-01T00:00:00.000Z').run();
    expect((await matrix()).groups).toEqual([]); await cleanup(env);
    expect(await env.DB.prepare('SELECT COUNT(*) AS count FROM reports').first('count')).toBe(0);
    expect(await env.DB.prepare('SELECT COUNT(*) AS count FROM reviews').first('count')).toBe(0);
  });
  it('preserves conflicting evidence instead of grouping by approval status', async () => {
    const first = fixture(); const second = fixture();
    second.capabilities[0] = { capability: 'cpuTemperature', status: 'notDetected', reasonCode: 'SENSOR_NOT_DETECTED' };
    await submit(first); await submit(second); await review(first.reportID); await review(second.reportID);
    expect((await matrix()).groups[0].community.some(row => row.status === 'notDetected')).toBe(true);
  });
});
describe('admin boundaries', () => {
  it('fails closed without configured production authentication', async () => {
    expect((await SELF.fetch(request('/api/admin/reports'))).status).toBe(403);
    const response = await worker.fetch(request('/api/admin/reports', 'GET', undefined, {
      Authorization: 'Bearer ' + env.ADMIN_TOKEN,
    }), { ...env, ENVIRONMENT: 'production', ADMIN_TOKEN: '' });
    expect(response.status).toBe(403);
  });
  it('rejects cross-origin admin mutations', async () => {
    const report = fixture(); await submit(report);
    expect((await review(report.reportID, 'approved', 'https://attacker.invalid')).status).toBe(403);
    expect((await matrix()).groups).toEqual([]);
  });
  it('does not leak internal columns in admin details', async () => {
    const report = fixture(); await submit(report);
    const response = await SELF.fetch(request('/api/admin/reports/' + report.reportID, 'GET', undefined, {
      Authorization: 'Bearer ' + env.ADMIN_TOKEN,
    }));
    expect(response.status).toBe(200); const text = await response.text();
    expect(text).not.toContain('payload_hash'); expect(text).not.toContain('deletion_token_hash'); expect(text).not.toContain(token);
  });
  it('keeps independent verification separate from community evidence', async () => {
    const response = await SELF.fetch(request('/api/admin/verifications', 'POST', {
      modelIdentifier: 'Mac14,13', macOSVersion: '15.0.0', appVersion: '1.0', helperVersion: '10',
      capability: 'manualControl', status: 'verifiedAvailable', notes: 'Independent controlled test',
      sourceURL: 'https://github.com/helson-lin/FanBar', verifiedOn: new Date().toISOString().slice(0, 10),
    }, { Authorization: 'Bearer ' + env.ADMIN_TOKEN, 'X-FanBar-Admin': '1', Origin: 'http://localhost' }));
    expect(response.status).toBe(201); const data = await matrix();
    expect(data.groups[0].community).toEqual([]); expect(data.groups[0].developerVerifications).toHaveLength(1);
  });
});
