-- 002_feed.sql — public feed: posts, comments, likes, feed analysis
-- tracking, and the outbox extension for feed analysis jobs.

-- The shared outbox now carries two job kinds. Groups jobs keep
-- raw_message_id; feed analysis jobs carry content_type/content_id/
-- content_revision instead — never text or identity.
ALTER TABLE jobs ALTER COLUMN raw_message_id DROP NOT NULL;
ALTER TABLE jobs
  ADD COLUMN content_type text CHECK (content_type IN ('post', 'comment')),
  ADD COLUMN content_id uuid,
  ADD COLUMN content_revision int;

ALTER TABLE jobs ADD CONSTRAINT jobs_payload_shape CHECK (
  (kind = 'process_raw_message'
    AND raw_message_id IS NOT NULL
    AND content_type IS NULL AND content_id IS NULL AND content_revision IS NULL)
  OR (kind = 'analyze_feed_content'
    AND raw_message_id IS NULL
    AND content_type IS NOT NULL AND content_id IS NOT NULL AND content_revision IS NOT NULL)
);

-- analysis_status is the source of truth for moderation state.
-- NOTE: the Flutter client's Post/Comment models currently have a non-null
-- nsfw_flag bool and cannot represent pending/failed/unavailable, so the API
-- serializes nsfw_flag=false and other_flags={} unless analysis_status is
-- 'complete'. The true status is kept here so "not analyzed yet" is never
-- conflated with "analyzed and safe" once the client grows a status field.
CREATE TABLE posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES users(id),
  content text NOT NULL,
  created_group_id uuid UNIQUE REFERENCES groups(id),
  analysis_status text NOT NULL DEFAULT 'pending'
    CHECK (analysis_status IN ('pending', 'complete', 'failed', 'unavailable')),
  analysis_nsfw boolean,
  analysis_flags jsonb NOT NULL DEFAULT '{}'::jsonb,
  analysis_provider_version text,
  content_revision int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX posts_order_idx ON posts (created_at, id);

CREATE TABLE comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id),
  author_id uuid NOT NULL REFERENCES users(id),
  content text NOT NULL,
  analysis_status text NOT NULL DEFAULT 'pending'
    CHECK (analysis_status IN ('pending', 'complete', 'failed', 'unavailable')),
  analysis_nsfw boolean,
  analysis_flags jsonb NOT NULL DEFAULT '{}'::jsonb,
  analysis_provider_version text,
  content_revision int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX comments_post_order_idx ON comments (post_id, created_at, id);

CREATE TABLE post_likes (
  post_id uuid NOT NULL REFERENCES posts(id),
  user_id uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

ALTER TABLE groups
  ADD CONSTRAINT groups_source_post_fk FOREIGN KEY (source_post_id) REFERENCES posts(id);
