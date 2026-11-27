import { PoolClient } from 'pg';

/**
 * Tells a group's controller that someone joined (API.md 73). The
 * notification names the group only; the members list shows who.
 */
export async function notifyMemberJoined(
  client: PoolClient,
  groupId: string,
  newMemberId: string,
): Promise<void> {
  await client.query(
    `INSERT INTO notifications (recipient_id, type, ref_id, group_id)
     SELECT m.user_id, 'member_joined', $2, $1
       FROM group_members m
      WHERE m.group_id = $1 AND m.role = 'controller' AND m.user_id <> $2`,
    [groupId, newMemberId],
  );
}
