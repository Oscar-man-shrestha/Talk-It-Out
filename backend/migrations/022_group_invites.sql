-- 022_group_invites.sql: shareable group invite links (API.md 61).
-- A controller creates a link; anyone signed in who opens it joins the
-- group as a contributor. Links can expire, have a use limit, or be revoked.
CREATE TABLE group_invites (
  code text PRIMARY KEY CHECK (code ~ '^[a-z2-9]{10}$'),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  max_uses integer CHECK (max_uses IS NULL OR max_uses BETWEEN 1 AND 1000),
  uses integer NOT NULL DEFAULT 0,
  revoked_at timestamptz
);

CREATE INDEX group_invites_group_idx ON group_invites (group_id, created_at DESC);
