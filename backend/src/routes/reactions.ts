import { Router } from 'express';
import { Pool } from 'pg';
import { z } from 'zod';
import { forbidden, notFound, parseWith } from '../errors';
import { RequireAuth } from '../middleware/auth';

/**
 * Emoji reactions on published group messages (HANDOFF.md feature 10).
 * Mounted under /groups next to the existing groups router; it only adds
 * the /:groupId/messages/:messageId/reactions paths.
 *
 * Privacy: responses carry per-emoji counts and the caller's own
 * reactions only, never who reacted, so reacting to an anonymous message
 * reveals nothing about its author or about other members.
 */

export const REACTION_EMOJIS = ['👍', '❤️', '🔥', '💡', '👏', '🎯'] as const;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const toggleSchema = z
  .object({
    emoji: z.enum(REACTION_EMOJIS, {
      error: () => `Choose one of ${REACTION_EMOJIS.join(' ')}.`,
    }),
  })
  .strict();

async function reactionSummary(pool: Pool, messageId: string, userId: string) {
  const { rows } = await pool.query(
    `SELECT emoji, count(*)::int AS n, bool_or(user_id = $2) AS mine
     FROM message_reactions WHERE message_id = $1
     GROUP BY emoji`,
    [messageId, userId],
  );
  const reactions: Record<string, number> = {};
  const mine: string[] = [];
  // Stable emoji order for clients.
  for (const emoji of REACTION_EMOJIS) {
    const row = rows.find((r) => r.emoji === emoji);
    if (!row) continue;
    reactions[emoji] = row.n;
    if (row.mine) mine.push(emoji);
  }
  return { message_id: messageId, reactions, my_reactions: mine };
}

export function createReactionsRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();

  /** 404 unknown group/message, 403 non-member. */
  async function requireMessageForMember(groupId: string, messageId: string, userId: string) {
    if (!UUID_RE.test(groupId) || !UUID_RE.test(messageId)) throw notFound();
    const { rows: group } = await pool.query('SELECT 1 FROM groups WHERE id = $1', [groupId]);
    if (!group[0]) throw notFound();
    const { rows: member } = await pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, userId],
    );
    if (!member[0]) throw forbidden();
    const { rows: message } = await pool.query(
      'SELECT 1 FROM published_messages WHERE id = $1 AND group_id = $2',
      [messageId, groupId],
    );
    if (!message[0]) throw notFound('We could not find that message.');
  }

  router.get('/:groupId/messages/:messageId/reactions', requireAuth, async (req, res) => {
    const groupId = String(req.params.groupId);
    const messageId = String(req.params.messageId);
    await requireMessageForMember(groupId, messageId, req.user!.id);
    res.json(await reactionSummary(pool, messageId, req.user!.id));
  });

  router.post('/:groupId/messages/:messageId/reactions', requireAuth, async (req, res) => {
    const groupId = String(req.params.groupId);
    const messageId = String(req.params.messageId);
    const body = parseWith(toggleSchema, req.body);
    await requireMessageForMember(groupId, messageId, req.user!.id);
    const removed = await pool.query(
      'DELETE FROM message_reactions WHERE message_id = $1 AND user_id = $2 AND emoji = $3',
      [messageId, req.user!.id, body.emoji],
    );
    if (removed.rowCount === 0) {
      await pool.query(
        `INSERT INTO message_reactions (message_id, user_id, emoji) VALUES ($1, $2, $3)
         ON CONFLICT DO NOTHING`,
        [messageId, req.user!.id, body.emoji],
      );
    }
    res.json(await reactionSummary(pool, messageId, req.user!.id));
  });

  return router;
}

/** POST /notifications/read-all, alongside the existing notifications router. */
export function createNotificationsReadAllRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();
  router.post('/read-all', requireAuth, async (req, res) => {
    const { rowCount } = await pool.query(
      'UPDATE notifications SET read_at = now() WHERE recipient_id = $1 AND read_at IS NULL',
      [req.user!.id],
    );
    res.json({ marked_count: rowCount ?? 0 });
  });
  return router;
}
