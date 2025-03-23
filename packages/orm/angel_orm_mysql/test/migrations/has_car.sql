CREATE TABLE IF NOT EXISTS has_cars (
    id serial PRIMARY KEY,
    type int not null,
    color varchar(1),
    created_at datetime,
    updated_at datetime
);