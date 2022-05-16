CREATE TABLE IF NOT EXISTS trees (
  id serial,
  rings smallint UNIQUE,
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY(id)
);