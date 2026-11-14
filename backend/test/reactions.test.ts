import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import { runStubWorkerOnce } from '../src/worker/stubWorker';
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

async function publishAnonymous(app: ReturnType<typeof testApp>) {
  const seeded = await seedGroup(app);
  const sent = await api.post(app, `/groups/${seeded.groupId}/messages`, seeded.contributor.token, {
    text: 'reaction privacy text',
    is_anonymous: true,
  });
  await runStubWorkerOnce(testPool());
  const accepted = await api.post(app, `/messages/${sent.body.id}/accept`, seeded.controller.token);
  return { ...seeded, messageId: accepted.body.published_message_id as string };
}

describe('message reactions', () => {
  it('toggles reactions and returns counts plus only my own reactions', async () => {
    const app = testApp();
    const { controller, contributor, groupId, messageId } = await publishAnonymous(app);
    const path = `/groups/${groupId}/messages/${messageId}/reactions`;

    const empty = await api.get(app, path, contributor.token);
    expect(empty.status).toBe(200);
    expect(empty.body).toEqual({ message_id: messageId, reactions: {}, my_reactions: [] });

    const a = await api.post(app, path, contributor.token, { emoji: '👍' });
    expect(a.status).toBe(200);
    expect(a.body).toEqual({ message_id: messageId, reactions: { '👍': 1 }, my_reactions: ['👍'] });

    const b = await api.post(app, path, controller.token, { emoji: '👍' });
    await api.post(app, path, controller.token, { emoji: '❤️' });
    expect(b.body.reactions['👍']).toBe(2);

    const view = await api.get(app, path, contributor.token);
    expect(view.body).toEqual({
      message_id: messageId,
      reactions: { '👍': 2, '❤️': 1 },
      my_reactions: ['👍'],
    });
    // Counts only: no user ids or names anywhere.
    const json = JSON.stringify(view.body);
    expect(json).not.toContain(controller.id);
    expect(json).not.toContain(contributor.id);
    expect(json).not.toContain('reaction privacy text');

    // Toggle off.
    const off = await api.post(app, path, contributor.token, { emoji: '👍' });
    expect(off.body).toEqual({
      message_id: messageId,
      reactions: { '👍': 1, '❤️': 1 },
      my_reactions: [],
    });
  });

  it('enforces membership, valid emoji, and existing messages', async () => {
    const app = testApp();
    const { contributor, groupId, messageId } = await publishAnonymous(app);
    const outsider = await registerUser(app, 'Out', 'out@example.com');
    const path = `/groups/${groupId}/messages/${messageId}/reactions`;

    expect((await api.get(app, path)).status).toBe(401);
    expect((await api.post(app, path, outsider.token, { emoji: '👍' })).status).toBe(403);
    const bad = await api.post(app, path, contributor.token, { emoji: '💩' });
    expect(bad.status).toBe(422);
    expect(bad.body.error.code).toBe('validation');
    const missing = await api.get(
      app,
      `/groups/${groupId}/messages/00000000-0000-4000-8000-000000000000/reactions`,
      contributor.token,
    );
    expect(missing.status).toBe(404);
    expect(
      (await api.get(app, `/groups/nope/messages/${messageId}/reactions`, contributor.token)).status,
    ).toBe(404);
  });

  it('deleting a published message removes its reactions', async () => {
    const app = testApp();
    const { controller, contributor, groupId, messageId } = await publishAnonymous(app);
    await api.post(app, `/groups/${groupId}/messages/${messageId}/reactions`, contributor.token, {
      emoji: '🔥',
    });
    expect(
      (await api.del(app, `/groups/${groupId}/messages/${messageId}`, controller.token)).status,
    ).toBe(204);
    const { rows } = await testPool().query(
      'SELECT count(*)::int AS n FROM message_reactions WHERE message_id = $1',
      [messageId],
    );
    expect(rows[0].n).toBe(0);
  });

  it('does not change the existing chat response shape', async () => {
    const app = testApp();
    const { contributor, groupId, messageId } = await publishAnonymous(app);
    await api.post(app, `/groups/${groupId}/messages/${messageId}/reactions`, contributor.token, {
      emoji: '🎯',
    });
    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(Object.keys(chat.body.items[0]).sort()).toEqual([
      'attachment_id',
      'display_sender',
      'group_id',
      'id',
      'published_at',
      'text',
    ]);
  });
});

describe('notifications read-all', () => {
  it('marks only the caller’s unread notifications and reports the count', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    for (const text of ['one', 'two']) {
      await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
        text,
        is_anonymous: false,
      });
    }
    expect((await api.get(app, '/notifications/unread-count', controller.token)).body).toEqual({
      count: 2,
    });
    const res = await api.post(app, '/notifications/read-all', controller.token);
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ marked_count: 2 });
    expect((await api.get(app, '/notifications/unread-count', controller.token)).body).toEqual({
      count: 0,
    });
    expect((await api.post(app, '/notifications/read-all', controller.token)).body).toEqual({
      marked_count: 0,
    });
    // The contributor had none and is unaffected.
    expect((await api.post(app, '/notifications/read-all', contributor.token)).body).toEqual({
      marked_count: 0,
    });
    expect((await api.post(app, '/notifications/read-all')).status).toBe(401);
  });
});
