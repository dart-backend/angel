CREATE TABLE IF NOT EXISTS books (
    id serial PRIMARY KEY,
    author_id int NOT NULL,
    partner_author_id int,
    name varchar(255),
    created_at datetime,
    updated_at datetime
);