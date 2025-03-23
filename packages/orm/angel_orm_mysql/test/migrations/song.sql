CREATE TABLE IF NOT EXISTS songs (
  id serial,
  weird_join_id int,
  title varchar(255),
  created_at datetime,
  updated_at datetime,
  PRIMARY KEY(id)
);