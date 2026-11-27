-- 011_realtime_notify.sql — live updates (API.md 41).
--
-- Every change that affects what a user sees sends a small signal on the
-- Postgres channel "tio_events". Signals carry ids only, never message
-- text or authorship of anonymous messages; the API decides who may
-- receive each one and clients refetch through the normal endpoints,
-- which enforce every privacy rule. NOTIFY is delivered after COMMIT, so
-- a client never refetches data that is not visible yet, and identical
-- signals in one transaction are delivered once.
--
-- Payload keys: t = type, g = group id, u = user id, m = published
-- message id, a = raw message author id (used server-side only, never
-- forwarded), p = post id.

CREATE OR REPLACE FUNCTION tio_notify(payload jsonb) RETURNS void
LANGUAGE sql AS $$ SELECT pg_notify('tio_events', payload::text) $$;

-- Group chat: a message was published, anonymized, or deleted.
CREATE OR REPLACE FUNCTION tio_published_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM tio_notify(jsonb_build_object('t', 'chat', 'g', OLD.group_id));
  ELSE
    PERFORM tio_notify(jsonb_build_object('t', 'chat', 'g', NEW.group_id));
  END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER published_messages_notify
  AFTER INSERT OR UPDATE OR DELETE ON published_messages
  FOR EACH ROW EXECUTE FUNCTION tio_published_changed();

-- Reactions on a published message.
CREATE OR REPLACE FUNCTION tio_reaction_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  mid uuid;
  gid uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN mid := OLD.message_id; ELSE mid := NEW.message_id; END IF;
  SELECT group_id INTO gid FROM published_messages WHERE id = mid;
  -- The message itself was deleted (cascade): its chat signal covers it.
  IF gid IS NOT NULL THEN
    PERFORM tio_notify(jsonb_build_object('t', 'reaction', 'g', gid, 'm', mid));
  END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER message_reactions_notify
  AFTER INSERT OR UPDATE OR DELETE ON message_reactions
  FOR EACH ROW EXECUTE FUNCTION tio_reaction_changed();

-- Moderation: a draft was submitted, rewritten, decided, or removed.
CREATE OR REPLACE FUNCTION tio_raw_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM tio_notify(jsonb_build_object('t', 'review', 'g', OLD.group_id, 'a', OLD.author_id));
  ELSE
    PERFORM tio_notify(jsonb_build_object('t', 'review', 'g', NEW.group_id, 'a', NEW.author_id));
  END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER raw_messages_notify
  AFTER INSERT OR DELETE OR UPDATE OF status, pipeline_status, rewritten_text, decided_at
  ON raw_messages
  FOR EACH ROW EXECUTE FUNCTION tio_raw_changed();

-- Notifications for one recipient.
CREATE OR REPLACE FUNCTION tio_notification_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM tio_notify(jsonb_build_object('t', 'notif', 'u', OLD.recipient_id));
  ELSE
    PERFORM tio_notify(jsonb_build_object('t', 'notif', 'u', NEW.recipient_id));
  END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER notifications_notify
  AFTER INSERT OR UPDATE OR DELETE ON notifications
  FOR EACH ROW EXECUTE FUNCTION tio_notification_changed();

-- Membership: joined, removed, left, role changed (controller hand-over).
CREATE OR REPLACE FUNCTION tio_member_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM tio_notify(jsonb_build_object('t', 'members', 'g', OLD.group_id, 'u', OLD.user_id));
  ELSE
    PERFORM tio_notify(jsonb_build_object('t', 'members', 'g', NEW.group_id, 'u', NEW.user_id));
  END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER group_members_notify
  AFTER INSERT OR UPDATE OR DELETE ON group_members
  FOR EACH ROW EXECUTE FUNCTION tio_member_changed();

-- Public feed: posts, comments, likes (and analysis results on posts).
CREATE OR REPLACE FUNCTION tio_feed_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  pid uuid;
BEGIN
  IF TG_TABLE_NAME = 'posts' THEN
    IF TG_OP = 'DELETE' THEN pid := OLD.id; ELSE pid := NEW.id; END IF;
  ELSE
    IF TG_OP = 'DELETE' THEN pid := OLD.post_id; ELSE pid := NEW.post_id; END IF;
  END IF;
  PERFORM tio_notify(jsonb_build_object('t', 'feed', 'p', pid));
  RETURN NULL;
END $$;

CREATE TRIGGER posts_notify AFTER INSERT OR UPDATE OR DELETE ON posts
  FOR EACH ROW EXECUTE FUNCTION tio_feed_changed();
CREATE TRIGGER comments_notify AFTER INSERT OR UPDATE OR DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION tio_feed_changed();
CREATE TRIGGER post_likes_notify AFTER INSERT OR UPDATE OR DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION tio_feed_changed();

-- Sessions ended (sign out everywhere, password change or reset): live
-- streams of that user are closed.
CREATE OR REPLACE FUNCTION tio_session_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM tio_notify(jsonb_build_object('t', 'session', 'u', NEW.id));
  RETURN NULL;
END $$;

CREATE TRIGGER users_session_notify
  AFTER UPDATE OF token_version ON users
  FOR EACH ROW WHEN (OLD.token_version IS DISTINCT FROM NEW.token_version)
  EXECUTE FUNCTION tio_session_changed();
