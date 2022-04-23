CREATE TEMPORARY TABLE fruits (
  id serial,
  tree_id int,
  common_name varchar(255),
  created_at timestamp,
  updated_at timestamp,
  PRIMARY KEY(id)
);