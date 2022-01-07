CREATE TEMPORARY TABLE "persons" (
  "id" serial PRIMARY KEY,
  "name" varchar(255),
  "age" int,
  "created_at" timestamp,
  "updated_at" timestamp
);