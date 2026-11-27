/**
 * GET /groups/:groupId/insights : Group Insights, a Premium feature for the
 * group's controller (API.md 71).
 *
 * Privacy: published text and counts only. Nothing names a person, nothing
 * separates one author's messages, and the breakdowns that could narrow
 * down who wrote an anonymous message (participants, anonymous share,
 * busiest hours) are only given for groups of 5 or more members.
 */
import { Router } from 'express';
import { Pool } from 'pg';
import { ApiError, forbidden, notFound } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { isPremium } from '../premium';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const INSIGHTS_WINDOW_DAYS = 14;
export const INSIGHTS_MIN_MEMBERS = 5;

const STOPWORDS = new Set(
  `about above after again against also because been before being below between both
  could does doing down during each from further have having here hers herself himself
  into itself just more most myself once only other ours ourselves over same should some
  such than that their theirs them themselves then there these they this those through
  under until very were what when where which while whom will with would your yours
  yourself yourselves please thanks thank really think going want need like make sure
  still maybe also into well just even much many every there's that's it's don't can't
  we're they're i'm you're let's`.split(/\s+/),
);

/** The most used words in published text (4+ letters, no filler words). */
export function topWords(texts: string[], limit = 8): { word: string; count: number }[] {
  const counts = new Map<string, number>();
  for (const text of texts) {
    const seen = new Set<string>();
    for (const raw of text.toLowerCase().match(/[a-z][a-z'-]{3,}/g) ?? []) {
      const word = raw.replace(/^'+|'+$/g, '');
      if (word.length < 4 || STOPWORDS.has(word) || seen.has(word)) continue;
      // Counted once per message, so one long message cannot dominate.
      seen.add(word);
      counts.set(word, (counts.get(word) ?? 0) + 1);
    }
  }
  return [...counts.entries()]
    .filter(([, count]) => count >= 2)
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([word, count]) => ({ word, count }));
}

export function createInsightsRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router({ mergeParams: true });
  router.use(requireAuth);

  router.get('/', async (req, res) => {
    const groupId = (req.params as { groupId: string }).groupId;
    if (!UUID_RE.test(groupId)) throw notFound();
    const me = req.user!.id;
    const role = await pool.query<{ role: string }>(
      'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
      [groupId, me],
    );
    if (!role.rows[0]) {
      const exists = await pool.query('SELECT 1 FROM groups WHERE id = $1', [groupId]);
      if (!exists.rows[0]) throw notFound();
      throw forbidden();
    }
    if (role.rows[0].role !== 'controller') {
      throw forbidden('Only the group’s controller can see its insights.');
    }
    if (!(await isPremium(pool, me))) {
      throw new ApiError(402, 'premium_required', 'Group Insights are part of Premium.');
    }
    // Hours are reported in the viewer's time zone (minutes east of UTC).
    const rawOffset = Number(req.query.tz_offset_minutes ?? 330);
    const offset = Number.isFinite(rawOffset) ? Math.max(-720, Math.min(840, Math.round(rawOffset))) : 330;

    const members = await pool.query<{ n: number }>(
      'SELECT count(*)::int AS n FROM group_members WHERE group_id = $1',
      [groupId],
    );
    const memberCount = members.rows[0].n;
    const breakdowns = memberCount >= INSIGHTS_MIN_MEMBERS;

    const daily = await pool.query<{ day: string; n: number }>(
      `SELECT to_char(d.day, 'YYYY-MM-DD') AS day, count(p.id)::int AS n
         FROM generate_series(
                (now() AT TIME ZONE 'UTC')::date - ($2::int - 1),
                (now() AT TIME ZONE 'UTC')::date,
                interval '1 day') AS d(day)
         LEFT JOIN published_messages p
           ON p.group_id = $1
          AND (p.published_at AT TIME ZONE 'UTC')::date = d.day::date
        GROUP BY d.day
        ORDER BY d.day`,
      [groupId, INSIGHTS_WINDOW_DAYS],
    );
    const review = await pool.query<{
      pending: number;
      accepted: number;
      rejected: number;
      median_minutes: number | null;
    }>(
      `SELECT
         count(*) FILTER (WHERE status = 'pending' AND NOT is_preview)::int AS pending,
         count(*) FILTER (WHERE status = 'accepted'
                          AND decided_at > now() - make_interval(days => $2))::int AS accepted,
         count(*) FILTER (WHERE status = 'rejected'
                          AND decided_at > now() - make_interval(days => $2))::int AS rejected,
         percentile_cont(0.5) WITHIN GROUP (
           ORDER BY extract(epoch FROM decided_at - created_at) / 60)
           FILTER (WHERE decided_by = $3 AND decided_at > now() - make_interval(days => $2))
           AS median_minutes
         FROM raw_messages
        WHERE group_id = $1`,
      [groupId, INSIGHTS_WINDOW_DAYS, me],
    );
    const texts = await pool.query<{ text: string }>(
      `SELECT text FROM published_messages
        WHERE group_id = $1 AND published_at > now() - make_interval(days => $2)
        ORDER BY published_at DESC
        LIMIT 2000`,
      [groupId, INSIGHTS_WINDOW_DAYS],
    );

    let participants: number | null = null;
    let anonymousMessages: number | null = null;
    let busiestHours: { hour: number; count: number }[] | null = null;
    if (breakdowns) {
      const people = await pool.query<{ named: number; anonymous: number }>(
        `SELECT count(DISTINCT author_id)::int AS named,
                count(*) FILTER (WHERE is_anonymous)::int AS anonymous
           FROM published_messages
          WHERE group_id = $1 AND published_at > now() - make_interval(days => $2)`,
        [groupId, INSIGHTS_WINDOW_DAYS],
      );
      participants = people.rows[0].named;
      anonymousMessages = people.rows[0].anonymous;
      const hours = await pool.query<{ hour: number; n: number }>(
        `SELECT extract(hour FROM (published_at AT TIME ZONE 'UTC') + make_interval(mins => $3))::int AS hour,
                count(*)::int AS n
           FROM published_messages
          WHERE group_id = $1 AND published_at > now() - make_interval(days => $2)
          GROUP BY 1
          ORDER BY n DESC, hour
          LIMIT 3`,
        [groupId, INSIGHTS_WINDOW_DAYS, offset],
      );
      busiestHours = hours.rows.map((r) => ({ hour: r.hour, count: r.n }));
    }

    const r = review.rows[0];
    res.json({
      window_days: INSIGHTS_WINDOW_DAYS,
      member_count: memberCount,
      breakdowns_available: breakdowns,
      messages: daily.rows.reduce((sum, d) => sum + d.n, 0),
      daily: daily.rows.map((d) => ({ date: d.day, count: d.n })),
      pending: r.pending,
      accepted: r.accepted,
      rejected: r.rejected,
      review_median_minutes:
        r.median_minutes === null ? null : Math.round(Number(r.median_minutes)),
      participants,
      anonymous_messages: anonymousMessages,
      busiest_hours: busiestHours,
      top_words: topWords(texts.rows.map((t) => t.text)),
    });
  });

  return router;
}
