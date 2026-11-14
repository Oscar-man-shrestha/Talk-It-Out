-- Password reset in three steps: email -> code -> new password. Checking
-- the code issues a one-time token (only its hash is kept here) that the
-- final step must present, so the new-password form only opens after a
-- correct code and the code itself is not needed again.
ALTER TABLE password_resets ADD COLUMN verify_token_hash text;
