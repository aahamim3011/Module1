-- Minimal stand-in for the shared Auth module's users table,
-- just enough for forum_schema.sql's foreign keys to work in this demo.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    user_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) UNIQUE NOT NULL,
    username      VARCHAR(100) UNIQUE NOT NULL,
    phone_number  VARCHAR(20),
    password_hash TEXT NOT NULL,
    role          VARCHAR(20) NOT NULL DEFAULT 'end_user',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A couple of demo users to test the forum with
INSERT INTO users (email, username, password_hash) VALUES
  ('rafi@example.com', 'rafi123', 'x'),
  ('mim@example.com', 'mim_writes', 'x');
