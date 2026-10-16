CREATE TABLE IF NOT EXISTS decisions (
  application_id text PRIMARY KEY,
  correlation_id text,
  activity text,
  outcome text,
  reason text,
  message_id text
);
