import { Router } from 'express';
import { Pool, PoolClient } from 'pg';
import { conflict, forbidden, notFound } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { withTransaction } from '../db';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface RawRow {
  id: string;
  group_id: string;
  author_id: string;
  original_text: string;
  is_anonymous: boolean;
  status: string;
  pipeline_status: string;
  rewritten_text: string | null;
}

/**
 * Locks the raw message row FOR UPDATE and runs the permission and state
 * checks every decision endpoint shares. Unknown message -> 404, caller is
 * not that group's controller -> 403, already decided -> 409.
 */
async function lockPendingMessageForController(
  client: PoolClient,
  messageId: string,
  callerId: string,
): Promise<RawRow> {
  const { rows } = await client.query(
    'SELECT * FROM raw_messages WHERE id = $1 FOR UPDATE',
    [messageId],
  );
  const raw = rows[0] as RawRow | undefined;
  if (!raw) throw notFound();
  const { rows: roleRows } = await client.query(
    'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
    [raw.group_id, callerId],
  );
  if (roleRows[0]?.role !== 'controller') throw forbidden();
  if (raw.status !== 'pending') {
    throw conflict('already_decided', 'This message has already been decided.');
  }
  return raw;
}

export function createMessagesRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();
  router.use(requireAuth);

  router.post('/:messageId/accept', async (req, res) => {
    const messageId = req.params.messageId;
    if (!UUID_RE.test(messageId)) throw notFound();
    const publishedId = await withTransaction(pool, async (client) => {
      const raw = await lockPendingMessageForController(client, messageId, req.user!.id);
      if (raw.pipeline_status !== 'done' || !raw.rewritten_text?.trim()) {
        throw conflict('no_rewrite', 'This message has no rewrite yet.');
      }
      // Publish only the rewrite. The CHECK constraint on published_messages
      // enforces author_id NULL exactly when the message is anonymous.
      const { rows: published } = await client.query(
        `INSERT INTO published_messages (group_id, author_id, text, is_anonymous, is_controller)
         VALUES ($1, $2, $3, $4, false)
         RETURNING id`,
        [
          raw.group_id,
          raw.is_anonymous ? null : raw.author_id,
          raw.rewritten_text,
          raw.is_anonymous,
        ],
      );
      await client.query(
        `UPDATE raw_messages
         SET status = 'accepted', published_message_id = $2,
             decided_at = now(), decided_by = $3
         WHERE id = $1`,
        [raw.id, published[0].id, req.user!.id],
      );
      return published[0].id as string;
    });
    res.json({ id: messageId, status: 'accepted', published_message_id: publishedId });
  });

  router.post('/:messageId/reject', async (req, res) => {
    const messageId = req.params.messageId;
    if (!UUID_RE.test(messageId)) throw notFound();
    await withTransaction(pool, async (client) => {
      const raw = await lockPendingMessageForController(client, messageId, req.user!.id);
      await client.query(
        `UPDATE raw_messages
         SET status = 'rejected', decided_at = now(), decided_by = $2
         WHERE id = $1`,
        [raw.id, req.user!.id],
      );
      // Rejection notification carries no reason.
      await client.query(
        `INSERT INTO notifications (recipient_id, type, ref_id, group_id)
         VALUES ($1, 'message_rejected', $2, $3)`,
        [raw.author_id, raw.id, raw.group_id],
      );
    });
    res.json({ id: messageId, status: 'rejected' });
  });

  return router;
}
