CREATE TABLE IF NOT EXISTS legs (
    id serial PRIMARY KEY,
    name varchar(255) NOT NULL,
    created_at timestamp,
    updated_at timestamp
);