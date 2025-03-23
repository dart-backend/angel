CREATE TABLE IF NOT EXISTS numbas (
  i int NOT NULL UNIQUE,
  parent int,
  created_at datetime,
  updated_at datetime,
  PRIMARY KEY(i)
);