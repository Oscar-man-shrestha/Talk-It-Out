-- 021_blocks_and_post_reports.sql: blocking people and reporting questions
-- (API.md 59, 60).

-- A block hides both people from each other in search, suggestions, the
-- feed, comments and profiles, and stops either adding the other to a
-- group. It does not change groups they already share.
CREATE TABLE user_blocks (
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE INDEX user_blocks_blocked_idx ON user_blocks (blocked_id);

-- A report hides the question from the reporter at once. Enough distinct
-- reports hide it from everyone except its author (threshold in the API).
CREATE TABLE post_reports (
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (
    reason IN ('spam', 'harassment', 'hate', 'self_harm', 'misinformation', 'other')
  ),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, reporter_id)
);
