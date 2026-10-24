-- 001_init.sql — initial schema for the Talk It Out backend.
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email citext UNIQUE NOT NULL,
  username text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agenda text NOT NULL,
  controller_id uuid NOT NULL REFERENCES users(id),
  source_post_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE group_members (
  group_id uuid NOT NULL REFERENCES groups(id),
  user_id uuid NOT NULL REFERENCES users(id),
  role text NOT NULL CHECK (role IN ('controller', 'contributor')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

-- A group has exactly one controller.
CREATE UNIQUE INDEX one_controller_per_group
  ON group_members (group_id) WHERE role = 'controller';

CREATE TABLE raw_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id),
  author_id uuid NOT NULL REFERENCES users(id),
  original_text text NOT NULL,
  is_anonymous boolean NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected')),
  pipeline_status text NOT NULL DEFAULT 'queued'
    CHECK (pipeline_status IN ('queued', 'processing', 'done', 'failed')),
  rewritten_text text,
  intent_preservation_score numeric(4, 3)
    CHECK (intent_preservation_score >= 0 AND intent_preservation_score <= 1),
  relevance_score numeric(4, 3)
    CHECK (relevance_score >= 0 AND relevance_score <= 1),
  relevance_label text
    CHECK (relevance_label IN ('relevant', 'borderline', 'off_topic')),
  published_message_id uuid UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by uuid REFERENCES users(id)
);

CREATE INDEX raw_messages_group_status_created_idx
  ON raw_messages (group_id, status, created_at);
CREATE INDEX raw_messages_author_idx ON raw_messages (author_id);

-- "Anonymous" here means hidden from other group members, NOT from someone
-- with database access: raw_messages still stores the author of every message.
-- This is moderation-backed anonymity, not cryptographic anonymity.
CREATE TABLE published_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id),
  author_id uuid REFERENCES users(id),
  text text NOT NULL,
  is_anonymous boolean NOT NULL,
  is_controller boolean NOT NULL DEFAULT false,
  published_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT anonymous_author_consistency CHECK (
    (is_anonymous AND author_id IS NULL)
    OR (NOT is_anonymous AND author_id IS NOT NULL)
  )
);

CREATE INDEX published_messages_group_time_idx
  ON published_messages (group_id, published_at);

-- Outbox for the (stub) rewrite pipeline. A job only references the raw
-- message id; it never stores message text or sender identity.
CREATE TABLE jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL,
  raw_message_id uuid NOT NULL REFERENCES raw_messages(id),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'running', 'done', 'failed')),
  attempts int NOT NULL DEFAULT 0,
  run_after timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX jobs_pending_idx ON jobs (status, run_after);

CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL REFERENCES users(id),
  type text NOT NULL
    CHECK (type IN ('message_pending_review', 'message_rejected')),
  ref_id uuid NOT NULL,
  group_id uuid NOT NULL REFERENCES groups(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);

CREATE INDEX notifications_recipient_idx
  ON notifications (recipient_id, created_at);
