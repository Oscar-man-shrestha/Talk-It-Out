-- Chat upgrades (Run 092): replies, rewrite previews, pins and polls.

-- Replies point at a published message (already public to the group).
ALTER TABLE raw_messages
  ADD COLUMN reply_to_id uuid REFERENCES published_messages(id) ON DELETE SET NULL;
ALTER TABLE published_messages
  ADD COLUMN reply_to_id uuid REFERENCES published_messages(id) ON DELETE SET NULL;

-- A preview is a draft the sender asked the AI to rewrite BEFORE sending.
-- It goes through the same worker path as a real message but is invisible
-- to the controller (no queue, counts, notification or review access).
-- Sending turns it into a normal pending message; unsent previews are
-- deleted after an hour.
ALTER TABLE raw_messages ADD COLUMN is_preview boolean NOT NULL DEFAULT false;
CREATE INDEX raw_messages_preview_idx ON raw_messages (author_id) WHERE is_preview;

-- Pinned messages (controller only).
ALTER TABLE published_messages ADD COLUMN pinned_at timestamptz;

-- Polls: posted by the controller as a published message. Votes are
-- counted, never shown per person.
CREATE TABLE polls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL UNIQUE REFERENCES published_messages(id) ON DELETE CASCADE,
  options text[] NOT NULL CHECK (cardinality(options) BETWEEN 2 AND 6),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE poll_votes (
  poll_id uuid NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  voter_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  option_index int NOT NULL CHECK (option_index >= 0 AND option_index < 6),
  voted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (poll_id, voter_id)
);

-- Live updates when a message is pinned or a vote changes.
CREATE OR REPLACE FUNCTION tio_poll_vote_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  gid uuid;
BEGIN
  SELECT p.group_id INTO gid
  FROM polls po JOIN published_messages p ON p.id = po.message_id
  WHERE po.id = CASE WHEN TG_OP = 'DELETE' THEN OLD.poll_id ELSE NEW.poll_id END;
  IF gid IS NOT NULL THEN
    PERFORM tio_notify(jsonb_build_object('t', 'chat', 'g', gid));
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER poll_votes_notify AFTER INSERT OR UPDATE OR DELETE ON poll_votes
  FOR EACH ROW EXECUTE FUNCTION tio_poll_vote_changed();
