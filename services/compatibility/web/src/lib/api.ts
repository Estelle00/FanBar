export class ApiError extends Error {
  constructor(readonly code: string, readonly status: number) { super(code); }
}

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const response = await fetch(path, { cache: 'no-store', ...options });
  if (response.status === 204) return null as T;
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new ApiError(body?.error?.code ?? 'REQUEST_FAILED', response.status);
  return body as T;
}

/* ---------- Public API shapes (see src/matrix.ts and src/admin.ts) ---------- */
export type Capability = 'cpuTemperature' | 'gpuTemperature' | 'ssdTemperature' | 'batteryTemperature'
  | 'fanReadings' | 'manualControl' | 'smartCooling';
export type CommunityStatus = 'available' | 'notApplicable' | 'notDetected' | 'temporarilyUnavailable' | 'requiresAuthorization'
  | 'unverified' | 'requestSucceeded' | 'requestFailed';
export type VerificationStatus = 'verifiedAvailable' | 'verifiedUnsupported';

export interface Verification {
  id: string; capability: Capability; status: VerificationStatus;
  notes: string; source_url: string; verified_on: string;
}
export interface MatrixGroup {
  modelIdentifier: string; macOSVersion: string; appVersion: string; helperVersion: string; updatedOn: string;
  community: { capability: Capability; status: CommunityStatus; count: number; userConfirmedWorking?: number }[];
  developerVerifications: Verification[];
}
export interface Matrix { schemaVersion: 1; generatedAt: string; truncated: boolean; groups: MatrixGroup[] }

export interface Report {
  schemaVersion: 1; reportID: string;
  device: { modelIdentifier: string; processor: string; macOSVersion: string; appVersion: string; helperVersion: string };
  fanCount?: number;
  capabilities: { capability: Capability; status: CommunityStatus; reasonCode: string; userConfirmedWorking?: true }[];
  selectedTemperatureSource: string;
}

/** GET /api/reports/:id — only reports the submitter chose to publish and that passed review. */
export interface PublicReport { report: Report; receivedOn: string; source: 'communityReport' }

export type ReviewStatus = 'pending' | 'approved' | 'rejected';
export type ReviewReason = 'reviewed' | 'duplicate' | 'invalid' | 'needsInvestigation';
export type ReviewFlag = 'conflict' | 'duplicate' | 'newModel';
export interface ReviewAnnotation { flags: ReviewFlag[]; duplicateOf: string[]; conflicts: Capability[] }
export interface AdminRow extends ReviewAnnotation {
  id: string; model_identifier: string; os_version: string; app_version: string; helper_version: string;
  publish_report: number; status: ReviewStatus; created_at: string; expires_at: string;
}
export interface AdminList { reports: AdminRow[]; hasMore: boolean; offset: number }
export interface AdminDetail {
  report: Report; status: ReviewStatus; publishReport: boolean; receivedAt: string; expiresAt: string;
  comparison: ReviewAnnotation & {
    otherApprovedReports: number;
    capabilities: { capability: Capability; status: CommunityStatus;
      existing: { status: CommunityStatus; count: number }[]; agrees: boolean | null;
      verification: { id: string; capability: Capability; status: VerificationStatus; verified_on: string } | null;
    }[];
  };
  reviews: { actor: string; status: ReviewStatus; reason: ReviewReason; reviewed_at: string }[];
}
