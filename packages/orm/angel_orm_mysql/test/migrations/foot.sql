CREATE TABLE IF NOT EXISTS feet (
    id serial PRIMARY KEY,
    leg_id int NOT NULL,
    n_toes double precision NOT NULL,
    created_at datetime,
    updated_at datetime
);