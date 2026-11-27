import { Router } from 'express';
import { Pool, PoolClient } from 'pg';
import { z } from 'zod';
import { ApiError, badRequest, conflict, forbidden, notFound, parseWith } from '../errors';
import { buildPage, parseListQuery, PageCursor } from '../pagination';
import { RequireAuth } from '../middleware/auth';
import { uniqueConstraint, withTransaction } from '../db';
import { blockedEitherWay, notBlockedSql, visiblePostSql } from '../blocks';
import { mediaUrl } from './profiles';
import { isPremium } from '../premium';

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

/**
 * Older questions have no topic; the topic filter falls back to these words
 * for them, the same list the app uses (lib/features/feed/data/post_topic.dart).
 */
const TOPIC_KEYWORDS: Record<(typeof POST_TOPICS)[number], string[]> = {
  workplace_policy: ['policy', 'workplace', 'remote'],
  engineering: ['engineer', 'tech', 'dashboard', 'estimate', 'nlp'],
  leadership: ['lead', 'exec'],
  compensation: ['pay', 'equity', 'compensation'],
  safety: ['safety', 'retro', 'psych'],
  culture: ['ethic', 'culture', 'offsite'],
};

// GET /posts filters (API.md 70). Applied in the database, so filtered
// pages are complete instead of a filter over what the app has loaded.
const postListFilterSchema = z.object({
  topic: z.enum(POST_TOPICS, { error: () => 'Choose one of the listed topics.' }).optional(),
  filter: z
    .enum(['unanswered', 'answered', 'discussed'], {
      error: () => 'Filter must be unanswered, answered or discussed.',
    })
    .optional(),
});

const commentContentSchema = z.object({
  content: z
    .string()
    .trim()
    .min(1, 'Write a comment first.')
    .max(5000, 'Comment is too long.'),
});

const bestAnswerSchema = z.object({
  comment_id: z.string().uuid({ error: () => 'Choose an answer.' }).nullable(),
});

const postEditSchema = postContentSchema
  .partial()
  .refine((b) => Object.keys(b).length > 0, { message: 'Change something first.' });

const postReportSchema = z.object({
  reason: z.enum(['spam', 'harassment', 'hate', 'self_harm', 'misinformation', 'other'], {
    error: () => 'Choose a reason.',
  }),
});

const reactionSchema = z.object({
  type: z.literal('like', {
    error: () => 'Only "like" reactions are supported.',
  }),
});

export interface PostRow {
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
  author_premium?: boolean;
  reaction_count: number;
  comment_count: number;
  my_reaction: boolean;
  best_comment_id?: string | null;
  edited_at?: Date | null;
  following?: boolean;
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
  author_premium?: boolean;
  /** Only filled for the question's author; null for everyone else. */
  report_count?: number | null;
  reported_by_me?: boolean;
  vote_count?: number;
  voted_by_me?: boolean;
  is_best?: boolean;
  edited_at?: Date | null;
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

export function postJson(row: PostRow) {
  const flags = analysisFlags(row.analysis_status, row.analysis_nsfw, row.analysis_flags);
  return {
    id: row.id,
    // Premium badge in the named public feed only (API.md 74).
    author: { id: row.author_id, name: row.author_name, premium: row.author_premium === true },
    title: row.title ?? null,
    topic: row.topic ?? null,
    content: row.content,
    nsfw_flag: flags.nsfw_flag,
    other_flags: flags.other_flags,
    reaction_count: Number(row.reaction_count),
    my_reaction: row.my_reaction ? 'like' : null,
    comment_count: Number(row.comment_count),
    created_at: row.created_at.toISOString(),
    best_comment_id: row.best_comment_id ?? null,
    edited_at: row.edited_at ? row.edited_at.toISOString() : null,
    following: row.following ?? false,
  };
}

function commentJson(row: CommentRow) {
  const flags = analysisFlags(row.analysis_status, row.analysis_nsfw, row.analysis_flags);
  return {
    id: row.id,
    post_id: row.post_id,
    // Premium badge in the named public feed only (API.md 74).
    author: { id: row.author_id, name: row.author_name, premium: row.author_premium === true },
    content: row.content,
    nsfw_flag: flags.nsfw_flag,
    other_flags: flags.other_flags,
    created_at: row.created_at.toISOString(),
    report_count: row.report_count ?? null,
    reported_by_me: row.reported_by_me ?? false,
    vote_count: Number(row.vote_count ?? 0),
    voted_by_me: row.voted_by_me ?? false,
    is_best: row.is_best ?? false,
    edited_at: row.edited_at ? row.edited_at.toISOString() : null,
  };
}

export const POST_SELECT = `
  SELECT p.id, p.title, p.topic, p.content, p.analysis_status, p.analysis_nsfw, p.analysis_flags,
         date_trunc('milliseconds', p.created_at) AS created_at,
         u.id AS author_id, u.name AS author_name,
         EXISTS (SELECT 1 FROM subscriptions ps WHERE ps.user_id = u.id
                   AND ps.status IN ('active', 'grace', 'cancelled')
                   AND (ps.expires_at IS NULL OR ps.expires_at > now())) AS author_premium,
         (SELECT count(*)::int FROM post_likes l WHERE l.post_id = p.id) AS reaction_count,
         (SELECT count(*)::int FROM comments c WHERE c.post_id = p.id) AS comment_count,
         EXISTS (SELECT 1 FROM post_likes ml
                 WHERE ml.post_id = p.id AND ml.user_id = $1) AS my_reaction,
         p.best_comment_id,
         date_trunc('milliseconds', p.edited_at) AS edited_at,
         EXISTS (SELECT 1 FROM post_follows pf
                 WHERE pf.post_id = p.id AND pf.user_id = $1) AS following
  FROM posts p
  JOIN users u ON u.id = p.author_id`;

// $5 is the caller. Report counts are shown only to the question's author,
// who is the one who may remove a reported comment.
const COMMENT_SELECT = `
  SELECT c.id, c.post_id, c.content, c.analysis_status, c.analysis_nsfw,
         c.analysis_flags, date_trunc('milliseconds', c.created_at) AS created_at,
         u.id AS author_id, u.name AS author_name,
         EXISTS (SELECT 1 FROM subscriptions ps WHERE ps.user_id = u.id
                   AND ps.status IN ('active', 'grace', 'cancelled')
                   AND (ps.expires_at IS NULL OR ps.expires_at > now())) AS author_premium,
         CASE WHEN p.author_id = $5
              THEN (SELECT count(*)::int FROM comment_reports cr WHERE cr.comment_id = c.id)
         END AS report_count,
         EXISTS (SELECT 1 FROM comment_reports mr
                 WHERE mr.comment_id = c.id AND mr.reporter_id = $5) AS reported_by_me,
         (SELECT count(*)::int FROM comment_votes v WHERE v.comment_id = c.id) AS vote_count,
         EXISTS (SELECT 1 FROM comment_votes mv
                 WHERE mv.comment_id = c.id AND mv.user_id = $5) AS voted_by_me,
         (p.best_comment_id IS NOT DISTINCT FROM c.id) AS is_best,
         date_trunc('milliseconds', c.edited_at) AS edited_at
  FROM comments c
  JOIN users u ON u.id = c.author_id
  JOIN posts p ON p.id = c.post_id`;

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
      // You follow your own question: new answers notify you (API.md 66).
      await client.query('INSERT INTO post_follows (post_id, user_id) VALUES ($1, $2)', [
        post.id,
        req.user!.id,
      ]);
      return inserted.rows;
    });
    const row = rows[0];
    res.status(201).json(
      postJson({
        ...row,
        author_id: req.user!.id,
        author_name: req.user!.name,
        author_premium: await isPremium(pool, req.user!.id),
        reaction_count: 0,
        comment_count: 0,
        my_reaction: false,
        following: true,
      }),
    );
  });

  router.get('/', async (req, res) => {
    const { limit, cursor } = parseListQuery(req);
    const { topic, filter } = parseWith(postListFilterSchema, {
      topic: req.query.topic,
      filter: req.query.filter,
    });
    const keywords = topic ? TOPIC_KEYWORDS[topic].map((k) => `%${k}%`) : null;
    const { rows } = await pool.query(
      `${POST_SELECT}
       WHERE ($2::timestamptz IS NULL
         OR (date_trunc('milliseconds', p.created_at), p.id) < ($2::timestamptz, $3::uuid))
         AND ${visiblePostSql('$1')}
         AND ($5::text IS NULL OR p.topic = $5::text
              OR (p.topic IS NULL
                  AND lower(coalesce(p.title, '') || ' ' || p.content) LIKE ANY ($6::text[])))
         AND ($7::text IS NULL
              OR ($7::text = 'unanswered'
                  AND NOT EXISTS (SELECT 1 FROM comments fc WHERE fc.post_id = p.id))
              OR ($7::text = 'answered'
                  AND EXISTS (SELECT 1 FROM comments fc WHERE fc.post_id = p.id))
              OR ($7::text = 'discussed'
                  AND (SELECT count(*) FROM comments fc WHERE fc.post_id = p.id) >= 2))
       ORDER BY p.created_at DESC, p.id DESC
       LIMIT $4`,
      [
        req.user!.id,
        cursor?.t ?? null,
        cursor?.i ?? null,
        limit + 1,
        topic ?? null,
        keywords,
        filter ?? null,
      ],
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
    if (await blockedEitherWay(pool, req.user!.id, rows[0].author_id)) throw notFound();
    res.json(postJson(rows[0]));
  });

  // GET /posts/:postId/likes (API.md 64): who liked a question, newest
  // first. The feed is public and named, so likers are shown (like
  // Facebook); group chat reactions stay counts only. People who blocked
  // you, or whom you blocked, are left out of the list.
  router.get('/:postId/likes', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    const me = req.user!.id;
    const author = await postAuthor(pool, postId);
    if (author === null || (await blockedEitherWay(pool, me, author))) throw notFound();
    const raw = Number(req.query.limit ?? 50);
    const limit = Number.isFinite(raw) ? Math.min(100, Math.max(1, Math.round(raw))) : 50;
    const { rows } = await pool.query(
      `SELECT u.id, u.name, u.username, u.username_chosen, p.avatar_media_id,
              count(*) OVER ()::int AS shown
       FROM post_likes l
       JOIN users u ON u.id = l.user_id
       LEFT JOIN user_profiles p ON p.user_id = u.id
       WHERE l.post_id = $1 AND ${notBlockedSql('$2', 'u.id')}
       ORDER BY (u.id = $2) DESC, l.created_at DESC
       LIMIT $3`,
      [postId, me, limit],
    );
    const total = await pool.query<{ n: number }>(
      'SELECT count(*)::int AS n FROM post_likes WHERE post_id = $1',
      [postId],
    );
    res.json({
      items: rows.map((r) => ({
        id: r.id,
        name: r.name,
        handle: r.username_chosen ? r.username : null,
        avatar_url: mediaUrl(req, r.avatar_media_id),
        is_me: r.id === me,
      })),
      total: total.rows[0].n,
    });
  });

  router.post('/:postId/reactions', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    parseWith(reactionSchema, req.body);
    if ((await postAuthor(pool, postId)) === null) throw notFound();
    // Idempotent per user: a second add keeps exactly one like row.
    const liked = await pool.query(
      `INSERT INTO post_likes (post_id, user_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [postId, req.user!.id],
    );
    // The author hears about new likes once per unread batch (no spam from
    // many likes, or from liking and unliking), never about their own.
    if (liked.rowCount) {
      await pool.query(
        `INSERT INTO notifications (recipient_id, type, ref_id, post_id)
         SELECT p.author_id, 'question_liked', p.id, p.id
           FROM posts p
          WHERE p.id = $1 AND p.author_id <> $2
            AND NOT EXISTS (SELECT 1 FROM notifications n
                             WHERE n.recipient_id = p.author_id AND n.type = 'question_liked'
                               AND n.post_id = p.id AND n.read_at IS NULL)`,
        [postId, req.user!.id],
      );
    }
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
    const listAuthor = await postAuthor(pool, postId);
    if (listAuthor === null || (await blockedEitherWay(pool, req.user!.id, listAuthor))) {
      throw notFound();
    }
    const { limit, cursor } = parseListQuery(req);
    const { rows } = await pool.query(
      `${COMMENT_SELECT}
       WHERE c.post_id = $1
         AND ${notBlockedSql('$5', 'c.author_id')}
         AND ($2::timestamptz IS NULL
              OR (date_trunc('milliseconds', c.created_at), c.id) > ($2::timestamptz, $3::uuid))
       ORDER BY c.created_at ASC, c.id ASC
       LIMIT $4`,
      [postId, cursor?.t ?? null, cursor?.i ?? null, limit + 1, req.user!.id],
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
    const commentAuthor = await postAuthor(pool, postId);
    if (commentAuthor === null || (await blockedEitherWay(pool, req.user!.id, commentAuthor))) {
      throw notFound();
    }
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
      // Tell everyone following the question (not the person answering, and
      // not people who blocked them or whom they blocked).
      await client.query(
        `INSERT INTO notifications (recipient_id, type, ref_id, post_id)
         SELECT f.user_id, 'question_answered', $2, $1
         FROM post_follows f
         WHERE f.post_id = $1 AND f.user_id <> $3 AND ${notBlockedSql('$3', 'f.user_id')}`,
        [postId, comment.id, req.user!.id],
      );
      // Answering follows the question, like Quora.
      await client.query(
        'INSERT INTO post_follows (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [postId, req.user!.id],
      );
      return inserted.rows;
    });
    const row = rows[0];
    res.status(201).json(
      commentJson({
        ...row,
        author_id: req.user!.id,
        author_name: req.user!.name,
        author_premium: await isPremium(pool, req.user!.id),
      }),
    );
  });

  // ---- Follow, votes, best answer, edits (API.md 65, 66) ----------------

  router.post('/:postId/follow', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    const author = await postAuthor(pool, postId);
    if (author === null || (await blockedEitherWay(pool, req.user!.id, author))) throw notFound();
    await pool.query(
      'INSERT INTO post_follows (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [postId, req.user!.id],
    );
    res.json({ following: true });
  });

  router.delete('/:postId/follow', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    await pool.query('DELETE FROM post_follows WHERE post_id = $1 AND user_id = $2', [postId, req.user!.id]);
    res.json({ following: false });
  });

  async function voteState(commentId: string, me: string) {
    const { rows } = await pool.query<{ vote_count: number; voted_by_me: boolean }>(
      `SELECT (SELECT count(*)::int FROM comment_votes WHERE comment_id = $1) AS vote_count,
              EXISTS (SELECT 1 FROM comment_votes WHERE comment_id = $1 AND user_id = $2) AS voted_by_me`,
      [commentId, me],
    );
    return rows[0];
  }

  async function commentOf(postId: string, commentId: string) {
    if (!UUID_RE.test(postId) || !UUID_RE.test(commentId)) throw notFound();
    const { rows } = await pool.query<{ author_id: string; post_author: string }>(
      `SELECT c.author_id, p.author_id AS post_author
       FROM comments c JOIN posts p ON p.id = c.post_id
       WHERE c.id = $1 AND c.post_id = $2`,
      [commentId, postId],
    );
    if (!rows[0]) throw notFound();
    return rows[0];
  }

  router.post('/:postId/comments/:commentId/vote', async (req, res) => {
    const { postId, commentId } = req.params;
    const comment = await commentOf(postId, commentId);
    const me = req.user!.id;
    if (await blockedEitherWay(pool, me, comment.author_id)) throw notFound();
    if (comment.author_id === me) {
      throw new ApiError(422, 'validation_error', 'You cannot upvote your own answer.');
    }
    await pool.query(
      'INSERT INTO comment_votes (comment_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [commentId, me],
    );
    res.json(await voteState(commentId, me));
  });

  router.delete('/:postId/comments/:commentId/vote', async (req, res) => {
    const { postId, commentId } = req.params;
    await commentOf(postId, commentId);
    await pool.query('DELETE FROM comment_votes WHERE comment_id = $1 AND user_id = $2', [
      commentId,
      req.user!.id,
    ]);
    res.json(await voteState(commentId, req.user!.id));
  });

  // PUT /posts/:postId/best {comment_id|null}: the asker picks the answer
  // that helped most (like Stack Overflow). One at a time.
  router.put('/:postId/best', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    const body = parseWith(bestAnswerSchema, req.body);
    const author = await postAuthor(pool, postId);
    if (author === null) throw notFound();
    if (author !== req.user!.id) throw forbidden();
    let commentAuthor: string | null = null;
    if (body.comment_id) {
      commentAuthor = (await commentOf(postId, body.comment_id)).author_id;
    }
    await withTransaction(pool, async (client) => {
      const before = await client.query<{ best_comment_id: string | null }>(
        'SELECT best_comment_id FROM posts WHERE id = $1 FOR UPDATE',
        [postId],
      );
      await client.query('UPDATE posts SET best_comment_id = $2 WHERE id = $1', [postId, body.comment_id]);
      const changed = before.rows[0]?.best_comment_id !== body.comment_id;
      if (changed && body.comment_id && commentAuthor && commentAuthor !== req.user!.id) {
        await client.query(
          `INSERT INTO notifications (recipient_id, type, ref_id, post_id)
           VALUES ($1, 'answer_best', $2, $3)`,
          [commentAuthor, body.comment_id, postId],
        );
      }
    });
    res.json({ best_comment_id: body.comment_id });
  });

  // PATCH /posts/:postId {title?, topic?, content?}: the author edits; the
  // question is marked "edited" and checked again.
  router.patch('/:postId', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    const author = await postAuthor(pool, postId);
    if (author === null) throw notFound();
    if (author !== req.user!.id) throw forbidden();
    const body = parseWith(postEditSchema, req.body);
    await withTransaction(pool, async (client) => {
      const { rows } = await client.query<{ content_revision: number }>(
        `UPDATE posts SET
           content = COALESCE($2, content),
           title = CASE WHEN $5 THEN $3 ELSE title END,
           topic = CASE WHEN $6 THEN $4 ELSE topic END,
           edited_at = now(),
           content_revision = content_revision + 1,
           analysis_status = 'pending'
         WHERE id = $1
         RETURNING content_revision`,
        [postId, body.content ?? null, body.title ?? null, body.topic ?? null, 'title' in body, 'topic' in body],
      );
      await enqueueFeedAnalysisJob(client, 'post', postId, rows[0].content_revision);
    });
    const { rows } = await pool.query(`${POST_SELECT} WHERE p.id = $2`, [req.user!.id, postId]);
    res.json(postJson(rows[0]));
  });

  router.patch('/:postId/comments/:commentId', async (req, res) => {
    const { postId, commentId } = req.params;
    const comment = await commentOf(postId, commentId);
    if (comment.author_id !== req.user!.id) throw forbidden();
    const body = parseWith(commentContentSchema, req.body);
    await withTransaction(pool, async (client) => {
      const { rows } = await client.query<{ content_revision: number }>(
        `UPDATE comments SET content = $2, edited_at = now(),
           content_revision = content_revision + 1, analysis_status = 'pending'
         WHERE id = $1 RETURNING content_revision`,
        [commentId, body.content],
      );
      await enqueueFeedAnalysisJob(client, 'comment', commentId, rows[0].content_revision);
    });
    // COMMENT_SELECT names the caller $5; here it is the second parameter.
    const { rows } = await pool.query(`${COMMENT_SELECT.replaceAll('$5', '$2')} WHERE c.id = $1`, [
      commentId,
      req.user!.id,
    ]);
    res.json(commentJson(rows[0]));
  });

  // Delete your own question with its likes and comments. A group started
  // from it keeps running; it just no longer links back to the question.
  router.delete('/:postId', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    const authorId = await postAuthor(pool, postId);
    if (authorId === null) throw notFound();
    if (authorId !== req.user!.id) throw forbidden();
    await withTransaction(pool, async (client) => {
      await client.query(
        `DELETE FROM jobs WHERE kind = 'analyze_feed_content'
           AND ((content_type = 'post' AND content_id = $1)
             OR (content_type = 'comment'
                 AND content_id IN (SELECT id FROM comments WHERE post_id = $1)))`,
        [postId],
      );
      await client.query('UPDATE groups SET source_post_id = NULL WHERE source_post_id = $1', [postId]);
      await client.query('DELETE FROM post_likes WHERE post_id = $1', [postId]);
      await client.query('DELETE FROM comments WHERE post_id = $1', [postId]);
      await client.query('DELETE FROM posts WHERE id = $1', [postId]);
    });
    res.status(204).end();
  });

  async function commentOwners(postId: string, commentId: string) {
    if (!UUID_RE.test(postId) || !UUID_RE.test(commentId)) throw notFound();
    const { rows } = await pool.query(
      `SELECT c.author_id AS comment_author, p.author_id AS post_author
       FROM comments c JOIN posts p ON p.id = c.post_id
       WHERE c.id = $1 AND c.post_id = $2`,
      [commentId, postId],
    );
    if (!rows[0]) throw notFound();
    return rows[0] as { comment_author: string; post_author: string };
  }

  // Report a comment. Idempotent; nothing is hidden automatically.
  // POST /posts/:postId/report {reason} (API.md 60): hides the question
  // from the reporter; enough reports hide it from everyone but its author.
  router.post('/:postId/report', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    const body = parseWith(postReportSchema, req.body);
    const author = await postAuthor(pool, postId);
    if (author === null) throw notFound();
    if (author === req.user!.id) {
      throw new ApiError(422, 'validation_error', 'You cannot report your own question.');
    }
    await pool.query(
      `INSERT INTO post_reports (post_id, reporter_id, reason) VALUES ($1, $2, $3)
       ON CONFLICT (post_id, reporter_id) DO UPDATE SET reason = EXCLUDED.reason`,
      [postId, req.user!.id, body.reason],
    );
    res.status(204).end();
  });

  router.delete('/:postId/report', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    await pool.query('DELETE FROM post_reports WHERE post_id = $1 AND reporter_id = $2', [
      postId,
      req.user!.id,
    ]);
    res.status(204).end();
  });

  router.post('/:postId/comments/:commentId/report', async (req, res) => {
    const owners = await commentOwners(req.params.postId, req.params.commentId);
    if (owners.comment_author === req.user!.id) {
      throw badRequest('own_comment', 'You cannot report your own comment.');
    }
    await pool.query(
      `INSERT INTO comment_reports (comment_id, reporter_id) VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [req.params.commentId, req.user!.id],
    );
    res.status(204).end();
  });

  router.delete('/:postId/comments/:commentId/report', async (req, res) => {
    await commentOwners(req.params.postId, req.params.commentId);
    await pool.query('DELETE FROM comment_reports WHERE comment_id = $1 AND reporter_id = $2', [
      req.params.commentId,
      req.user!.id,
    ]);
    res.status(204).end();
  });

  // Remove a comment: its author, or the author of the question it is on.
  router.delete('/:postId/comments/:commentId', async (req, res) => {
    const owners = await commentOwners(req.params.postId, req.params.commentId);
    const me = req.user!.id;
    if (owners.comment_author !== me && owners.post_author !== me) throw forbidden();
    await withTransaction(pool, async (client) => {
      await client.query(
        `DELETE FROM jobs WHERE kind = 'analyze_feed_content'
           AND content_type = 'comment' AND content_id = $1`,
        [req.params.commentId],
      );
      await client.query('DELETE FROM comments WHERE id = $1', [req.params.commentId]);
    });
    res.status(204).end();
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
        description: '',
        rules: '',
        member_count: 1,
        muted: false,
        pinned: false,
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
