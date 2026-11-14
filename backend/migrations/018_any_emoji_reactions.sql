-- React with any emoji, like a messaging app (Run 093). The API checks it
-- is exactly one emoji; the database only bounds the size. Still counts
-- only: who reacted is never returned.
ALTER TABLE message_reactions DROP CONSTRAINT IF EXISTS message_reactions_emoji_check;
ALTER TABLE message_reactions
  ADD CONSTRAINT message_reactions_emoji_size CHECK (octet_length(emoji) BETWEEN 1 AND 32);
