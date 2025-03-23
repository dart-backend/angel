CREATE TABLE "authors" (
    id serial PRIMARY KEY,
    name varchar(255) UNIQUE NOT NULL,
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE "books" (
    id serial PRIMARY KEY,
    author_id int NOT NULL,
    partner_author_id int,
    name varchar(255),
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE "cars" (
    id serial PRIMARY KEY,
    make varchar(255) NOT NULL,
    description TEXT NOT NULL,
    family_friendly BOOLEAN NOT NULL,
    recalled_at timestamp,
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE "numbers" (
    id serial PRIMARY KEY,
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE "alphabets" (
    id serial PRIMARY KEY,
    value TEXT,
    numbers_id int,
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE "feet" (
    id serial PRIMARY KEY,
    leg_id int NOT NULL,
    n_toes int NOT NULL,
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE "fruits" (
  "id" serial,
  "tree_id" int,
  "common_name" varchar,
  "created_at" timestamp,
  "updated_at" timestamp,
  PRIMARY KEY(id)
);

CREATE TABLE "has_cars" (
    id serial PRIMARY KEY,
    type int not null,
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE "has_maps" (
    id serial PRIMARY KEY,
    value jsonb not null,
    list jsonb not null,
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE "legs" (
    id serial PRIMARY KEY,
    name varchar(255) NOT NULL,
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE "roles" (
  "id" serial PRIMARY KEY,
  "name" varchar(255),
  "created_at" timestamp,
  "updated_at" timestamp
);

CREATE TABLE "trees" (
  "id" serial,
  "rings" smallint UNIQUE,
  "created_at" timestamp,
  "updated_at" timestamp,
  UNIQUE(rings),
  PRIMARY KEY(id)
);

CREATE TABLE "unorthodoxes" (
  "name" varchar(255),
  PRIMARY KEY(name)
);

CREATE TABLE "users" (
  "id" serial PRIMARY KEY,
  "username" varchar(255),
  "password" varchar(255),
  "email" varchar(255),
  "created_at" timestamp,
  "updated_at" timestamp
);

CREATE TABLE "role_users" (
  "id" serial PRIMARY KEY,
  "user_id" int NOT NULL,
  "role_id" int NOT NULL,
  "created_at" timestamp,
  "updated_at" timestamp
);

CREATE TABLE "foos" (
  "bar" varchar(255),
  PRIMARY KEY(bar)
);

CREATE TABLE "weird_joins" (
  "id" serial,
  "join_name" varchar(255) references unorthodoxes(name),
  PRIMARY KEY(id)
);

CREATE TABLE "songs" (
  "id" serial,
  "weird_join_id" int references weird_joins(id),
  "title" varchar(255),
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  PRIMARY KEY(id)
);

CREATE TABLE "numbas" (
  "i" int,
  "parent" int references weird_joins(id),
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  PRIMARY KEY(i)
);

CREATE TABLE "foo_pivots" (
  "weird_join_id" int references weird_joins(id),
  "foo_bar" varchar(255) references foos(bar)
);