-- Minimal, private markers prevent an in-flight retry from resurrecting deleted payloads.
CREATE TABLE withdrawals (
    report_id_hash TEXT PRIMARY KEY,
    deletion_token_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL
);
CREATE INDEX withdrawals_expiry ON withdrawals(expires_at);
