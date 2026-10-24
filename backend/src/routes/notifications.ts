import { Router } from 'express';
import { Pool } from 'pg';
import { notFound } from '../errors';
import { buildPage, parseListQuery } from '../pagination';
import { RequireAuth } from '../middleware/auth';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function createNotificationsRouter(
  pool: Pool,
  requireAuth: RequireAuth,
): Router {
  const router = Router();
  router.use(requireAuth);

  router.get('/', async (req, res) => {
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `SELECT n.id, n.type, n.ref_id,
              date_trunc('milliseconds', n.created_at) AS created_at,
              n.read_at,
              g.id AS group_id, g.agenda AS group_agenda
       FROM notifications n
       JOIN groups g ON g.id = n.group_id
       WHERE n.recipient_id = $1
         AND ($2::timestamptz IS NULL
              OR (date_trunc('milliseconds', n.created_at), n.id) < ($2::timestamptz, $3::uuid))
       ORDER BY n.created_at DESC, n.id DESC
       LIMIT $4`,
      [req.user!.id, cursor?.t ?? null, cursor?.i ?? null, limit + 1],
    );
    const page = buildPage(
      rows,
      limit,
      (row) => ({ t: row.created_at.toISOString(), i: row.id }),
      (row) => ({
        id: row.id,
        type: row.type,
        ref_id: row.ref_id,
        group: { id: row.group_id, agenda: row.group_agenda },
        created_at: row.created_at.toISOString(),
        read_at: row.read_at ? row.read_at.toISOString() : null,
      }),
    );
    res.json(page);
  });

  router.post('/:notificationId/read', async (req, res) => {
    const notificationId = req.params.notificationId;
    if (!UUID_RE.test(notificationId)) throw notFound();
    const { rowCount } = await pool.query(
      `UPDATE notifications SET read_at = now()
       WHERE id = $1 AND recipient_id = $2 AND read_at IS NULL`,
      [notificationId, req.user!.id],
    );
    if (rowCount === 0) {
      // Distinguish "already read" (still a success) from "not yours / unknown".
      const { rows } = await pool.query(
        'SELECT 1 FROM notifications WHERE id = $1 AND recipient_id = $2',
        [notificationId, req.user!.id],
      );
      if (!rows[0]) throw notFound();
    }
    res.status(204).end();
  });

  router.get('/unread-count', async (req, res) => {
    const { rows } = await pool.query(
      'SELECT count(*)::int AS count FROM notifications WHERE recipient_id = $1 AND read_at IS NULL',
      [req.user!.id],
    );
    res.json({ count: rows[0].count });
  });

  return router;
}
