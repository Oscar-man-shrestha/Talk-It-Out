import { Router } from 'express';
import { Pool, PoolClient } from 'pg';
import { z } from 'zod';
import { conflict, forbidden, notFound, parseWith } from '../errors';
import { buildPage, parseListQuery, PageCursor } from '../pagination';
import { RequireAuth } from '../middleware/auth';
import { uniqueConstraint, withTransaction } from '../db';

const createGroupSchema = z.object({
  agenda: z
    .string()
    .trim()
    .min(1, 'Add an agenda first.')
    .max(500, 'Agenda is too long.'),
});

const addMemberSchema = z.object({
  username: z
    .string()
    .trim()
    .transform((value) => value.replace(/^@+/, ''))
    .pipe(z.string().min(1, 'Enter a username.').max(100, 'Username is too long.')),
  role: z
    .enum(['contributor'], {
      error: () => 'Members can only be added as contributors.',
    })
    .default('contributor'),
});

const sendMessageSchema = z.object({
  text: z.string().trim().min(1, 'Write a message before sending.'),
  is_anonymous: z.boolean().default(false),
});

const controllerMessageSchema = z.object({
  text: z
    .string()
    .trim()
    .min(1, 'Write a message before sending.')
    .max(5000, 'Message is too long.'),
});

/**
 * Pending messages only count toward the controller's queue while their
 * author is still a member; a removed member's pending rows stay in the
 * database for audit but drop out of every queue surface.
 */
const PENDING_FROM_MEMBERS = `SELECT count(*)::int FROM raw_messages r
  WHERE r.group_id = g.id AND r.status = 'pending'
    AND EXISTS (
      SELECT 1 FROM group_members m
      WHERE m.group_id = r.group_id AND m.user_id = r.author_id
    )`;

/** Queue rows only while the author is still a member of the group. */
const QUEUE_AUTHOR_IS_MEMBER = `EXISTS (
  SELECT 1 FROM group_members am
  WHERE am.group_id = r.group_id AND am.user_id = r.author_id
)`;

interface GroupRow {
  id: string;
  agenda: string;
  controller_id: string;
  source_post_id: string | null;
  created_at: Date;
  role: string;
  pending_count: number | null;
}

function groupJson(row: GroupRow) {
  return {
    id: row.id,
    agenda: row.agenda,
    controller_id: row.controller_id,
    source_post_id: row.source_post_id,
    created_at: row.created_at.toISOString(),
    my_role: row.role,
    pending_count: row.pending_count === null ? null : Number(row.pending_count),
  };
}

/** Returns the caller's role in the group, or null when not a member. */
async function memberRole(
  client: Pool | PoolClient,
  groupId: string,
  userId: string,
): Promise<string | null> {
  const { rows } = await client.query(
    'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
    [groupId, userId],
  );
  return rows[0]?.role ?? null;
}

async function groupExists(client: Pool | PoolClient, groupId: string): Promise<boolean> {
  const { rows } = await client.query('SELECT 1 FROM groups WHERE id = $1', [groupId]);
  return rows.length > 0;
}

/** 404 for unknown groups, 403 for non-members. Returns the caller's role. */
async function requireMember(pool: Pool, groupId: string, userId: string): Promise<string> {
  if (!(await groupExists(pool, groupId))) throw notFound();
  const role = await memberRole(pool, groupId, userId);
  if (role === null) throw forbidden();
  return role;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function requireUuid(value: string, what: string): string {
  if (!UUID_RE.test(value)) throw notFound(`We could not find that ${what}.`);
  return value;
}

export function createGroupsRouter(
  pool: Pool,
  requireAuth: RequireAuth,
  maxInputChars: number,
): Router {
  const router = Router();
  router.use(requireAuth);
  // Submission-time pipeline limit: the rewrite pipeline never receives
  // text longer than PIPELINE_MAX_INPUT_CHARS (docs/groups-pipeline-contract.md §6).
  const submitSchema = sendMessageSchema.extend({
    text: sendMessageSchema.shape.text.max(
      maxInputChars,
      `Messages must be at most ${maxInputChars} characters.`,
    ),
  });

  router.post('/', async (req, res) => {
    const body = parseWith(createGroupSchema, req.body);
    const group = await withTransaction(pool, async (client) => {
      const { rows } = await client.query(
        `INSERT INTO groups (agenda, controller_id)
         VALUES ($1, $2)
         RETURNING id, agenda, controller_id, source_post_id, created_at`,
        [body.agenda, req.user!.id],
      );
      const group = rows[0];
      await client.query(
        'INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, $3)',
        [group.id, req.user!.id, 'controller'],
      );
      return group;
    });
    res.status(201).json(
      groupJson({ ...group, role: 'controller', pending_count: 0 }),
    );
  });

  router.get('/', async (req, res) => {
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `SELECT g.id, g.agenda, g.controller_id, g.source_post_id,
              date_trunc('milliseconds', g.created_at) AS created_at,
              gm.role,
              CASE WHEN gm.role = 'controller' THEN (
                ${PENDING_FROM_MEMBERS}
              ) END AS pending_count
       FROM groups g
       JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $1
       WHERE ($2::timestamptz IS NULL
              OR (date_trunc('milliseconds', g.created_at), g.id) < ($2::timestamptz, $3::uuid))
       ORDER BY g.created_at DESC, g.id DESC
       LIMIT $4`,
      [req.user!.id, cursor?.t ?? null, cursor?.i ?? null, limit + 1],
    );
    const page = buildPage<GroupRow, ReturnType<typeof groupJson>>(
      rows,
      limit,
      (row) => ({ t: row.created_at.toISOString(), i: row.id }),
      groupJson,
    );
    res.json(page);
  });

  router.get('/:groupId', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    const role = await requireMember(pool, groupId, req.user!.id);
    const { rows } = await pool.query(
      `SELECT g.id, g.agenda, g.controller_id, g.source_post_id, g.created_at,
              CASE WHEN $2 = 'controller' THEN (
                ${PENDING_FROM_MEMBERS}
              ) END AS pending_count
       FROM groups g WHERE g.id = $1`,
      [groupId, role],
    );
    res.json(groupJson({ ...rows[0], role }));
  });

  router.post('/:groupId/members', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const callerRole = await memberRole(pool, groupId, req.user!.id);
    if (callerRole !== 'controller') throw forbidden();
    const body = parseWith(addMemberSchema, req.body);

    const { rows: userRows } = await pool.query(
      'SELECT id, name FROM users WHERE lower(username) = lower($1)',
      [body.username],
    );
    const user = userRows[0];
    if (!user) throw notFound('No user has that username.');

    try {
      await pool.query(
        `INSERT INTO group_members (group_id, user_id, role)
         VALUES ($1, $2, 'contributor')`,
        [groupId, user.id],
      );
    } catch (err) {
      if (uniqueConstraint(err) === 'group_members_pkey') {
        throw conflict('already_member', 'That person is already in this group.');
      }
      throw err;
    }
    res.status(201).json({ user_id: user.id, name: user.name, role: 'contributor' });
  });

  router.get('/:groupId/members', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    await requireMember(pool, groupId, req.user!.id);
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `SELECT gm.user_id, u.name, gm.role,
              date_trunc('milliseconds', gm.joined_at) AS joined_at
       FROM group_members gm
       JOIN users u ON u.id = gm.user_id
       WHERE gm.group_id = $1
         AND ($2::timestamptz IS NULL
              OR (date_trunc('milliseconds', gm.joined_at), gm.user_id) > ($2::timestamptz, $3::uuid))
       ORDER BY gm.joined_at ASC, gm.user_id ASC
       LIMIT $4`,
      [groupId, cursor?.t ?? null, cursor?.i ?? null, limit + 1],
    );
    const page = buildPage(
      rows,
      limit,
      (row) => ({ t: row.joined_at.toISOString(), i: row.user_id }),
      (row) => ({ user_id: row.user_id, name: row.name, role: row.role }),
    );
    res.json(page);
  });

  router.post('/:groupId/messages', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const role = await memberRole(pool, groupId, req.user!.id);
    if (role === null) throw forbidden();
    if (role === 'controller') {
      throw forbidden('Controllers review messages instead of sending them.');
    }
    const body = parseWith(submitSchema, req.body);

    const result = await withTransaction(pool, async (client) => {
      const { rows } = await client.query(
        `INSERT INTO raw_messages (group_id, author_id, original_text, is_anonymous)
         VALUES ($1, $2, $3, $4)
         RETURNING id, group_id, status, created_at`,
        [groupId, req.user!.id, body.text, body.is_anonymous],
      );
      const raw = rows[0];
      // Outbox job: holds only the raw message id, never text or identity.
      await client.query(
        `INSERT INTO jobs (kind, raw_message_id) VALUES ('process_raw_message', $1)`,
        [raw.id],
      );
      await client.query(
        `INSERT INTO notifications (recipient_id, type, ref_id, group_id)
         SELECT controller_id, 'message_pending_review', $2, id
         FROM groups WHERE id = $1`,
        [groupId, raw.id],
      );
      return raw;
    });
    res.status(201).json({
      id: result.id,
      group_id: result.group_id,
      status: result.status,
      created_at: result.created_at.toISOString(),
    });
  });

  router.get('/:groupId/messages', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    await requireMember(pool, groupId, req.user!.id);
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `SELECT p.id, p.group_id, p.text,
              date_trunc('milliseconds', p.published_at) AS published_at,
              u.id AS author_id, u.name AS author_name
       FROM published_messages p
       LEFT JOIN users u ON u.id = p.author_id
       WHERE p.group_id = $1
         AND ($2::timestamptz IS NULL
              OR (date_trunc('milliseconds', p.published_at), p.id) > ($2::timestamptz, $3::uuid))
       ORDER BY p.published_at ASC, p.id ASC
       LIMIT $4`,
      [groupId, cursor?.t ?? null, cursor?.i ?? null, limit + 1],
    );
    const page = buildPage(
      rows,
      limit,
      (row): PageCursor => ({ t: row.published_at.toISOString(), i: row.id }),
      (row) => ({
        id: row.id,
        group_id: row.group_id,
        text: row.text,
        display_sender: row.author_id
          ? { id: row.author_id, name: row.author_name }
          : null,
        published_at: row.published_at.toISOString(),
      }),
    );
    res.json(page);
  });

  router.get('/:groupId/messages/mine', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    await requireMember(pool, groupId, req.user!.id);
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `SELECT id, group_id, status, is_anonymous,
              date_trunc('milliseconds', created_at) AS created_at
       FROM raw_messages
       WHERE group_id = $1 AND author_id = $2
         AND ($3::timestamptz IS NULL
              OR (date_trunc('milliseconds', created_at), id) < ($3::timestamptz, $4::uuid))
       ORDER BY created_at DESC, id DESC
       LIMIT $5`,
      [groupId, req.user!.id, cursor?.t ?? null, cursor?.i ?? null, limit + 1],
    );
    const page = buildPage(
      rows,
      limit,
      (row) => ({ t: row.created_at.toISOString(), i: row.id }),
      (row) => ({
        id: row.id,
        group_id: row.group_id,
        status: row.status,
        is_anonymous: row.is_anonymous,
        created_at: row.created_at.toISOString(),
      }),
    );
    res.json(page);
  });

  const rawMessageJson = (row: {
    id: string;
    group_id: string;
    author_id: string;
    sender_name: string;
    original_text: string;
    rewritten_text: string | null;
    is_anonymous: boolean;
    intent_preservation_score: string | null;
    relevance_score: string | null;
    relevance_label: string | null;
    pipeline_status: string;
    status: string;
    created_at: Date;
  }) => ({
    id: row.id,
    group_id: row.group_id,
    sender_id: row.author_id,
    sender_name: row.sender_name,
    original_text: row.original_text,
    rewritten_text: row.rewritten_text,
    is_anonymous: row.is_anonymous,
    intent_preservation_score:
      row.intent_preservation_score === null
        ? null
        : Number(row.intent_preservation_score),
    relevance_score:
      row.relevance_score === null ? null : Number(row.relevance_score),
    relevance_label: row.relevance_label,
    pipeline_status: row.pipeline_status,
    status: row.status,
    created_at: row.created_at.toISOString(),
  });

  router.get('/:groupId/review-queue', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const callerRole = await memberRole(pool, groupId, req.user!.id);
    if (callerRole !== 'controller') throw forbidden();
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `SELECT r.id, r.group_id, r.author_id, r.original_text, r.rewritten_text,
              r.is_anonymous, r.intent_preservation_score, r.relevance_score,
              r.relevance_label, r.pipeline_status, r.status,
              date_trunc('milliseconds', r.created_at) AS created_at,
              u.name AS sender_name
       FROM raw_messages r
       JOIN users u ON u.id = r.author_id
       WHERE r.group_id = $1 AND r.status = 'pending' AND ${QUEUE_AUTHOR_IS_MEMBER}
         AND ($2::timestamptz IS NULL
              OR (date_trunc('milliseconds', r.created_at), r.id) > ($2::timestamptz, $3::uuid))
       ORDER BY r.created_at ASC, r.id ASC
       LIMIT $4`,
      [groupId, cursor?.t ?? null, cursor?.i ?? null, limit + 1],
    );
    const page = buildPage(
      rows,
      limit,
      (row) => ({ t: row.created_at.toISOString(), i: row.id }),
      rawMessageJson,
    );
    res.json(page);
  });

  router.get('/:groupId/review-queue/:messageId', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    const messageId = requireUuid(req.params.messageId, 'message');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const callerRole = await memberRole(pool, groupId, req.user!.id);
    if (callerRole !== 'controller') throw forbidden();
    const { rows } = await pool.query(
      `SELECT r.*, u.name AS sender_name
       FROM raw_messages r
       JOIN users u ON u.id = r.author_id
       WHERE r.id = $1 AND r.group_id = $2`,
      [messageId, groupId],
    );
    if (!rows[0]) throw notFound();
    res.json(rawMessageJson(rows[0]));
  });

  // Controller announcements skip the rewrite pipeline entirely: they are
  // published immediately, never anonymous, and always attributed.
  router.post('/:groupId/messages/controller', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const role = await memberRole(pool, groupId, req.user!.id);
    if (role !== 'controller') throw forbidden();
    const body = parseWith(controllerMessageSchema, req.body);
    const { rows } = await pool.query(
      `INSERT INTO published_messages (group_id, author_id, text, is_anonymous, is_controller)
       VALUES ($1, $2, $3, false, true)
       RETURNING id, group_id, text, published_at`,
      [groupId, req.user!.id, body.text],
    );
    const row = rows[0];
    res.status(201).json({
      id: row.id,
      group_id: row.group_id,
      text: row.text,
      display_sender: { id: req.user!.id, name: req.user!.name },
      published_at: row.published_at.toISOString(),
    });
  });

  // Anonymous published rows never stored an author (author_id NULL), so
  // deleting the published row removes every group-facing trace of the
  // message. raw_messages keeps its internal, controller-only audit linkage.
  router.delete('/:groupId/messages/:messageId', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    const messageId = requireUuid(req.params.messageId, 'message');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const role = await memberRole(pool, groupId, req.user!.id);
    if (role !== 'controller') throw forbidden();
    const { rowCount } = await pool.query(
      'DELETE FROM published_messages WHERE id = $1 AND group_id = $2',
      [messageId, groupId],
    );
    if (rowCount === 0) throw notFound();
    res.status(204).end();
  });

  router.delete('/:groupId/members/:userId', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    const userId = requireUuid(req.params.userId, 'member');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const role = await memberRole(pool, groupId, req.user!.id);
    if (role !== 'controller') throw forbidden();
    if (userId === req.user!.id) {
      throw conflict('controller_immutable', 'The controller cannot remove themselves.');
    }
    const { rowCount } = await pool.query(
      'DELETE FROM group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, userId],
    );
    if (rowCount === 0) throw notFound();
    // Removed users lose access immediately; their pending review items drop
    // out of the queue via the author-membership filter.
    res.status(204).end();
  });

  router.post('/:groupId/leave', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const role = await memberRole(pool, groupId, req.user!.id);
    if (role === null) throw forbidden();
    if (role === 'controller') {
      // D4 (decided 2026-11-13): the longest-standing remaining member takes
      // over. A controller who is the only member has nobody to hand to.
      const handedTo = await withTransaction(pool, (client) =>
        handOverControl(client, groupId, req.user!.id),
      );
      if (handedTo === null) {
        throw conflict(
          'last_member',
          'You are the only member, so there is nobody to take over this group.',
        );
      }
      res.status(204).end();
      return;
    }
    await pool.query('DELETE FROM group_members WHERE group_id = $1 AND user_id = $2', [
      groupId,
      req.user!.id,
    ]);
    res.status(204).end();
  });

  return router;
}

/**
 * Removes the controller [leavingId] from [groupId] and promotes the member
 * who joined earliest (ties broken by user id, so the choice is stable).
 * Returns the new controller's id, or null when nobody else is a member; in
 * that case nothing is changed. Run inside a transaction: the
 * one_controller_per_group index requires the old controller row to be gone
 * before the new one is promoted. Reusable by a future account-deletion flow.
 */
export async function handOverControl(
  client: PoolClient,
  groupId: string,
  leavingId: string,
): Promise<string | null> {
  // Lock the group row so two concurrent leaves cannot both promote.
  await client.query('SELECT id FROM groups WHERE id = $1 FOR UPDATE', [groupId]);
  const { rows } = await client.query<{ user_id: string }>(
    `SELECT user_id FROM group_members
     WHERE group_id = $1 AND user_id <> $2
     ORDER BY joined_at ASC, user_id ASC
     LIMIT 1`,
    [groupId, leavingId],
  );
  const next = rows[0]?.user_id;
  if (!next) return null;
  await client.query('DELETE FROM group_members WHERE group_id = $1 AND user_id = $2', [
    groupId,
    leavingId,
  ]);
  await client.query(
    `UPDATE group_members SET role = 'controller' WHERE group_id = $1 AND user_id = $2`,
    [groupId, next],
  );
  await client.query('UPDATE groups SET controller_id = $2 WHERE id = $1', [groupId, next]);
  return next;
}

