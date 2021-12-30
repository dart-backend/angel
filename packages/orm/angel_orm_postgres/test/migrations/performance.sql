CREATE TEMPORARY TABLE "world" (
  id serial NOT NULL,
  randomNumber integer NOT NULL default 0,
  PRIMARY KEY  (id)
);

CREATE TEMPORARY TABLE "fortune" (
  id serial NOT NULL,
  message varchar(2048) NOT NULL,
  PRIMARY KEY  (id)
);