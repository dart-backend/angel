CREATE TABLE IF NOT EXISTS weird_joins (
  id serial,
  join_name varchar(255),
  PRIMARY KEY(id)
);

CREATE TABLE IF NOT EXISTS foos (
  bar varchar(255) not null UNIQUE,
  PRIMARY KEY(bar)
);

CREATE TABLE IF NOT EXISTS foo_pivots (
  weird_join_id int,
  foo_bar varchar(255)
);
