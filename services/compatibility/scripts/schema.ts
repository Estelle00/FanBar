import { readFileSync, writeFileSync } from 'node:fs';
import { z } from 'zod';
import { policy } from '../src/policy.ts';
import { reportSchema } from '../src/schema.ts';
const text = JSON.stringify({
  ...z.toJSONSchema(reportSchema, { target: 'draft-7' }),
  title: 'FanBar compatibility report v1',
  description: 'Strict upload allow-list. Additional semantic evidence checks are documented in services/compatibility/PRIVACY.md.',
}, null, 2) + '\n';
for (const file of ['../../contracts/compatibility-report.schema.json', 'public/report-schema.json']) {
  if (process.argv.includes('--check')) {
    if (readFileSync(file, 'utf8') !== text) throw new Error(`Schema drift: ${file}`);
  } else { writeFileSync(file, text); }
}

const policyFile = '../../contracts/compatibility-policy.example.json';
const policyText = JSON.stringify(policy('https://report.getfanbar.com'), null, 2) + '\n';
if (process.argv.includes('--check')) {
  if (readFileSync(policyFile, 'utf8') !== policyText) throw new Error('Policy fixture drift');
} else { writeFileSync(policyFile, policyText); }
