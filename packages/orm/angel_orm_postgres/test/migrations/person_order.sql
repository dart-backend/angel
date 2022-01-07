CREATE TEMPORARY TABLE "person_orders" (
  "id" serial PRIMARY KEY,
  "person_id" int not null,
  "name" varchar(255),
  "price" int,
  "deleted" bool not null default false,
  "created_at" timestamp,
  "updated_at" timestamp
);