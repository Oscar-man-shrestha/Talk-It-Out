-- 019_discovery.sql: people search, chosen @handles, interests and feed
-- signals (API.md 52 to 56).

-- Trigram matching for fuzzy people search. pg_trgm is a trusted
-- extension, so the database owner can create it.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Usernames were derived from the email local-part and never shown.
-- A user now chooses a public @handle; until then the derived username
-- stays private (search matches it only exactly, as before).
ALTER TABLE users ADD COLUMN username_chosen boolean NOT NULL DEFAULT false;

CREATE INDEX users_name_trgm_idx ON users USING gin (lower(name) gin_trgm_ops);
CREATE INDEX users_username_trgm_idx ON users USING gin (lower(username) gin_trgm_ops);

-- Interests a user picked (the feed learns the rest from feed signals).
CREATE TABLE user_interests (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  interest text NOT NULL CHECK (interest ~ '^[a-z_]{2,40}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, interest)
);

-- True once the user has been through the interest picker, even if they
-- skipped it, so the picker is not shown again.
ALTER TABLE users ADD COLUMN interests_set_at timestamptz;

-- Public-feed signals. One row per (user, post, kind); repeating an action
-- only moves created_at. Never written for group or anonymous messages.
CREATE TABLE feed_events (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('open', 'save', 'not_interested')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id, kind)
);

CREATE INDEX feed_events_user_idx ON feed_events (user_id, created_at DESC);

-- A sound-alike key per name word, so search finds "Rohan" for "rhoan"
-- (swapped letters share almost no trigrams). Mirrors phoneticKey() in
-- src/nlp/fuzzy.ts closely enough to find candidates; the exact score is
-- computed in the API.
CREATE FUNCTION talk_sound(word text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT CASE WHEN w = '' THEN ''
              ELSE regexp_replace(left(w, 1) || regexp_replace(substr(w, 2), '[aeiou]', '', 'g'),
                                  '(.)\1+', '\1', 'g')
         END
  FROM (
    SELECT translate(
             regexp_replace(
               regexp_replace(
                 regexp_replace(
                   regexp_replace(
                     regexp_replace(
                       regexp_replace(
                         regexp_replace(lower(word), '[^a-z]', '', 'g'),
                       'ph', 'f', 'g'),
                     'ck', 'k', 'g'),
                   'q', 'k', 'g'),
                 'x', 'ks', 'g'),
               'c([eiy])', 's\1', 'g'),
             'c', 'k', 'g'),
           'zwy', 'svi') AS w0
  ) a,
  LATERAL (SELECT regexp_replace(w0, '([kgtdbsj])h', '\1', 'g') AS w) b
$$;

CREATE FUNCTION talk_name_sounds(name text) RETURNS text[]
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT coalesce(array_agg(s) FILTER (WHERE s <> ''), '{}')
  FROM (SELECT talk_sound(part) AS s
        FROM regexp_split_to_table(name, '\s+') AS part) t
$$;

CREATE INDEX users_name_sounds_idx ON users USING gin (talk_name_sounds(name));
