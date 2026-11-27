-- 023_answers_follows_groups.sql (API.md 65-68)
-- Feed: votes on answers, a best answer chosen by the asker, following a
-- question, and "edited" marks. Groups: a description and rules, and a
-- per-member mute and pin. Notifications also cover the feed and mentions.

CREATE TABLE comment_votes (
  comment_id uuid NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (comment_id, user_id)
);

ALTER TABLE posts
  ADD COLUMN best_comment_id uuid REFERENCES comments(id) ON DELETE SET NULL,
  ADD COLUMN edited_at timestamptz;

ALTER TABLE comments ADD COLUMN edited_at timestamptz;

CREATE TABLE post_follows (
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);
CREATE INDEX post_follows_user_idx ON post_follows (user_id);

-- Authors follow their own questions, including existing ones.
INSERT INTO post_follows (post_id, user_id)
SELECT id, author_id FROM posts
ON CONFLICT DO NOTHING;

ALTER TABLE groups
  ADD COLUMN description text NOT NULL DEFAULT '' CHECK (char_length(description) <= 500),
  ADD COLUMN rules text NOT NULL DEFAULT '' CHECK (char_length(rules) <= 1000);

ALTER TABLE group_members
  ADD COLUMN muted boolean NOT NULL DEFAULT false,
  ADD COLUMN pinned_at timestamptz;

-- Feed notifications point at a question instead of a group.
ALTER TABLE notifications
  ALTER COLUMN group_id DROP NOT NULL,
  ADD COLUMN post_id uuid REFERENCES posts(id) ON DELETE CASCADE;
ALTER TABLE notifications DROP CONSTRAINT notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
  type IN ('message_pending_review', 'message_rejected', 'mentioned', 'question_answered', 'answer_best')
);
ALTER TABLE notifications ADD CONSTRAINT notifications_target_check CHECK (
  (type IN ('question_answered', 'answer_best') AND post_id IS NOT NULL)
  OR (type NOT IN ('question_answered', 'answer_best') AND group_id IS NOT NULL)
);
