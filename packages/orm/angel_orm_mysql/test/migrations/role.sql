CREATE TABLE IF NOT EXISTS roles (
  id serial PRIMARY KEY,
  name varchar(255),
  created_at datetime,
  updated_at datetime
);