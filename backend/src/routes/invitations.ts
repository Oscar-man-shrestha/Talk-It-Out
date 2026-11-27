/**
 * Your group invitations (API.md 69): see them, accept to join, or
 * decline. Declining tells nobody anything beyond "not joined".
 */
import { Router } from 'express';
import { Pool } from 'pg';
import { blockedEitherWay } from '../blocks';
import { withTransaction } from '../db';
import { ApiError, notFound } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { notifyMemberJoined } from '../notifyMembers';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function createInvitationsRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();
  router.use(requireAuth);

  router.get('/', async (req, res) => {
    const { rows } = await pool.query(
      `SELECT i.id, g.id AS group_id, g.agenda, u.name AS inviter,
              (SELECT count(*)::int FROM group_members m WHERE m.group_id = g.id) AS members,
              date_trunc('milliseconds', i.created_at) AS created_at
       FROM group_invitations i
       JOIN groups g ON g.id = i.group_id
       LEFT JOIN users u ON u.id = i.inviter_id
       WHERE i.invitee_id = $1 AND i.status = 'pending'
       ORDER BY i.created_at DESC`,
      [req.user!.id],
    );
    res.json({
      items: rows.map((r) => ({
        id: r.id,
        group: { id: r.group_id, agenda: r.agenda, member_count: r.members },
        invited_by: r.inviter,
        created_at: r.created_at.toISOString(),
      })),
    });
  });

  async function decide(invitationId: string, me: string, accept: boolean) {
    if (!UUID_RE.test(invitationId)) throw notFound('That invitation is no longer open.');
    return withTransaction(pool, async (client) => {
      const { rows } = await client.query<{ group_id: string; inviter_id: string | null }>(
        `SELECT group_id, inviter_id FROM group_invitations
         WHERE id = $1 AND invitee_id = $2 AND status = 'pending' FOR UPDATE`,
        [invitationId, me],
      );
      const inv = rows[0];
      if (!inv) throw notFound('That invitation is no longer open.');
      if (accept && inv.inviter_id && (await blockedEitherWay(pool, me, inv.inviter_id))) {
        throw new ApiError(403, 'blocked', 'You cannot join this group.');
      }
      if (accept) {
        const joined = await client.query(
          `INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'contributor')
           ON CONFLICT DO NOTHING`,
          [inv.group_id, me],
        );
        if (joined.rowCount) await notifyMemberJoined(client, inv.group_id, me);
      }
      await client.query(
        `UPDATE group_invitations SET status = $2, decided_at = now() WHERE id = $1`,
        [invitationId, accept ? 'accepted' : 'declined'],
      );
      // Answered: the invitation leaves the alerts list.
      await client.query(
        `DELETE FROM notifications
         WHERE type = 'group_invitation' AND ref_id = $1 AND recipient_id = $2`,
        [invitationId, me],
      );
      return inv.group_id;
    });
  }

  router.post('/:id/accept', async (req, res) => {
    const groupId = await decide(req.params.id, req.user!.id, true);
    res.json({ group_id: groupId, joined: true });
  });

  router.post('/:id/decline', async (req, res) => {
    await decide(req.params.id, req.user!.id, false);
    res.status(204).end();
  });

  return router;
}
