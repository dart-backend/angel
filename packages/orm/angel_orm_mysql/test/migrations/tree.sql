CREATE TABLE IF NOT EXISTS trees (
  id serial,
  rings smallint UNIQUE,
  created_at datetime,
  updated_at datetime,
  PRIMARY KEY(id)
);