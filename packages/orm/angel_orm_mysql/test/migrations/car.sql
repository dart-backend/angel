CREATE TABLE IF NOT EXISTS cars (
    id serial PRIMARY KEY,
    make varchar(255) NOT NULL,
    description TEXT NOT NULL,
    family_friendly BOOLEAN NOT NULL,
    recalled_at datetime,
    created_at datetime,
    updated_at datetime,
    price double
);