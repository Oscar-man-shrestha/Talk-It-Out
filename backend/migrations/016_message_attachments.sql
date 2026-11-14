-- Images in group chats (Run 091). An image is uploaded first (hidden
-- metadata such as GPS and camera details is removed on the server), then
-- attached to one message. It follows that message: the controller sees it
-- in review, the group sees it only once the message is published, and it
-- is deleted when the message is rejected or deleted. uploader_id is never
-- returned by the API; it only lets the uploader attach their own image.
CREATE TABLE message_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  uploader_id uuid REFERENCES users(id) ON DELETE SET NULL,
  content_type text NOT NULL
    CHECK (content_type IN ('image/png', 'image/jpeg', 'image/webp')),
  bytes bytea NOT NULL,
  byte_size int NOT NULL CHECK (byte_size > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX message_attachments_group_idx ON message_attachments (group_id);

ALTER TABLE raw_messages
  ADD COLUMN attachment_id uuid REFERENCES message_attachments(id) ON DELETE SET NULL;
ALTER TABLE published_messages
  ADD COLUMN attachment_id uuid REFERENCES message_attachments(id) ON DELETE SET NULL;
-- One image belongs to at most one message.
CREATE UNIQUE INDEX raw_messages_attachment_uq
  ON raw_messages (attachment_id) WHERE attachment_id IS NOT NULL;
