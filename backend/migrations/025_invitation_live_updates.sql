-- 025_invitation_live_updates.sql: live updates for group invitations.
-- Sending, accepting, declining or cancelling an invitation sends the same
-- 'members' signal as a membership change (011), so the controller's
-- "Invited (n)" list and the invited person's Groups screen refresh at once.
-- The signal carries only the group and the invited user's id; the hub turns
-- it into a 'groups' event for that user and 'members' events (group id only)
-- for connected members, so no one learns who was invited from the event.
CREATE OR REPLACE FUNCTION tio_invitation_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM tio_notify(jsonb_build_object('t', 'members', 'g', NEW.group_id, 'u', NEW.invitee_id));
  RETURN NULL;
END $$;

CREATE TRIGGER group_invitations_notify
  AFTER INSERT OR UPDATE OF status ON group_invitations
  FOR EACH ROW EXECUTE FUNCTION tio_invitation_changed();
