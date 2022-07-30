CREATE TABLE IF NOT EXISTS fruits (
  id serial,
  tree_id int,
  common_name varchar(255),
  created_at datetime,
  updated_at datetime,
  PRIMARY KEY(id)
);