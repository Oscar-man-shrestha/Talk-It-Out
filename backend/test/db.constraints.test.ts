import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import { closePool, ensureSchema, resetDb, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

async function seedOneRow() {
  const pool = testPool();
  const user = await pool.query(
    `INSERT INTO users (email, username, password_hash, name)
     VALUES ('u@example.com', 'u', 'x', 'U') RETURNING id`,
  );
  const group = await pool.query(
    `INSERT INTO groups (agenda, controller_id)
     VALUES ('db test group', $1) RETURNING id`,
    [user.rows[0].id],
  );
  await pool.query(
    `INSERT INTO group_members (group_id, user_id, role)
     VALUES ($1, $2, 'controller')`,
    [group.rows[0].id, user.rows[0].id],
  );
  return { userId: user.rows[0].id as string, groupId: group.rows[0].id as string };
}

describe('database constraints', () => {
  it('rejects an anonymous published row that still has an author_id', async () => {
    const { userId, groupId } = await seedOneRow();
    await expect(
      testPool().query(
        `INSERT INTO published_messages (group_id, author_id, text, is_anonymous)
         VALUES ($1, $2, 'text', true)`,
        [groupId, userId],
      ),
    ).rejects.toMatchObject({ code: '23514' });
  });

  it('rejects a non-anonymous published row without an author_id', async () => {
    const { groupId } = await seedOneRow();
    await expect(
      testPool().query(
        `INSERT INTO published_messages (group_id, author_id, text, is_anonymous)
         VALUES ($1, NULL, 'text', false)`,
        [groupId],
      ),
    ).rejects.toMatchObject({ code: '23514' });
  });

  it('accepts the two consistent combinations', async () => {
    const { userId, groupId } = await seedOneRow();
    await expect(
      testPool().query(
        `INSERT INTO published_messages (group_id, author_id, text, is_anonymous)
         VALUES ($1, NULL, 'anon ok', true)`,
        [groupId],
      ),
    ).resolves.toBeTruthy();
    await expect(
      testPool().query(
        `INSERT INTO published_messages (group_id, author_id, text, is_anonymous)
         VALUES ($1, $2, 'signed ok', false)`,
        [groupId, userId],
      ),
    ).resolves.toBeTruthy();
  });

  it('a group cannot have two controllers', async () => {
    const { groupId } = await seedOneRow();
    const pool = testPool();
    const second = await pool.query(
      `INSERT INTO users (email, username, password_hash, name)
       VALUES ('v@example.com', 'v', 'x', 'V') RETURNING id`,
    );
    await expect(
      pool.query(
        `INSERT INTO group_members (group_id, user_id, role)
         VALUES ($1, $2, 'controller')`,
        [groupId, second.rows[0].id],
      ),
    ).rejects.toMatchObject({ code: '23505' });
  });

  it('rejects invalid enum values', async () => {
    const { userId, groupId } = await seedOneRow();
    await expect(
      testPool().query(
        `INSERT INTO raw_messages (group_id, author_id, original_text, is_anonymous, status)
         VALUES ($1, $2, 'x', false, 'banana')`,
        [groupId, userId],
      ),
    ).rejects.toMatchObject({ code: '23514' });
    await expect(
      testPool().query(
        `INSERT INTO notifications (recipient_id, type, ref_id, group_id)
         VALUES ($1, 'banana', gen_random_uuid(), $2)`,
        [userId, groupId],
      ),
    ).rejects.toMatchObject({ code: '23514' });
  });

  it('rejects scores outside 0..1', async () => {
    const { userId, groupId } = await seedOneRow();
    await expect(
      testPool().query(
        `INSERT INTO raw_messages (group_id, author_id, original_text, is_anonymous, relevance_score)
         VALUES ($1, $2, 'x', false, 1.5)`,
        [groupId, userId],
      ),
    ).rejects.toMatchObject({ code: '23514' });
  });
});
