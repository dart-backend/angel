CREATE TEMPORARY TABLE "has_cars" (
    id serial PRIMARY KEY,
    type int not null,
    color varchar(1),
    created_at timestamp,
    updated_at timestamp
);