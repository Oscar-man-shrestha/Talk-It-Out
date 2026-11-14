/**
 * People discovery (API.md 52, 53, 54): fuzzy search, suggested people,
 * chosen @handles and feed interests.
 */
import { Router } from 'express';
import { Pool } from 'pg';
import { z } from 'zod';
import { ApiError, notFound, parseWith } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { uniqueConstraint, withTransaction } from '../db';
import { matchPerson, NameMatchKind } from '../nlp/fuzzy';
import { fold } from '../nlp/text';
import { INTEREST_IDS, INTERESTS } from '../nlp/topics';
import { mediaUrl } from './profiles';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Instagram-style: 3-30 of a-z 0-9 . _, no leading/trailing or double dot. */
export const HANDLE_RE = /^(?!\.)(?!.*\.\.)(?!.*\.$)[a-z0-9._]{3,30}$/;
const RESERVED = new Set([
  'admin', 'administrator', 'support', 'help', 'api', 'root', 'system', 'talkitout',
  'talk_it_out', 'talk.it.out', 'moderator', 'controller', 'anonymous', 'me', 'settings',
  'null', 'undefined', 'official', 'security', 'staff',
]);

export function handleProblem(handle: string): string | null {
  if (handle.length < 3) return 'Handles need at least 3 characters.';
  if (handle.length > 30) return 'Handles can have at most 30 characters.';
  if (!/^[a-z0-9._]+$/.test(handle)) return 'Use only letters, numbers, dots and underscores.';
  if (!HANDLE_RE.test(handle)) return 'A dot cannot start or end a handle, or appear twice in a row.';
  if (RESERVED.has(handle)) return 'That handle is reserved.';
  return null;
}

/** Handle ideas made from a name, best first (not checked for availability). */
export function handleIdeas(name: string, seed: string): string[] {
  const parts = fold(name).split(/[^a-z0-9]+/).filter((p) => p.length > 0).slice(0, 3);
  if (parts.length === 0) parts.push('user');
  const [first, last] = [parts[0], parts[parts.length - 1]];
  // Stable numbers per person, so suggestions do not jump around.
  let hash = 0;
  for (const ch of seed) hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
  const n1 = 10 + (hash % 90);
  const n2 = 100 + ((hash >>> 8) % 900);
  const ideas = parts.length > 1
    ? [`${first}.${last}`, `${first}${last}`, `${first}_${last}`, `${first}.${last[0]}`,
      `${last}.${first}`, `${first}${last[0]}`, `${first}.${last}${n1}`, `${first}${n2}`, `${first}_${n1}`]
    : [first, `${first}.${n1}`, `${first}_${n1}`, `the.${first}`, `${first}${n2}`, `${first}.official`];
  return [...new Set(ideas.map((h) => h.slice(0, 30)))].filter((h) => handleProblem(h) === null);
}

async function availableHandles(pool: Pool, ideas: string[], max: number): Promise<string[]> {
  if (ideas.length === 0) return [];
  const { rows } = await pool.query<{ u: string }>(
    'SELECT lower(username) AS u FROM users WHERE lower(username) = ANY($1::text[])',
    [ideas],
  );
  const taken = new Set(rows.map((r) => r.u));
  return ideas.filter((h) => !taken.has(h)).slice(0, max);
}

const searchQuery = z.object({
  q: z.string().trim().min(1, 'Type a name to search.').max(60, 'Search is too long.'),
  group_id: z.string().regex(UUID_RE, 'Unknown group.').optional(),
  limit: z.coerce.number().int().min(1).max(25).default(12),
});

const suggestedQuery = z.object({
  group_id: z.string().regex(UUID_RE, 'Unknown group.').optional(),
  limit: z.coerce.number().int().min(1).max(25).default(12),
});

const handleBody = z.object({
  handle: z.string().trim().toLowerCase().transform((v) => v.replace(/^@+/, '')),
});

const interestsBody = z.object({
  interests: z
    .array(z.enum(INTEREST_IDS as [string, ...string[]], { error: () => 'Unknown interest.' }))
    .max(INTEREST_IDS.length),
});

interface PersonRow {
  id: string;
  name: string;
  username: string;
  username_chosen: boolean;
  headline: string | null;
  avatar_media_id: string | null;
  shared_groups: number;
  in_group: boolean;
}

function escapeLike(value: string): string {
  return value.replace(/[!%_]/g, (ch) => `!${ch}`);
}

export function createPeopleRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();
  router.use(requireAuth);

  async function checkGroup(groupId: string | undefined, userId: string): Promise<void> {
    if (!groupId) return;
    const { rows } = await pool.query(
      'SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, userId],
    );
    if (!rows[0]) throw notFound('We could not find that group.');
  }

  function personJson(req: Parameters<typeof mediaUrl>[0], row: PersonRow, extra: Record<string, unknown>) {
    return {
      id: row.id,
      name: row.name,
      handle: row.username_chosen ? row.username : null,
      headline: row.headline ?? '',
      avatar_url: mediaUrl(req, row.avatar_media_id),
      shared_groups: Number(row.shared_groups),
      in_group: row.in_group,
      ...extra,
    };
  }

  const PERSON_COLUMNS = `
    u.id, u.name, u.username, u.username_chosen, p.headline, p.avatar_media_id,
    (SELECT count(*)::int FROM group_members a
       JOIN group_members b ON b.group_id = a.group_id
      WHERE a.user_id = $1 AND b.user_id = u.id) AS shared_groups,
    CASE WHEN $2::uuid IS NULL THEN false
         ELSE EXISTS (SELECT 1 FROM group_members g WHERE g.group_id = $2 AND g.user_id = u.id)
    END AS in_group`;

  // GET /users/search?q=&group_id= : fuzzy people search.
  router.get('/search', async (req, res) => {
    const query = parseWith(searchQuery, req.query);
    const me = req.user!.id;
    await checkGroup(query.group_id, me);
    const q = query.q.toLowerCase().replace(/^@+/, '').trim();
    if (q.length === 0) {
      res.json({ items: [], similar_only: false });
      return;
    }
    const rows = await withTransaction(pool, async (client) => {
      // Lower thresholds than the defaults: candidates are re-ranked below.
      await client.query("SET LOCAL pg_trgm.similarity_threshold = 0.2");
      await client.query("SET LOCAL pg_trgm.word_similarity_threshold = 0.3");
      const result = await client.query<PersonRow>(
        `SELECT ${PERSON_COLUMNS}
         FROM users u
         LEFT JOIN user_profiles p ON p.user_id = u.id
         WHERE u.id <> $1 AND (
           lower(u.username) = $3
           OR lower(u.name) LIKE $4 ESCAPE '!'
           OR (u.username_chosen AND lower(u.username) LIKE $5 ESCAPE '!')
           OR lower(u.name) % $3
           OR $3 <% lower(u.name)
           OR (u.username_chosen AND $3 <% lower(u.username))
           OR talk_name_sounds(u.name) && talk_name_sounds($3)
         )
         LIMIT 300`,
        [me, query.group_id ?? null, q, `%${escapeLike(q)}%`, `${escapeLike(q)}%`],
      );
      return result.rows;
    });

    const scored: { row: PersonRow; score: number; kind: NameMatchKind }[] = [];
    for (const row of rows) {
      const m = matchPerson(q, {
        name: row.name,
        username: row.username,
        usernameChosen: row.username_chosen,
      });
      if (!m) continue;
      // People you share groups with come first among equal matches,
      // as on Instagram.
      const social = 0.05 * Math.min(Number(row.shared_groups), 3);
      scored.push({ row, score: m.score + social, kind: m.kind });
    }
    scored.sort((a, b) => b.score - a.score || a.row.name.localeCompare(b.row.name));
    const top = scored.slice(0, query.limit);
    res.json({
      items: top.map((s) => personJson(req, s.row, { match: s.kind })),
      // True when nothing matched exactly or by prefix: the app says
      // "Showing similar names".
      similar_only: top.length > 0 && top.every((s) => s.kind !== 'exact' && s.kind !== 'prefix'),
    });
  });

  // GET /users/suggested?group_id= : people you may know.
  router.get('/suggested', async (req, res) => {
    const query = parseWith(suggestedQuery, req.query);
    const me = req.user!.id;
    await checkGroup(query.group_id, me);
    const { rows } = await pool.query<PersonRow & { liked_their_post: boolean }>(
      `WITH candidates AS (
         SELECT b.user_id AS id FROM group_members a
           JOIN group_members b ON b.group_id = a.group_id
          WHERE a.user_id = $1 AND b.user_id <> $1
         UNION
         SELECT p.author_id FROM post_likes l JOIN posts p ON p.id = l.post_id
          WHERE l.user_id = $1 AND p.author_id <> $1
         UNION
         SELECT p.author_id FROM comments c JOIN posts p ON p.id = c.post_id
          WHERE c.author_id = $1 AND p.author_id <> $1
       )
       SELECT * FROM (
         SELECT ${PERSON_COLUMNS},
                EXISTS (SELECT 1 FROM post_likes l JOIN posts pp ON pp.id = l.post_id
                         WHERE l.user_id = $1 AND pp.author_id = u.id) AS liked_their_post
         FROM candidates c
         JOIN users u ON u.id = c.id
         LEFT JOIN user_profiles p ON p.user_id = u.id
       ) s
       WHERE NOT s.in_group
       ORDER BY s.shared_groups DESC, s.liked_their_post DESC, s.name ASC
       LIMIT $3`,
      [me, query.group_id ?? null, query.limit],
    );
    res.json({
      items: rows.map((row) => {
        const shared = Number(row.shared_groups);
        const reason = shared > 1
          ? `In ${shared} of your groups`
          : shared === 1
            ? 'In one of your groups'
            : 'You liked their question';
        return personJson(req, row, { reason });
      }),
    });
  });

  // GET /users/handle-available?handle= : live check while typing.
  router.get('/handle-available', async (req, res) => {
    const { handle } = parseWith(handleBody, { handle: req.query.handle ?? '' });
    const me = req.user!.id;
    const { rows } = await pool.query<{ id: string; name: string }>(
      'SELECT id, name FROM users WHERE id = $1',
      [me],
    );
    const problem = handleProblem(handle);
    let available = problem === null;
    if (available) {
      const taken = await pool.query(
        'SELECT 1 FROM users WHERE lower(username) = $1 AND id <> $2',
        [handle, me],
      );
      available = taken.rows.length === 0;
    }
    const suggestions = available
      ? []
      : await availableHandles(pool, handleIdeas(`${rows[0]?.name ?? ''} ${handle}`.trim(), me), 4);
    res.json({
      handle,
      available,
      problem: problem ?? (available ? null : 'That handle is taken.'),
      suggestions,
    });
  });

  // GET /users/me/handle : the current handle (if chosen) and ideas.
  router.get('/me/handle', async (req, res) => {
    const me = req.user!.id;
    const { rows } = await pool.query(
      'SELECT name, username, username_chosen FROM users WHERE id = $1',
      [me],
    );
    const row = rows[0];
    res.json({
      handle: row.username_chosen ? row.username : null,
      suggestions: await availableHandles(pool, handleIdeas(row.name, me), 5),
    });
  });

  // PUT /users/me/handle {handle}
  router.put('/me/handle', async (req, res) => {
    const { handle } = parseWith(handleBody, req.body);
    const me = req.user!.id;
    const problem = handleProblem(handle);
    if (problem) throw new ApiError(422, 'validation_error', problem);
    try {
      const { rows } = await pool.query(
        `UPDATE users SET username = $2, username_chosen = true
         WHERE id = $1 AND NOT EXISTS (
           SELECT 1 FROM users o WHERE lower(o.username) = $2 AND o.id <> $1)
         RETURNING name`,
        [me, handle],
      );
      if (!rows[0]) throw new Error('taken');
    } catch (err) {
      if (err instanceof Error && (err.message === 'taken' || uniqueConstraint(err) === 'users_username_key')) {
        const { rows } = await pool.query('SELECT name FROM users WHERE id = $1', [me]);
        const suggestions = await availableHandles(pool, handleIdeas(`${rows[0]?.name ?? ''}`, me), 4);
        res.status(409).json({
          error: { code: 'handle_taken', message: 'That handle is taken.' },
          suggestions,
        });
        return;
      }
      throw err;
    }
    res.json({ handle });
  });

  // GET /users/me/interests
  router.get('/me/interests', async (req, res) => {
    const me = req.user!.id;
    const [picked, user] = await Promise.all([
      pool.query<{ interest: string }>(
        'SELECT interest FROM user_interests WHERE user_id = $1 ORDER BY created_at, interest',
        [me],
      ),
      pool.query('SELECT interests_set_at FROM users WHERE id = $1', [me]),
    ]);
    res.json({
      interests: picked.rows.map((r) => r.interest).filter((id) => INTEREST_IDS.includes(id)),
      chosen: user.rows[0]?.interests_set_at != null,
      available: INTERESTS.map(({ id, label, emoji, blurb }) => ({ id, label, emoji, blurb })),
    });
  });

  // PUT /users/me/interests {interests: [...]} : replaces the picks. An
  // empty list is allowed (the person skipped the picker).
  router.put('/me/interests', async (req, res) => {
    const body = parseWith(interestsBody, req.body);
    const me = req.user!.id;
    const unique = [...new Set(body.interests)];
    await withTransaction(pool, async (client) => {
      await client.query('DELETE FROM user_interests WHERE user_id = $1', [me]);
      if (unique.length > 0) {
        await client.query(
          `INSERT INTO user_interests (user_id, interest)
           SELECT $1, x FROM unnest($2::text[]) AS x`,
          [me, unique],
        );
      }
      await client.query('UPDATE users SET interests_set_at = now() WHERE id = $1', [me]);
    });
    res.json({ interests: unique, chosen: true });
  });

  return router;
}
