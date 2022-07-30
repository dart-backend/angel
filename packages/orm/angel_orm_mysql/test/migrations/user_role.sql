CREATE TABLE IF NOT EXISTS role_users (
  id serial PRIMARY KEY,
  user_id int NOT NULL,
  role_id int NOT NULL,
  created_at datetime,
  updated_at datetime
);