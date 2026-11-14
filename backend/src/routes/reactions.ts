import { Router } from 'express';
import { Pool } from 'pg';
import { z } from 'zod';
import { badRequest, forbidden, notFound, parseWith } from '../errors';
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

/**
 * Exactly one emoji: a flag, a keycap, or a pictograph with optional skin
 * tone, variation selector and zero-width-joiner sequence (families,
 * professions). Plain text, digits or several emoji are refused.
 */
export const SINGLE_EMOJI_RE =
  /^(?:\p{Regional_Indicator}{2}|[#*0-9]\uFE0F?\u20E3|\p{Extended_Pictographic}(?:\p{Emoji_Modifier}|\uFE0F)?(?:\u200D\p{Extended_Pictographic}(?:\p{Emoji_Modifier}|\uFE0F)?)*)$/u;

/** One person can add at most this many different reactions to a message. */
export const MAX_REACTIONS_PER_PERSON = 10;

const toggleSchema = z
  .object({
    emoji: z
      .string()
      .max(32)
      .refine((value) => SINGLE_EMOJI_RE.test(value), 'React with a single emoji.'),
  })
  .strict();

async function reactionSummary(pool: Pool, messageId: string, userId: string) {
  const { rows } = await pool.query(
    `SELECT emoji, count(*)::int AS n, bool_or(user_id = $2) AS mine
     FROM message_reactions WHERE message_id = $1
     GROUP BY emoji
     ORDER BY min(created_at), emoji`,
    [messageId, userId],
  );
  // Stable order for clients: the order emoji were first used.
  const reactions: Record<string, number> = {};
  const mine: string[] = [];
  for (const row of rows) {
    reactions[row.emoji] = row.n;
    if (row.mine) mine.push(row.emoji);
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
      const { rows: count } = await pool.query(
        'SELECT count(*)::int AS n FROM message_reactions WHERE message_id = $1 AND user_id = $2',
        [messageId, req.user!.id],
      );
      if (count[0].n >= MAX_REACTIONS_PER_PERSON) {
        throw badRequest('too_many_reactions', `You can add up to ${MAX_REACTIONS_PER_PERSON} reactions to a message.`);
      }
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
