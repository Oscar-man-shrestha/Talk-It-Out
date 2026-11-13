import { Router } from 'express';
import { Pool, PoolClient } from 'pg';
import { z } from 'zod';
import { conflict, forbidden, notFound, parseWith } from '../errors';
import { buildPage, parseListQuery, PageCursor } from '../pagination';
import { RequireAuth } from '../middleware/auth';
import { uniqueConstraint, withTransaction } from '../db';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const POST_TOPICS = [
  'workplace_policy',
  'engineering',
  'leadership',
  'compensation',
  'safety',
  'culture',
] as const;

const postContentSchema = z.object({
  content: z
    .string()
    .trim()
    .min(1, 'Write a post first.')
    .max(5000, 'Post is too long.'),
  // Optional so older clients keep working (API.md 42).
  title: z
    .string()
    .trim()
    .min(1, 'Add a title.')
    .max(150, 'Titles can be at most 150 characters.')
    .nullish(),
  topic: z.enum(POST_TOPICS, { error: () => 'Choose one of the listed topics.' }).nullish(),
});

const commentContentSchema = z.object({
  content: z
    .string()
    .trim()
    .min(1, 'Write a comment first.')
    .max(5000, 'Comment is too long.'),
});

const reactionSchema = z.object({
  type: z.literal('like', {
    error: () => 'Only "like" reactions are supported.',
  }),
});

interface PostRow {
  id: string;
  title: string | null;
  topic: string | null;
  content: string;
  analysis_status: string;
  analysis_nsfw: boolean | null;
  analysis_flags: Record<string, unknown> | null;
  created_at: Date;
  author_id: string;
  author_name: string;
  reaction_count: number;
  comment_count: number;
  my_reaction: boolean;
}

interface CommentRow {
  id: string;
  post_id: string;
  content: string;
  analysis_status: string;
  analysis_nsfw: boolean | null;
  analysis_flags: Record<string, unknown> | null;
  created_at: Date;
  author_id: string;
  author_name: string;
}

/**
 * The client's Post/Comment models have a non-null nsfw_flag and cannot
 * represent pending/failed/unavailable analysis, so anything that is not
 * analysis_status='complete' serializes as nsfw_flag=false / other_flags={}.
 * The distinction lives on in the database and must never be treated as
 * "verified safe" internally.
 */
function analysisFlags(status: string, nsfw: boolean | null, flags: Record<string, unknown> | null) {
  if (status !== 'complete') return { nsfw_flag: false, other_flags: {} };
  return { nsfw_flag: nsfw === true, other_flags: flags ?? {} };
}

function postJson(row: PostRow) {
  const flags = analysisFlags(row.analysis_status, row.analysis_nsfw, row.analysis_flags);
  return {
    id: row.id,
    author: { id: row.author_id, name: row.author_name },
    title: row.title ?? null,
    topic: row.topic ?? null,
    content: row.content,
    nsfw_flag: flags.nsfw_flag,
    other_flags: flags.other_flags,
    reaction_count: Number(row.reaction_count),
    my_reaction: row.my_reaction ? 'like' : null,
    comment_count: Number(row.comment_count),
    created_at: row.created_at.toISOString(),
  };
}

function commentJson(row: CommentRow) {
  const flags = analysisFlags(row.analysis_status, row.analysis_nsfw, row.analysis_flags);
  return {
    id: row.id,
    post_id: row.post_id,
    author: { id: row.author_id, name: row.author_name },
    content: row.content,
    nsfw_flag: flags.nsfw_flag,
    other_flags: flags.other_flags,
    created_at: row.created_at.toISOString(),
  };
}

const POST_SELECT = `
  SELECT p.id, p.title, p.topic, p.content, p.analysis_status, p.analysis_nsfw, p.analysis_flags,
         date_trunc('milliseconds', p.created_at) AS created_at,
         u.id AS author_id, u.name AS author_name,
         (SELECT count(*)::int FROM post_likes l WHERE l.post_id = p.id) AS reaction_count,
         (SELECT count(*)::int FROM comments c WHERE c.post_id = p.id) AS comment_count,
         EXISTS (SELECT 1 FROM post_likes ml
                 WHERE ml.post_id = p.id AND ml.user_id = $1) AS my_reaction
  FROM posts p
  JOIN users u ON u.id = p.author_id`;

const COMMENT_SELECT = `
  SELECT c.id, c.post_id, c.content, c.analysis_status, c.analysis_nsfw,
         c.analysis_flags, date_trunc('milliseconds', c.created_at) AS created_at,
         u.id AS author_id, u.name AS author_name
  FROM comments c
  JOIN users u ON u.id = c.author_id`;

/** Enqueues a feed analysis job; the job never carries text or identity. */
function enqueueFeedAnalysisJob(
  client: PoolClient,
  contentType: 'post' | 'comment',
  contentId: string,
  contentRevision: number,
): Promise<unknown> {
  return client.query(
    `INSERT INTO jobs (kind, content_type, content_id, content_revision)
     VALUES ('analyze_feed_content', $1, $2, $3)`,
    [contentType, contentId, contentRevision],
  );
}

async function postAuthor(pool: Pool, postId: string): Promise<string | null> {
  const { rows } = await pool.query('SELECT author_id FROM posts WHERE id = $1', [postId]);
  return rows[0]?.author_id ?? null;
}

export function createFeedRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();
  router.use(requireAuth);

  router.post('/', async (req, res) => {
    const body = parseWith(postContentSchema, req.body);
    const rows = await withTransaction(pool, async (client) => {
      const inserted = await client.query(
        `INSERT INTO posts (author_id, content, title, topic)
         VALUES ($1, $2, $3, $4)
         RETURNING id, title, topic, content, analysis_status, analysis_nsfw,
                   analysis_flags, content_revision, created_at`,
        [req.user!.id, body.content, body.title ?? null, body.topic ?? null],
      );
      const post = inserted.rows[0];
      await enqueueFeedAnalysisJob(client, 'post', post.id, post.content_revision);
      return inserted.rows;
    });
    const row = rows[0];
    res.status(201).json(
      postJson({
        ...row,
        author_id: req.user!.id,
        author_name: req.user!.name,
        reaction_count: 0,
        comment_count: 0,
        my_reaction: false,
      }),
    );
  });

  router.get('/', async (req, res) => {
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `${POST_SELECT}
       WHERE $2::timestamptz IS NULL
         OR (date_trunc('milliseconds', p.created_at), p.id) < ($2::timestamptz, $3::uuid)
       ORDER BY p.created_at DESC, p.id DESC
       LIMIT $4`,
      [req.user!.id, cursor?.t ?? null, cursor?.i ?? null, limit + 1],
    );
    const page = buildPage(
      rows,
      limit,
      (row): PageCursor => ({ t: row.created_at.toISOString(), i: row.id }),
      postJson,
    );
    res.json(page);
  });

  router.get('/:postId', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    const { rows } = await pool.query(`${POST_SELECT} WHERE p.id = $2`, [
      req.user!.id,
      postId,
    ]);
    if (!rows[0]) throw notFound();
    res.json(postJson(rows[0]));
  });

  router.post('/:postId/reactions', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    parseWith(reactionSchema, req.body);
    if ((await postAuthor(pool, postId)) === null) throw notFound();
    // Idempotent per user: a second add keeps exactly one like row.
    await pool.query(
      `INSERT INTO post_likes (post_id, user_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [postId, req.user!.id],
    );
    const { rows } = await pool.query(
      `SELECT (SELECT count(*)::int FROM post_likes l WHERE l.post_id = $1) AS reaction_count,
              EXISTS (SELECT 1 FROM post_likes ml
                      WHERE ml.post_id = $1 AND ml.user_id = $2) AS my_reaction`,
      [postId, req.user!.id],
    );
    res.json({
      reaction_count: Number(rows[0].reaction_count),
      my_reaction: rows[0].my_reaction ? 'like' : null,
    });
  });

  router.delete('/:postId/reactions', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    if ((await postAuthor(pool, postId)) === null) throw notFound();
    await pool.query('DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2', [
      postId,
      req.user!.id,
    ]);
    const { rows } = await pool.query(
      `SELECT (SELECT count(*)::int FROM post_likes l WHERE l.post_id = $1) AS reaction_count,
              EXISTS (SELECT 1 FROM post_likes ml
                      WHERE ml.post_id = $1 AND ml.user_id = $2) AS my_reaction`,
      [postId, req.user!.id],
    );
    res.json({
      reaction_count: Number(rows[0].reaction_count),
      my_reaction: rows[0].my_reaction ? 'like' : null,
    });
  });

  router.get('/:postId/comments', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    if ((await postAuthor(pool, postId)) === null) throw notFound();
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `${COMMENT_SELECT}
       WHERE c.post_id = $1
         AND ($2::timestamptz IS NULL
              OR (date_trunc('milliseconds', c.created_at), c.id) > ($2::timestamptz, $3::uuid))
       ORDER BY c.created_at ASC, c.id ASC
       LIMIT $4`,
      [postId, cursor?.t ?? null, cursor?.i ?? null, limit + 1],
    );
    const page = buildPage(
      rows,
      limit,
      (row): PageCursor => ({ t: row.created_at.toISOString(), i: row.id }),
      commentJson,
    );
    res.json(page);
  });

  router.post('/:postId/comments', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    if ((await postAuthor(pool, postId)) === null) throw notFound();
    const body = parseWith(commentContentSchema, req.body);
    const rows = await withTransaction(pool, async (client) => {
      const inserted = await client.query(
        `INSERT INTO comments (post_id, author_id, content)
         VALUES ($1, $2, $3)
         RETURNING id, post_id, content, analysis_status, analysis_nsfw,
                   analysis_flags, content_revision, created_at`,
        [postId, req.user!.id, body.content],
      );
      const comment = inserted.rows[0];
      await enqueueFeedAnalysisJob(client, 'comment', comment.id, comment.content_revision);
      return inserted.rows;
    });
    const row = rows[0];
    res.status(201).json(
      commentJson({ ...row, author_id: req.user!.id, author_name: req.user!.name }),
    );
  });

  router.post('/:postId/group', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    const authorId = await postAuthor(pool, postId);
    if (authorId === null) throw notFound();
    if (authorId !== req.user!.id) throw forbidden();
    // A question's title makes a better group agenda than its whole body.
    const { rows: postRows } = await pool.query(
      "SELECT left(coalesce(title, content), 500) AS content FROM posts WHERE id = $1",
      [
      postId,
    ]);
    try {
      const group = await withTransaction(pool, async (client) => {
        const inserted = await client.query(
          `INSERT INTO groups (agenda, controller_id, source_post_id)
           VALUES ($1, $2, $3)
           RETURNING id, agenda, controller_id, source_post_id, created_at`,
          [postRows[0].content, req.user!.id, postId],
        );
        const group = inserted.rows[0];
        await client.query(
          `INSERT INTO group_members (group_id, user_id, role)
           VALUES ($1, $2, 'controller')`,
          [group.id, req.user!.id],
        );
        await client.query('UPDATE posts SET created_group_id = $2 WHERE id = $1', [
          postId,
          group.id,
        ]);
        return group;
      });
      res.status(201).json({
        id: group.id,
        agenda: group.agenda,
        controller_id: group.controller_id,
        source_post_id: group.source_post_id,
        created_at: group.created_at.toISOString(),
        my_role: 'controller',
        pending_count: 0,
      });
    } catch (err) {
      const constraint = uniqueConstraint(err);
      if (constraint === 'one_group_per_source_post' || constraint === 'posts_created_group_id_key') {
        throw conflict('already_converted', 'A group has already been created from this post.');
      }
      throw err;
    }
  });

  return router;
}
