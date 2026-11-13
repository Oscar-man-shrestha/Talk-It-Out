-- 009_token_version.sql — a per-user counter copied into every access
-- token ("tv" claim). Bumping it (sign out everywhere, password change or
-- reset) makes every existing access token invalid at once.
ALTER TABLE users ADD COLUMN token_version int NOT NULL DEFAULT 0;
