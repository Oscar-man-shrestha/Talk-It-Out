import supertest from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
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

const deleteAccount = (app: ReturnType<typeof testApp>, token: string, password: unknown) =>
  supertest(app)
    .delete('/users/me')
    .set({ Authorization: `Bearer ${token}` })
    .send({ password });

const count = async (sql: string, params: unknown[] = []) =>
  (await testPool().query(`SELECT count(*)::int AS n FROM ${sql}`, params)).rows[0].n as number;

describe('DELETE /users/me', () => {
  it('needs the right password; a typo is 403, never a sign-out 401', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Wrong Pass', 'wrong-pass@example.com');
    expect((await deleteAccount(app, user.token, 'nope')).status).toBe(403);
    expect((await deleteAccount(app, user.token, 'nope')).body.error.code).toBe('wrong_password');
    expect((await deleteAccount(app, user.token, undefined)).status).toBe(422);
    expect((await supertest(app).delete('/users/me').send({ password: 'secret123' })).status).toBe(
      401,
    );
    expect((await api.get(app, '/me', user.token)).status).toBe(200);
  });

  it('hands over groups, anonymizes chat, removes the rest, and voids the token', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);

    // A group the controller is alone in, a published announcement, a feed
    // post with someone else's comment and like, and a profile picture row.
    const solo = await api.post(app, '/groups', controller.token, { agenda: 'Only me' });
    await api.post(app, `/groups/${groupId}/messages/controller`, controller.token, {
      text: 'Meeting moved to 5pm.',
    });
    const post = await api.post(app, '/posts', controller.token, { content: 'My public idea' });
    await api.post(app, `/posts/${post.body.id}/comments`, contributor.token, {
      content: 'Nice one',
    });
    await api.post(app, `/posts/${post.body.id}/reactions`, contributor.token, { type: 'like' });
    const before = await count('users');

    const res = await deleteAccount(app, controller.token, 'secret123');
    expect(res.status).toBe(204);

    // The token no longer works and the user row is gone.
    expect((await api.get(app, '/me', controller.token)).status).toBe(401);
    expect(await count('users')).toBe(before - 1);

    // D4: the remaining member now controls the shared group.
    const group = await api.get(app, `/groups/${groupId}`, contributor.token);
    expect(group.body.my_role).toBe('controller');
    expect(group.body.controller_id).toBe(contributor.id);

    // The announcement stays for the group, without a name.
    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(chat.body.items).toHaveLength(1);
    expect(chat.body.items[0].text).toBe('Meeting moved to 5pm.');
    expect(chat.body.items[0].display_sender).toBeNull();

    // The group nobody else was in is gone, and so is the feed post with
    // the comment and like other people left on it.
    expect(await count('groups WHERE id = $1', [solo.body.id])).toBe(0);
    expect(await count('posts WHERE id = $1', [post.body.id])).toBe(0);
    expect(await count('comments WHERE post_id = $1', [post.body.id])).toBe(0);
    expect(await count('post_likes WHERE post_id = $1', [post.body.id])).toBe(0);
    expect(await count('group_members WHERE user_id = $1', [controller.id])).toBe(0);
    // No feed-analysis job is left pointing at the deleted post or comment.
    expect(await count("jobs WHERE kind = 'analyze_feed_content'")).toBe(0);
  });

  it('deletes a contributor’s drafts and review notifications', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'the intro slide should mention the dataset',
      is_anonymous: true,
    });
    expect(sent.status).toBe(201);

    expect((await deleteAccount(app, contributor.token, 'secret123')).status).toBe(204);

    expect(await count('raw_messages WHERE author_id = $1', [contributor.id])).toBe(0);
    expect(await count('jobs')).toBe(0);
    expect(await count('notifications WHERE ref_id = $1', [sent.body.id])).toBe(0);
    const queue = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(queue.body.items).toHaveLength(0);
    const members = await api.get(app, `/groups/${groupId}/members`, controller.token);
    expect(members.body.items.map((m: { user_id: string }) => m.user_id)).toEqual([
      controller.id,
    ]);
  });
});
