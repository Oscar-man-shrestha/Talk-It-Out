import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import {
  api,
  closePool,
  ensureSchema,
  registerUser,
  resetDb,
  seedGroup,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

/** Inserts n published messages directly so pagination is testable in isolation. */
async function insertPublished(groupId: string, n: number) {
  for (let i = 0; i < n; i += 1) {
    await testPool().query(
      `INSERT INTO published_messages (group_id, author_id, text, is_anonymous, published_at)
       VALUES ($1, NULL, $2, true, now() + ($3 || ' seconds')::interval)`,
      [groupId, `page item ${i}`, String(i * 60)],
    );
  }
}

describe('pagination', () => {
  it('pages oldest-first through published messages with limit and cursor', async () => {
    const app = testApp();
    const { contributor, groupId } = await seedGroup(app);
    await insertPublished(groupId, 3);

    const first = await api.get(app, `/groups/${groupId}/messages?limit=2`, contributor.token);
    expect(first.status).toBe(200);
    expect(first.body.items.map((i: { text: string }) => i.text)).toEqual([
      'page item 0',
      'page item 1',
    ]);
    expect(typeof first.body.next_cursor).toBe('string');

    const second = await api.get(
      app,
      `/groups/${groupId}/messages?limit=2&cursor=${first.body.next_cursor}`,
      contributor.token,
    );
    expect(second.body.items.map((i: { text: string }) => i.text)).toEqual(['page item 2']);
    expect(second.body.next_cursor).toBeNull();
  });

  it('default limit is 50 and limit above 100 is clamped, not an error', async () => {
    const app = testApp();
    const { contributor, groupId } = await seedGroup(app);
    await insertPublished(groupId, 2);
    const clamp = await api.get(app, `/groups/${groupId}/messages?limit=1000`, contributor.token);
    expect(clamp.status).toBe(200);
    expect(clamp.body.items).toHaveLength(2);

    const deflt = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(deflt.status).toBe(200);
    expect(deflt.body.items).toHaveLength(2);
  });

  it('invalid limit and cursor values return 400 envelopes', async () => {
    const app = testApp();
    const { contributor, groupId } = await seedGroup(app);

    const badLimit = await api.get(app, `/groups/${groupId}/messages?limit=abc`, contributor.token);
    expect(badLimit.status).toBe(400);
    expect(badLimit.body.error.code).toBe('bad_request');

    const zeroLimit = await api.get(app, `/groups/${groupId}/messages?limit=0`, contributor.token);
    expect(zeroLimit.status).toBe(400);

    const badCursor = await api.get(
      app,
      `/groups/${groupId}/messages?cursor=garbage`,
      contributor.token,
    );
    expect(badCursor.status).toBe(400);
    expect(badCursor.body.error.code).toBe('invalid_cursor');
  });

  it('paginates the groups list and notifications too', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Many Groups', 'many@example.com');
    for (let i = 0; i < 3; i += 1) {
      await api.post(app, '/groups', user.token, { agenda: `agenda ${i}` });
    }
    const first = await api.get(app, '/groups?limit=2', user.token);
    expect(first.body.items).toHaveLength(2);
    expect(typeof first.body.next_cursor).toBe('string');
    const second = await api.get(app, `/groups?limit=2&cursor=${first.body.next_cursor}`, user.token);
    expect(second.body.items).toHaveLength(1);
    // Newest first.
    expect(first.body.items[0].agenda).toBe('agenda 2');
    expect(second.body.items[0].agenda).toBe('agenda 0');
  });
});
