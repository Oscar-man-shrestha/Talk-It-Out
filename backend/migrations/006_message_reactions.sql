-- 006_message_reactions.sql — emoji reactions on published group
-- messages. Reactions are by identified members; the API only ever
-- returns per-emoji counts plus the caller's own reactions, never a list
-- of who reacted. Deleting a published message removes its reactions.

CREATE TABLE message_reactions (
  message_id uuid NOT NULL REFERENCES published_messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji text NOT NULL CHECK (emoji IN ('👍', '❤️', '🔥', '💡', '👏', '🎯')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id, emoji)
);
