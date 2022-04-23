CREATE TEMPORARY TABLE weird_joins (
  id serial,
  join_name varchar(255),
  PRIMARY KEY(id)
);

CREATE TEMPORARY TABLE foos (
  bar varchar(255) not null UNIQUE,
  PRIMARY KEY(bar)
);

CREATE TEMPORARY TABLE foo_pivots (
  weird_join_id int,
  foo_bar varchar(255)
);
