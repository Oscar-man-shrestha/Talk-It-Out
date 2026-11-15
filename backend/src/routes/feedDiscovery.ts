/**
 * Personalised feed, feed search, topic suggestions and feed signals
 * (API.md 55, 56). Mounted at /posts before the main feed router so these
 * paths are not taken by GET /posts/:postId.
 */
import { NextFunction, Request, Response, Router } from 'express';
import { Pool } from 'pg';
import { z } from 'zod';
import { badRequest, notFound, parseWith } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { decodeCursor, encodeCursor } from '../pagination';
import { EngagedPost, rankForYou, RankPost, searchPosts, similarPosts } from '../nlp/rank';
import { classify, interestById } from '../nlp/topics';
import { POST_SELECT, POST_TOPICS, postJson, PostRow } from './feed';
import { visiblePostSql } from '../blocks';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Candidate window for ranking: recent posts only, so a request stays fast.
const CANDIDATE_DAYS = 120;
const CANDIDATE_LIMIT = 400;
const SEARCH_LIMIT = 1000;

const SIGNAL_WEIGHTS = { like: 0.5, comment: 1, save: 0.75, open: 0.2 } as const;
const NOT_INTERESTED_WEIGHT = 1.5;

const forYouQuery = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(20),
  cursor: z.string().optional(),
});

const searchQuery = z.object({
  q: z.string().trim().min(1, 'Type something to search.').max(120, 'Search is too long.'),
  limit: z.coerce.number().int().min(1).max(50).default(30),
});

const classifyBody = z.object({
  title: z.string().max(150).nullish(),
  content: z.string().max(5000).default(''),
});

const signalBody = z.object({
  kind: z.enum(['open', 'save', 'not_interested'], { error: () => 'Unknown signal.' }),
  // false undoes it (unsave, "show again").
  on: z.boolean().default(true),
});

type Row = PostRow & { in_my_groups: boolean; engaged_by_me: boolean };

export function createFeedDiscoveryRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();
  router.use(requireAuth);

  // GET /posts?mode=for_you : falls through to the plain feed otherwise.
  router.get('/', async (req: Request, res: Response, next: NextFunction) => {
    if (req.query.mode !== 'for_you') {
      next();
      return;
    }
    const query = parseWith(forYouQuery, req.query);
    let offset = 0;
    if (query.cursor) {
      const c = decodeCursor(query.cursor);
      const n = Number.parseInt(c.i, 10);
      if (c.t !== 'for_you' || !Number.isInteger(n) || n < 0) {
        throw badRequest('invalid_cursor', 'That page link is no longer valid.');
      }
      offset = n;
    }
    const me = req.user!.id;
    const settings = await pool.query('SELECT personalized FROM users WHERE id = $1', [me]);
    const personalized = settings.rows[0]?.personalized !== false;

    const [candidates, engaged, dismissed, picked] = await Promise.all([
      pool.query<Row>(
        `SELECT q.*,
                EXISTS (SELECT 1 FROM group_members a
                          JOIN group_members b ON b.group_id = a.group_id
                         WHERE a.user_id = $1 AND b.user_id = q.author_id
                           AND q.author_id <> $1) AS in_my_groups,
                (q.my_reaction OR EXISTS (SELECT 1 FROM comments c
                                           WHERE c.post_id = q.id AND c.author_id = $1)) AS engaged_by_me
         FROM (${POST_SELECT}
               WHERE p.created_at > now() - make_interval(days => $2)
                 AND ${visiblePostSql('$1')}
               ORDER BY p.created_at DESC
               LIMIT $3) q`,
        [me, CANDIDATE_DAYS, CANDIDATE_LIMIT],
      ),
      pool.query<{ title: string | null; content: string; topic: string | null; weight: number; at: Date }>(
        `SELECT p.title, p.content, p.topic, e.weight::float8 AS weight, e.at
         FROM (
           SELECT post_id, ${SIGNAL_WEIGHTS.like} AS weight, created_at AS at
             FROM post_likes WHERE user_id = $1
           UNION ALL
           SELECT post_id, ${SIGNAL_WEIGHTS.comment}, max(created_at)
             FROM comments WHERE author_id = $1 GROUP BY post_id
           UNION ALL
           SELECT post_id,
                  CASE kind WHEN 'save' THEN ${SIGNAL_WEIGHTS.save} ELSE ${SIGNAL_WEIGHTS.open} END,
                  created_at
             FROM feed_events WHERE user_id = $1 AND kind IN ('save', 'open')
         ) e
         JOIN posts p ON p.id = e.post_id
         WHERE e.at > now() - interval '180 days' AND p.author_id <> $1
         ORDER BY e.at DESC
         LIMIT 200`,
        [me],
      ),
      pool.query<{ id: string; title: string | null; content: string; topic: string | null }>(
        `SELECT p.id, p.title, p.content, p.topic
         FROM feed_events e JOIN posts p ON p.id = e.post_id
         WHERE e.user_id = $1 AND e.kind = 'not_interested'
           AND e.created_at > now() - interval '180 days'`,
        [me],
      ),
      pool.query<{ interest: string }>('SELECT interest FROM user_interests WHERE user_id = $1', [me]),
    ]);

    const disliked = new Map<string, number>();
    for (const d of dismissed.rows) {
      for (const t of classify(d.title, d.content, d.topic)) {
        disliked.set(t.id, (disliked.get(t.id) ?? 0) + NOT_INTERESTED_WEIGHT * t.score);
      }
    }
    const byId = new Map(candidates.rows.map((r) => [r.id, r]));
    const ranked = rankForYou(
      candidates.rows.map((r): RankPost => ({
        id: r.id,
        title: r.title,
        content: r.content,
        topic: r.topic,
        authorId: r.author_id,
        createdAt: r.created_at,
        likes: Number(r.reaction_count),
        comments: Number(r.comment_count),
        inMyGroups: personalized && r.in_my_groups,
        engagedByMe: r.engaged_by_me,
      })),
      // Personalisation off: only popularity and freshness, plus the posts
      // the person explicitly hid.
      {
        userId: me,
        picked: personalized ? picked.rows.map((r) => r.interest) : [],
        engaged: personalized
          ? engaged.rows.map((e): EngagedPost => ({ ...e, weight: Number(e.weight) }))
          : [],
        hidden: new Set(dismissed.rows.map((d) => d.id)),
        disliked: personalized ? disliked : new Map(),
        now: new Date(),
      },
    );

    const page = ranked.slice(offset, offset + query.limit);
    const nextOffset = offset + page.length;
    res.json({
      items: page.map((r) => ({
        ...postJson(byId.get(r.id)!),
        reason: r.reason,
        interests: r.interests,
      })),
      next_cursor: nextOffset < ranked.length ? encodeCursor({ t: 'for_you', i: String(nextOffset) }) : null,
    });
  });

  // GET /posts/search?q= : ranked, typo-tolerant search.
  router.get('/search', async (req, res) => {
    const query = parseWith(searchQuery, req.query);
    const { rows } = await pool.query<PostRow>(
      `${POST_SELECT} WHERE ${visiblePostSql('$1')} ORDER BY p.created_at DESC LIMIT $2`,
      [req.user!.id, SEARCH_LIMIT],
    );
    const result = searchPosts(rows, query.q);
    const byId = new Map(rows.map((r) => [r.id, r]));
    res.json({
      items: result.ids.slice(0, query.limit).map((id) => postJson(byId.get(id)!)),
      did_you_mean: result.didYouMean,
    });
  });

  // POST /posts/classify {title, content} : topic ideas while writing.
  router.post('/classify', async (req, res) => {
    const body = parseWith(classifyBody, req.body);
    const scores = classify(body.title ?? null, body.content);
    const topic = scores.find((s) => (POST_TOPICS as readonly string[]).includes(s.id))?.id ?? null;
    res.json({
      topic,
      interests: scores.slice(0, 3).map((s) => {
        const interest = interestById(s.id)!;
        return { id: s.id, label: interest.label, emoji: interest.emoji, score: s.score };
      }),
    });
  });

  // POST /posts/similar {title, content} : "already asked?" while writing.
  router.post('/similar', async (req, res) => {
    const body = parseWith(classifyBody, req.body);
    const { rows } = await pool.query<PostRow>(
      `${POST_SELECT} WHERE ${visiblePostSql('$1')} ORDER BY p.created_at DESC LIMIT $2`,
      [req.user!.id, SEARCH_LIMIT],
    );
    const byId = new Map(rows.map((r) => [r.id, r]));
    const hits = similarPosts(rows, body.title ?? null, body.content);
    res.json({
      items: hits.map((h) => {
        const row = byId.get(h.id)!;
        const text = row.title ?? row.content.replace(/\s+/g, ' ');
        return {
          id: row.id,
          title: text.length > 120 ? `${text.slice(0, 117)}...` : text,
          comment_count: Number(row.comment_count),
          score: h.score,
        };
      }),
    });
  });

  // POST /posts/:postId/signals {kind, on}
  router.post('/:postId/signals', async (req, res) => {
    const postId = req.params.postId;
    if (!UUID_RE.test(postId)) throw notFound();
    const body = parseWith(signalBody, req.body);
    const me = req.user!.id;
    const exists = await pool.query('SELECT 1 FROM posts WHERE id = $1', [postId]);
    if (!exists.rows[0]) throw notFound();
    if (body.kind !== 'not_interested') {
      // With personalisation off, activity is not recorded at all.
      const settings = await pool.query('SELECT personalized FROM users WHERE id = $1', [me]);
      if (settings.rows[0]?.personalized === false) {
        res.status(204).end();
        return;
      }
    }
    if (body.on) {
      await pool.query(
        `INSERT INTO feed_events (user_id, post_id, kind) VALUES ($1, $2, $3)
         ON CONFLICT (user_id, post_id, kind) DO UPDATE SET created_at = now()`,
        [me, postId, body.kind],
      );
    } else {
      await pool.query(
        'DELETE FROM feed_events WHERE user_id = $1 AND post_id = $2 AND kind = $3',
        [me, postId, body.kind],
      );
    }
    res.status(204).end();
  });

  return router;
}
