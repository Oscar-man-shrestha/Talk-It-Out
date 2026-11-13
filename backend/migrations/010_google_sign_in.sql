-- 010_google_sign_in.sql — Sign in with Google. google_sub is Google's
-- stable account id. Accounts created through Google have no password
-- until the user sets one with "Forgot?" (password_hash becomes nullable).
ALTER TABLE users ADD COLUMN google_sub text UNIQUE;
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
