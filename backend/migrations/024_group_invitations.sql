-- 024_group_invitations.sql: asking before adding someone (API.md 69).
-- A controller's "add" now invites; the person joins only by accepting.
CREATE TABLE group_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inviter_id uuid REFERENCES users(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz
);

-- At most one open invitation per person per group.
CREATE UNIQUE INDEX group_invitations_one_pending
  ON group_invitations (group_id, invitee_id) WHERE status = 'pending';
CREATE INDEX group_invitations_invitee_idx ON group_invitations (invitee_id, status);

ALTER TABLE notifications DROP CONSTRAINT notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
  type IN ('message_pending_review', 'message_rejected', 'mentioned', 'question_answered',
           'answer_best', 'group_invitation')
);
