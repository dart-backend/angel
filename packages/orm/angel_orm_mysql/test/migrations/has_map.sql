CREATE TABLE IF NOT EXISTS has_maps (
    id serial PRIMARY KEY,
    value jsonb not null,
    list jsonb not null,
    created_at datetime,
    updated_at datetime
);