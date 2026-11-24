CREATE TABLE IF NOT EXISTS archgate_operations (
  operation_id VARCHAR(120) PRIMARY KEY,
  operation VARCHAR(120) NOT NULL,
  status VARCHAR(40) NOT NULL,
  occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
  steps JSONB NOT NULL,
  details JSONB NOT NULL
);
