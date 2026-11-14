import { Request, Router } from 'express';
import { Pool, PoolClient } from 'pg';
import { z } from 'zod';
import { badRequest, conflict, forbidden, notFound, parseWith } from '../errors';
import { buildPage, decodeCursor, encodeCursor, parseListQuery, PageCursor } from '../pagination';
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

const attachmentId = z
  .string()
  .regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, 'Attach the image again.')
  .nullish();

const uuidRef = (message: string) =>
  z
    .string()
    .regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, message)
    .nullish();

const sendMessageSchema = z.object({
  text: z.string().trim().min(1, 'Add a caption before sending.'),
  is_anonymous: z.boolean().default(false),
  attachment_id: attachmentId,
  reply_to_id: uuidRef('That message can no longer be replied to.'),
});

const sendPreviewSchema = z.object({
  is_anonymous: z.boolean().default(false),
  attachment_id: attachmentId,
  reply_to_id: uuidRef('That message can no longer be replied to.'),
});

const pollSchema = z.object({
  question: z.string().trim().min(1, 'Write a question.').max(300, 'Keep the question under 300 characters.'),
  options: z
    .array(z.string().trim().min(1, 'Options cannot be empty.').max(100, 'Keep options under 100 characters.'))
    .min(2, 'Add at least 2 options.')
    .max(6, 'Use at most 6 options.'),
});

const voteSchema = z.object({ option_index: z.number().int().min(0).max(5) });

/** Unsent rewrite previews older than this are deleted. */
const PREVIEW_TTL = "interval '1 hour'";

const controllerMessageSchema = z.object({
  text: z
    .string()
    .trim()
    .min(1, 'Write a message before sending.')
    .max(5000, 'Message is too long.'),
  attachment_id: attachmentId,
  reply_to_id: uuidRef('That message can no longer be replied to.'),
});

/**
 * Checks that an uploaded image may go on a new message: it belongs to
 * this group, the caller uploaded it, and no message uses it yet. Locks it
 * for the rest of the transaction.
 */
async function claimAttachment(
  client: PoolClient,
  id: string | null | undefined,
  groupId: string,
  userId: string,
): Promise<string | null> {
  if (!id) return null;
  const { rows } = await client.query(
    `SELECT a.id FROM message_attachments a
     WHERE a.id = $1 AND a.group_id = $2 AND a.uploader_id = $3
       AND NOT EXISTS (SELECT 1 FROM raw_messages r WHERE r.attachment_id = a.id)
       AND NOT EXISTS (SELECT 1 FROM published_messages p WHERE p.attachment_id = a.id)
     FOR UPDATE`,
    [id, groupId, userId],
  );
  if (!rows[0]) {
    throw badRequest('invalid_attachment', 'That image is no longer available. Attach it again.');
  }
  return rows[0].id as string;
}

/** Deletes rewrite previews (and their jobs) matching a raw_messages filter. */
async function deletePreviews(client: PoolClient, where: string, params: unknown[]): Promise<void> {
  const { rows } = await client.query(`SELECT id FROM raw_messages WHERE ${where}`, params);
  const ids = rows.map((r) => r.id as string);
  if (ids.length === 0) return;
  await client.query('DELETE FROM jobs WHERE raw_message_id = ANY($1::uuid[])', [ids]);
  await client.query('DELETE FROM raw_messages WHERE id = ANY($1::uuid[]) AND is_preview', [ids]);
}

/** A reply must point at a published message in the same group. */
async function checkReplyTarget(
  client: PoolClient,
  id: string | null | undefined,
  groupId: string,
): Promise<string | null> {
  if (!id) return null;
  const { rows } = await client.query(
    'SELECT id FROM published_messages WHERE id = $1 AND group_id = $2',
    [id, groupId],
  );
  if (!rows[0]) throw badRequest('invalid_reply', 'That message can no longer be replied to.');
  return id;
}

/**
 * Group-facing message rows with their reply quote, pin and poll. $1 is the
 * group and $2 the caller (for "my vote"); callers add WHERE/ORDER/LIMIT.
 * A quote shows only what the group already sees: the published text and
 * the published sender (null when anonymous).
 */
const PUBLISHED_SELECT = `
  SELECT p.id, p.group_id, p.text, p.attachment_id, p.reply_to_id,
         p.pinned_at IS NOT NULL AS pinned,
         date_trunc('milliseconds', p.published_at) AS published_at,
         u.id AS author_id, u.name AS author_name,
         q.text AS reply_text, qu.id AS reply_author_id, qu.name AS reply_author_name,
         po.id AS poll_id, po.options AS poll_options,
         (SELECT array_agg(c ORDER BY i) FROM (
            SELECT gs.i, count(v.voter_id)::int AS c
            FROM generate_series(0, cardinality(po.options) - 1) AS gs(i)
            LEFT JOIN poll_votes v ON v.poll_id = po.id AND v.option_index = gs.i
            GROUP BY gs.i) t) AS poll_counts,
         (SELECT v.option_index FROM poll_votes v
          WHERE v.poll_id = po.id AND v.voter_id = $2) AS poll_my_vote
  FROM published_messages p
  LEFT JOIN users u ON u.id = p.author_id
  LEFT JOIN published_messages q ON q.id = p.reply_to_id
  LEFT JOIN users qu ON qu.id = q.author_id
  LEFT JOIN polls po ON po.message_id = p.id
  WHERE p.group_id = $1`;

interface PublishedRow {
  id: string;
  group_id: string;
  text: string;
  attachment_id: string | null;
  reply_to_id: string | null;
  pinned: boolean;
  published_at: Date;
  author_id: string | null;
  author_name: string | null;
  reply_text: string | null;
  reply_author_id: string | null;
  reply_author_name: string | null;
  poll_id: string | null;
  poll_options: string[] | null;
  poll_counts: number[] | null;
  poll_my_vote: number | null;
}

function publishedJson(row: PublishedRow) {
  const counts = row.poll_counts ?? [];
  return {
    id: row.id,
    group_id: row.group_id,
    text: row.text,
    display_sender: row.author_id ? { id: row.author_id, name: row.author_name } : null,
    attachment_id: row.attachment_id,
    reply_to:
      row.reply_to_id && row.reply_text !== null
        ? {
            id: row.reply_to_id,
            text: row.reply_text.length > 140 ? `${row.reply_text.slice(0, 140)}…` : row.reply_text,
            display_sender: row.reply_author_id
              ? { id: row.reply_author_id, name: row.reply_author_name }
              : null,
          }
        : null,
    pinned: row.pinned,
    poll: row.poll_id
      ? {
          id: row.poll_id,
          options: (row.poll_options ?? []).map((text, i) => ({ text, votes: counts[i] ?? 0 })),
          total_votes: counts.reduce((a, b) => a + b, 0),
          my_vote: row.poll_my_vote,
        }
      : null,
    published_at: row.published_at.toISOString(),
  };
}

/**
 * Pending messages only count toward the controller's queue while their
 * author is still a member; a removed member's pending rows stay in the
 * database for audit but drop out of every queue surface.
 */
const PENDING_FROM_MEMBERS = `SELECT count(*)::int FROM raw_messages r
  WHERE r.group_id = g.id AND r.status = 'pending' AND NOT r.is_preview
    AND EXISTS (
      SELECT 1 FROM group_members m
      WHERE m.group_id = r.group_id AND m.user_id = r.author_id
    )`;

/** Queue rows only while the author is still a member of the group. */
const QUEUE_AUTHOR_IS_MEMBER = `NOT r.is_preview AND EXISTS (
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
      const attachment = await claimAttachment(client, body.attachment_id, groupId, req.user!.id);
      const replyTo = await checkReplyTarget(client, body.reply_to_id, groupId);
      const { rows } = await client.query(
        `INSERT INTO raw_messages
           (group_id, author_id, original_text, is_anonymous, attachment_id, reply_to_id)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, group_id, status, created_at`,
        [groupId, req.user!.id, body.text, body.is_anonymous, attachment, replyTo],
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

  // Default: oldest first from the start (the v1 contract). With
  // ?before=<cursor> (empty for "the latest"), returns the page just before
  // that point, still in reading order, plus prev_cursor for older pages.
  router.get('/:groupId/messages', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    await requireMember(pool, groupId, req.user!.id);
    const { limit, cursor } = parseListQuery(req);
    if (typeof req.query.before === 'string') {
      const before = req.query.before ? decodeCursor(req.query.before) : null;
      const { rows } = await pool.query<PublishedRow>(
        `${PUBLISHED_SELECT}
           AND ($3::timestamptz IS NULL
                OR (date_trunc('milliseconds', p.published_at), p.id) < ($3::timestamptz, $4::uuid))
         ORDER BY p.published_at DESC, p.id DESC
         LIMIT $5`,
        [groupId, req.user!.id, before?.t ?? null, before?.i ?? null, limit + 1],
      );
      const more = rows.length > limit;
      const page = rows.slice(0, limit).reverse();
      res.json({
        items: page.map(publishedJson),
        prev_cursor:
          more && page[0]
            ? encodeCursor({ t: page[0].published_at.toISOString(), i: page[0].id })
            : null,
      });
      return;
    }
    const { rows } = await pool.query<PublishedRow>(
      `${PUBLISHED_SELECT}
         AND ($3::timestamptz IS NULL
              OR (date_trunc('milliseconds', p.published_at), p.id) > ($3::timestamptz, $4::uuid))
       ORDER BY p.published_at ASC, p.id ASC
       LIMIT $5`,
      [groupId, req.user!.id, cursor?.t ?? null, cursor?.i ?? null, limit + 1],
    );
    res.json(
      buildPage(
        rows,
        limit,
        (row): PageCursor => ({ t: row.published_at.toISOString(), i: row.id }),
        publishedJson,
      ),
    );
  });

  // Search the group's published messages (newest first, at most 50).
  router.get('/:groupId/messages/search', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    await requireMember(pool, groupId, req.user!.id);
    const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (q.length < 2) throw badRequest('bad_request', 'Type at least 2 characters to search.');
    if (q.length > 100) throw badRequest('bad_request', 'Search is too long.');
    const pattern = `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    const { rows } = await pool.query<PublishedRow>(
      `${PUBLISHED_SELECT} AND p.text ILIKE $3
       ORDER BY p.published_at DESC, p.id DESC LIMIT 50`,
      [groupId, req.user!.id, pattern],
    );
    res.json({ items: rows.map(publishedJson) });
  });

  // --- Rewrite preview (before sending) --------------------------------
  // The sender sees how the AI will word their own draft. Nothing reaches
  // the controller until they send it.
  router.post('/:groupId/messages/preview', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const role = await memberRole(pool, groupId, req.user!.id);
    if (role === null) throw forbidden();
    if (role === 'controller') {
      throw forbidden('Controllers review messages instead of sending them.');
    }
    const body = parseWith(submitSchema, req.body);
    const row = await withTransaction(pool, async (client) => {
      await deletePreviews(
        client,
        `author_id = $1 AND is_preview AND created_at < now() - ${PREVIEW_TTL}`,
        [req.user!.id],
      );
      const { rows } = await client.query(
        `INSERT INTO raw_messages (group_id, author_id, original_text, is_anonymous, is_preview)
         VALUES ($1, $2, $3, $4, true)
         RETURNING id, pipeline_status`,
        [groupId, req.user!.id, body.text, body.is_anonymous],
      );
      await client.query(
        `INSERT INTO jobs (kind, raw_message_id) VALUES ('process_raw_message', $1)`,
        [rows[0].id],
      );
      return rows[0];
    });
    res.status(202).json({ id: row.id, pipeline_status: row.pipeline_status, rewritten_text: null });
  });

  router.get('/:groupId/messages/preview/:previewId', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    const previewId = requireUuid(req.params.previewId, 'preview');
    const { rows } = await pool.query(
      `SELECT id, pipeline_status, rewritten_text FROM raw_messages
       WHERE id = $1 AND group_id = $2 AND author_id = $3 AND is_preview`,
      [previewId, groupId, req.user!.id],
    );
    if (!rows[0]) throw notFound('That preview has expired. Preview again.');
    res.json({
      id: rows[0].id,
      pipeline_status: rows[0].pipeline_status,
      rewritten_text: rows[0].pipeline_status === 'done' ? rows[0].rewritten_text : null,
    });
  });

  router.post('/:groupId/messages/preview/:previewId/send', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    const previewId = requireUuid(req.params.previewId, 'preview');
    const role = await memberRole(pool, groupId, req.user!.id);
    if (role !== 'contributor') throw forbidden();
    const body = parseWith(sendPreviewSchema, req.body);
    const sent = await withTransaction(pool, async (client) => {
      const { rows } = await client.query(
        `SELECT id, is_anonymous FROM raw_messages
         WHERE id = $1 AND group_id = $2 AND author_id = $3 AND is_preview
         FOR UPDATE`,
        [previewId, groupId, req.user!.id],
      );
      if (!rows[0]) throw notFound('That preview has expired. Preview again.');
      const attachment = await claimAttachment(client, body.attachment_id, groupId, req.user!.id);
      const replyTo = await checkReplyTarget(client, body.reply_to_id, groupId);
      const { rows: updated } = await client.query(
        `UPDATE raw_messages
         SET is_preview = false, is_anonymous = $2, attachment_id = $3, reply_to_id = $4,
             created_at = now()
         WHERE id = $1
         RETURNING id, group_id, status, created_at, pipeline_status`,
        [previewId, body.is_anonymous, attachment, replyTo],
      );
      // The previewed wording used the tone for the old choice; if the
      // anonymity choice changed, rewrite again with the right one.
      if (rows[0].is_anonymous !== body.is_anonymous && updated[0].pipeline_status !== 'queued' && updated[0].pipeline_status !== 'processing') {
        await client.query(
          `UPDATE raw_messages SET pipeline_status = 'queued', rewritten_text = NULL,
             intent_preservation_score = NULL, relevance_score = NULL, relevance_label = NULL
           WHERE id = $1`,
          [previewId],
        );
        await client.query(
          `INSERT INTO jobs (kind, raw_message_id) VALUES ('process_raw_message', $1)`,
          [previewId],
        );
      }
      await client.query(
        `INSERT INTO notifications (recipient_id, type, ref_id, group_id)
         SELECT controller_id, 'message_pending_review', $2, id FROM groups WHERE id = $1`,
        [groupId, previewId],
      );
      return updated[0];
    });
    res.status(201).json({
      id: sent.id,
      group_id: sent.group_id,
      status: sent.status,
      created_at: sent.created_at.toISOString(),
    });
  });

  router.delete('/:groupId/messages/preview/:previewId', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    const previewId = requireUuid(req.params.previewId, 'preview');
    await withTransaction(pool, (client) =>
      deletePreviews(client, 'id = $1 AND group_id = $2 AND author_id = $3 AND is_preview', [
        previewId,
        groupId,
        req.user!.id,
      ]),
    );
    res.status(204).end();
  });

  // --- Pins and polls (controller) ---------------------------------------
  for (const pin of [true, false]) {
    router[pin ? 'post' : 'delete']('/:groupId/messages/:messageId/pin', async (req, res) => {
      const groupId = requireUuid(req.params.groupId, 'group');
      const messageId = requireUuid(req.params.messageId, 'message');
      if (!(await groupExists(pool, groupId))) throw notFound();
      if ((await memberRole(pool, groupId, req.user!.id)) !== 'controller') throw forbidden();
      const { rowCount } = await pool.query(
        `UPDATE published_messages SET pinned_at = ${pin ? 'now()' : 'NULL'}
         WHERE id = $1 AND group_id = $2`,
        [messageId, groupId],
      );
      if (rowCount === 0) throw notFound();
      res.status(204).end();
    });
  }

  router.post('/:groupId/polls', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    if (!(await groupExists(pool, groupId))) throw notFound();
    if ((await memberRole(pool, groupId, req.user!.id)) !== 'controller') throw forbidden();
    const body = parseWith(pollSchema, req.body);
    const messageId = await withTransaction(pool, async (client) => {
      const { rows } = await client.query(
        `INSERT INTO published_messages (group_id, author_id, text, is_anonymous, is_controller)
         VALUES ($1, $2, $3, false, true) RETURNING id`,
        [groupId, req.user!.id, body.question],
      );
      await client.query('INSERT INTO polls (message_id, options) VALUES ($1, $2)', [
        rows[0].id,
        body.options,
      ]);
      return rows[0].id as string;
    });
    const { rows } = await pool.query<PublishedRow>(`${PUBLISHED_SELECT} AND p.id = $3`, [
      groupId,
      req.user!.id,
      messageId,
    ]);
    res.status(201).json(publishedJson(rows[0]));
  });

  // Votes are counted, never listed: nobody sees who voted for what.
  for (const vote of [true, false]) {
    router[vote ? 'post' : 'delete']('/:groupId/polls/:pollId/vote', async (req, res) => {
      const groupId = requireUuid(req.params.groupId, 'group');
      const pollId = requireUuid(req.params.pollId, 'poll');
      await requireMember(pool, groupId, req.user!.id);
      const { rows } = await pool.query(
        `SELECT po.id, cardinality(po.options) AS n FROM polls po
         JOIN published_messages p ON p.id = po.message_id
         WHERE po.id = $1 AND p.group_id = $2`,
        [pollId, groupId],
      );
      if (!rows[0]) throw notFound();
      if (vote) {
        const body = parseWith(voteSchema, req.body);
        if (body.option_index >= rows[0].n) throw badRequest('bad_request', 'Pick one of the options.');
        await pool.query(
          `INSERT INTO poll_votes (poll_id, voter_id, option_index) VALUES ($1, $2, $3)
           ON CONFLICT (poll_id, voter_id) DO UPDATE SET option_index = $3, voted_at = now()`,
          [pollId, req.user!.id, body.option_index],
        );
      } else {
        await pool.query('DELETE FROM poll_votes WHERE poll_id = $1 AND voter_id = $2', [
          pollId,
          req.user!.id,
        ]);
      }
      res.status(204).end();
    });
  }

  router.get('/:groupId/messages/mine', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    await requireMember(pool, groupId, req.user!.id);
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `SELECT id, group_id, status, is_anonymous,
              date_trunc('milliseconds', created_at) AS created_at
       FROM raw_messages
       WHERE group_id = $1 AND author_id = $2 AND NOT is_preview
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
    decided_at: Date | null;
    attachment_id: string | null;
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
    decided_at: row.decided_at ? row.decided_at.toISOString() : null,
    attachment_id: row.attachment_id,
  });

  const REVIEW_STATUSES = ['pending', 'accepted', 'rejected'] as const;
  type ReviewStatus = (typeof REVIEW_STATUSES)[number];
  const reviewStatusOf = (req: Request): ReviewStatus => {
    const raw = req.query.status;
    if (raw === undefined) return 'pending';
    if (typeof raw === 'string' && (REVIEW_STATUSES as readonly string[]).includes(raw)) {
      return raw as ReviewStatus;
    }
    throw badRequest('bad_request', 'Status must be pending, accepted or rejected.');
  };

  // Pending messages oldest first (the queue). ?status=accepted|rejected
  // lists the controller's decided messages instead, most recently decided
  // first, so a controller can look back at what was published or turned down.
  router.get('/:groupId/review-queue', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const callerRole = await memberRole(pool, groupId, req.user!.id);
    if (callerRole !== 'controller') throw forbidden();
    const status = reviewStatusOf(req);
    const { limit, cursor } = parseListQuery(req);
    const pending = status === 'pending';
    const sortColumn = pending ? 'r.created_at' : 'r.decided_at';
    const { rows } = await pool.query(
      `SELECT r.id, r.group_id, r.author_id, r.original_text, r.rewritten_text,
              r.is_anonymous, r.intent_preservation_score, r.relevance_score,
              r.relevance_label, r.pipeline_status, r.status, r.attachment_id,
              date_trunc('milliseconds', r.created_at) AS created_at,
              date_trunc('milliseconds', r.decided_at) AS decided_at,
              date_trunc('milliseconds', ${sortColumn}) AS sort_at,
              u.name AS sender_name
       FROM raw_messages r
       JOIN users u ON u.id = r.author_id
       WHERE r.group_id = $1 AND r.status = $5 AND ${QUEUE_AUTHOR_IS_MEMBER}
         AND ($2::timestamptz IS NULL
              OR (date_trunc('milliseconds', ${sortColumn}), r.id)
                 ${pending ? '>' : '<'} ($2::timestamptz, $3::uuid))
       ORDER BY ${sortColumn} ${pending ? 'ASC' : 'DESC'}, r.id ${pending ? 'ASC' : 'DESC'}
       LIMIT $4`,
      [groupId, cursor?.t ?? null, cursor?.i ?? null, limit + 1, status],
    );
    const page = buildPage(
      rows,
      limit,
      (row) => ({ t: (row.sort_at as Date).toISOString(), i: row.id as string }),
      (row) => rawMessageJson(row),
    );
    res.json(page);
  });

  // How many messages sit in each review tab (same visibility as the lists).
  router.get('/:groupId/review-counts', async (req, res) => {
    const groupId = requireUuid(req.params.groupId, 'group');
    if (!(await groupExists(pool, groupId))) throw notFound();
    const callerRole = await memberRole(pool, groupId, req.user!.id);
    if (callerRole !== 'controller') throw forbidden();
    const { rows } = await pool.query(
      `SELECT count(*) FILTER (WHERE r.status = 'pending')::int AS pending,
              count(*) FILTER (WHERE r.status = 'accepted')::int AS accepted,
              count(*) FILTER (WHERE r.status = 'rejected')::int AS rejected
       FROM raw_messages r
       WHERE r.group_id = $1 AND ${QUEUE_AUTHOR_IS_MEMBER}`,
      [groupId],
    );
    res.json(rows[0]);
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
       WHERE r.id = $1 AND r.group_id = $2 AND NOT r.is_preview`,
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
    const rows = await withTransaction(pool, async (client) => {
      const attachment = await claimAttachment(client, body.attachment_id, groupId, req.user!.id);
      const replyTo = await checkReplyTarget(client, body.reply_to_id, groupId);
      const inserted = await client.query(
        `INSERT INTO published_messages
           (group_id, author_id, text, is_anonymous, is_controller, attachment_id, reply_to_id)
         VALUES ($1, $2, $3, false, true, $4, $5)
         RETURNING id`,
        [groupId, req.user!.id, body.text, attachment, replyTo],
      );
      return inserted.rows;
    });
    const { rows: full } = await pool.query<PublishedRow>(`${PUBLISHED_SELECT} AND p.id = $3`, [
      groupId,
      req.user!.id,
      rows[0].id,
    ]);
    res.status(201).json(publishedJson(full[0]));
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
    const deleted = await withTransaction(pool, async (client) => {
      const { rows } = await client.query(
        'DELETE FROM published_messages WHERE id = $1 AND group_id = $2 RETURNING attachment_id',
        [messageId, groupId],
      );
      if (!rows[0]) return false;
      // The image goes with the message.
      if (rows[0].attachment_id) {
        await client.query('DELETE FROM message_attachments WHERE id = $1', [rows[0].attachment_id]);
      }
      return true;
    });
    if (!deleted) throw notFound();
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

