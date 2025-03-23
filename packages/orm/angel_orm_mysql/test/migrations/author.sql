CREATE TABLE IF NOT EXISTS authors (
    id serial PRIMARY KEY,
    name varchar(255) UNIQUE NOT NULL,
    created_at datetime,
    updated_at datetime
);