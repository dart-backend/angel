CREATE TEMPORARY TABLE "feet" (
    id serial PRIMARY KEY,
    leg_id int NOT NULL,
    n_toes double precision NOT NULL,
    created_at timestamp,
    updated_at timestamp
);