CREATE TABLE diagnostics (
  id TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  deletion_token_hash TEXT NOT NULL,
  model_identifier TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
CREATE INDEX diagnostics_expiry ON diagnostics(expires_at);
CREATE INDEX diagnostics_created ON diagnostics(created_at DESC);
CREATE TABLE diagnostic_withdrawals (
  id_hash TEXT PRIMARY KEY,
  deletion_token_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
