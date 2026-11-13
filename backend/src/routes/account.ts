import argon2 from 'argon2';
import { Router } from 'express';
import { Pool, PoolClient } from 'pg';
import { z } from 'zod';
import { withTransaction } from '../db';
import { ApiError, parseWith } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { handOverControl } from './groups';

const deleteAccountSchema = z
  .object({ password: z.string().min(1, 'Enter your password.').max(128) })
  .strict();

/**
 * DELETE /users/me — permanently deletes the caller's account (API.md 37).
 *
 * The password is required again so a stolen access token alone cannot
 * erase an account. Everything happens in one transaction:
 * - groups the user controls are handed to the earliest-joined member (D4);
 *   a group with no other member is removed with its content;
 * - the user's published group messages stay, so other members' history is
 *   intact, but they are re-marked anonymous (shown as "Anonymous user");
 * - original drafts (raw messages), their jobs and notifications, feed
 *   posts with their comments and likes, the user's own comments, likes and
 *   notifications are deleted;
 * - profile, media, reactions and refresh tokens go with the user row
 *   (ON DELETE CASCADE).
 */
export function createAccountRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();

  router.delete('/me', requireAuth, async (req, res) => {
    const body = parseWith(deleteAccountSchema, req.body);
    const userId = req.user!.id;
    const { rows } = await pool.query<{ password_hash: string }>(
      'SELECT password_hash FROM users WHERE id = $1',
      [userId],
    );
    const hash = rows[0]?.password_hash;
    if (!hash || !(await argon2.verify(hash, body.password))) {
      // 403, not 401: a 401 means "session expired" to clients, which
      // would sign the user out over a typo.
      throw new ApiError(403, 'wrong_password', 'That password is not correct.');
    }
    await withTransaction(pool, (client) => deleteAccount(client, userId));
    res.status(204).end();
  });

  return router;
}

export async function deleteAccount(client: PoolClient, userId: string): Promise<void> {
  // 1. Groups this user controls: hand over, or remove when nobody is left.
  const { rows: controlled } = await client.query<{ id: string }>(
    'SELECT id FROM groups WHERE controller_id = $1',
    [userId],
  );
  for (const { id: groupId } of controlled) {
    const next = await handOverControl(client, groupId, userId);
    if (next === null) await deleteEmptyGroup(client, groupId);
  }

  // 2. Remaining memberships.
  await client.query('DELETE FROM group_members WHERE user_id = $1', [userId]);

  // 3. Original drafts and everything that points at them.
  const draftIds = (
    await client.query<{ id: string }>('SELECT id FROM raw_messages WHERE author_id = $1', [
      userId,
    ])
  ).rows.map((r) => r.id);
  if (draftIds.length > 0) {
    await client.query('DELETE FROM jobs WHERE raw_message_id = ANY($1::uuid[])', [draftIds]);
    await client.query('DELETE FROM notifications WHERE ref_id = ANY($1::uuid[])', [draftIds]);
    await client.query('DELETE FROM raw_messages WHERE id = ANY($1::uuid[])', [draftIds]);
  }
  await client.query('UPDATE raw_messages SET decided_by = NULL WHERE decided_by = $1', [
    userId,
  ]);

  // 4. Published group messages keep the text but lose the name.
  await client.query(
    `UPDATE published_messages SET is_anonymous = true, author_id = NULL
     WHERE author_id = $1`,
    [userId],
  );

  // 5. Feed: the user's likes and comments, then their posts with the
  //    comments and likes other people left on them.
  await client.query('DELETE FROM post_likes WHERE user_id = $1', [userId]);
  const postIds = (
    await client.query<{ id: string }>('SELECT id FROM posts WHERE author_id = $1', [userId])
  ).rows.map((r) => r.id);
  // Feed-analysis jobs reference content by id without a foreign key; drop
  // the ones for comments and posts that are about to disappear.
  const commentIds = (
    await client.query<{ id: string }>(
      'SELECT id FROM comments WHERE author_id = $1 OR post_id = ANY($2::uuid[])',
      [userId, postIds],
    )
  ).rows.map((r) => r.id);
  await client.query(
    `DELETE FROM jobs WHERE kind = 'analyze_feed_content'
       AND ((content_type = 'post' AND content_id = ANY($1::uuid[]))
         OR (content_type = 'comment' AND content_id = ANY($2::uuid[])))`,
    [postIds, commentIds],
  );
  await client.query('DELETE FROM comments WHERE author_id = $1', [userId]);
  if (postIds.length > 0) {
    await client.query('UPDATE groups SET source_post_id = NULL WHERE source_post_id = ANY($1::uuid[])', [
      postIds,
    ]);
    await client.query('DELETE FROM post_likes WHERE post_id = ANY($1::uuid[])', [postIds]);
    await client.query('DELETE FROM comments WHERE post_id = ANY($1::uuid[])', [postIds]);
    await client.query('DELETE FROM posts WHERE id = ANY($1::uuid[])', [postIds]);
  }

  // 6. Notifications addressed to the user, then the user (cascades the
  //    profile, media, reactions and refresh tokens).
  await client.query('DELETE FROM notifications WHERE recipient_id = $1', [userId]);
  await client.query('DELETE FROM users WHERE id = $1', [userId]);
}

/** Removes a group whose only member was the departing controller. */
async function deleteEmptyGroup(client: PoolClient, groupId: string): Promise<void> {
  await client.query(
    'DELETE FROM jobs WHERE raw_message_id IN (SELECT id FROM raw_messages WHERE group_id = $1)',
    [groupId],
  );
  await client.query('DELETE FROM notifications WHERE group_id = $1', [groupId]);
  await client.query('DELETE FROM raw_messages WHERE group_id = $1', [groupId]);
  await client.query('DELETE FROM published_messages WHERE group_id = $1', [groupId]);
  await client.query('DELETE FROM group_members WHERE group_id = $1', [groupId]);
  await client.query('UPDATE posts SET created_group_id = NULL WHERE created_group_id = $1', [
    groupId,
  ]);
  await client.query('DELETE FROM groups WHERE id = $1', [groupId]);
}
