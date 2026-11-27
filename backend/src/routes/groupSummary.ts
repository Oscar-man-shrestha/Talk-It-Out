/**
 * GET /groups/:groupId/summary?limit= : "Catch up" for members (API.md 63).
 * Uses only what the group already sees (published, approved text) and
 * never says who wrote what.
 */
import { Router } from 'express';
import { Pool } from 'pg';
import { forbidden, notFound } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { summarize } from '../nlp/summarize';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function createGroupSummaryRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router({ mergeParams: true });
  router.use(requireAuth);

  router.get('/', async (req, res) => {
    const groupId = (req.params as { groupId: string }).groupId;
    if (!UUID_RE.test(groupId)) throw notFound();
    const group = await pool.query('SELECT 1 FROM groups WHERE id = $1', [groupId]);
    if (!group.rows[0]) throw notFound();
    const member = await pool.query('SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2', [
      groupId,
      req.user!.id,
    ]);
    if (!member.rows[0]) throw forbidden();
    const raw = Number(req.query.limit ?? 60);
    const limit = Number.isFinite(raw) ? Math.min(200, Math.max(5, Math.round(raw))) : 60;
    const { rows } = await pool.query<{ text: string; published_at: Date }>(
      `SELECT text, published_at FROM published_messages
       WHERE group_id = $1
       ORDER BY published_at DESC
       LIMIT $2`,
      [groupId, limit],
    );
    const summary = summarize(rows.map((r) => ({ text: r.text, at: r.published_at })));
    res.json({
      ...summary,
      from: rows.length ? rows[rows.length - 1].published_at.toISOString() : null,
      to: rows.length ? rows[0].published_at.toISOString() : null,
    });
  });

  return router;
}
