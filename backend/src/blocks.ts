/**
 * Block and report rules shared by the feed, people and profile routes
 * (API.md 59, 60). SQL fragments take parameter references such as '$1'.
 */
import { Pool, PoolClient } from 'pg';

/** Distinct reports that hide a question from everyone but its author. */
export const REPORT_HIDE_THRESHOLD = 5;

/** True when neither person has blocked the other. */
export function notBlockedSql(me: string, other: string): string {
  return `NOT EXISTS (
    SELECT 1 FROM user_blocks ub
    WHERE (ub.blocker_id = ${me} AND ub.blocked_id = ${other})
       OR (ub.blocker_id = ${other} AND ub.blocked_id = ${me}))`;
}

/**
 * A question the viewer may see in lists: no block either way, not reported
 * by the viewer, and not hidden by reports (its author always sees it).
 */
export function visiblePostSql(me: string, post = 'p'): string {
  return `(${notBlockedSql(me, `${post}.author_id`)}
    AND NOT EXISTS (SELECT 1 FROM post_reports mr
                    WHERE mr.post_id = ${post}.id AND mr.reporter_id = ${me})
    AND (${post}.author_id = ${me}
         OR (SELECT count(*) FROM post_reports ar WHERE ar.post_id = ${post}.id) < ${REPORT_HIDE_THRESHOLD}))`;
}

export async function blockedEitherWay(client: Pool | PoolClient, a: string, b: string): Promise<boolean> {
  if (a === b) return false;
  const { rows } = await client.query(
    `SELECT 1 FROM user_blocks
     WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1)`,
    [a, b],
  );
  return rows.length > 0;
}
