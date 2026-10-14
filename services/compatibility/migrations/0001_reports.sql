-- Only allow-listed compatibility data lives here. No raw logs, IPs or device IDs.
CREATE TABLE reports (
    id TEXT PRIMARY KEY,
    payload TEXT NOT NULL CHECK (json_valid(payload)),
    payload_hash TEXT NOT NULL,
    deletion_token_hash TEXT NOT NULL,
    model_identifier TEXT NOT NULL,
    os_version TEXT NOT NULL,
    app_version TEXT NOT NULL,
    helper_version TEXT NOT NULL,
    publish_report INTEGER NOT NULL CHECK (publish_report IN (0, 1)),
    policy_version TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL
);
CREATE INDEX reports_combination ON reports(model_identifier, os_version, app_version, helper_version, status);
CREATE INDEX reports_expiry ON reports(expires_at);
CREATE INDEX reports_review_queue ON reports(status, created_at);

-- Independently tested conclusions are distinct from user-submitted requests.
CREATE TABLE verifications (
    id TEXT PRIMARY KEY,
    model_identifier TEXT NOT NULL,
    os_version TEXT NOT NULL,
    app_version TEXT NOT NULL,
    helper_version TEXT NOT NULL,
    capability TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('verifiedAvailable', 'verifiedUnsupported')),
    notes TEXT NOT NULL,
    source_url TEXT NOT NULL,
    verified_on TEXT NOT NULL,
    UNIQUE(model_identifier, os_version, app_version, helper_version, capability)
);

-- Audit only administrative decisions, not user identities or deletion credentials.
CREATE TABLE reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    object_type TEXT NOT NULL CHECK (object_type IN ('report', 'verification')),
    object_id TEXT NOT NULL,
    actor TEXT NOT NULL,
    status TEXT NOT NULL,
    reason TEXT NOT NULL,
    reviewed_at TEXT NOT NULL
);
