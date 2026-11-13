-- The tone a contributor wants their named group messages rewritten in.
-- Private to the user (only their own profile returns it). Anonymous
-- messages always use the default, so a distinctive tone can never hint
-- at who sent one.
ALTER TABLE user_profiles
  ADD COLUMN rewrite_tone text NOT NULL DEFAULT 'professional'
    CHECK (rewrite_tone IN ('professional', 'direct', 'socratic', 'empathetic'));
