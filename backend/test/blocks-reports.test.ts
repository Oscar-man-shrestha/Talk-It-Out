import supertest from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { REPORT_HIDE_THRESHOLD } from '../src/blocks';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp, testPool, acceptInvites } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const del = (app: ReturnType<typeof testApp>, path: string, token: string) =>
  supertest(app).delete(path).set({ Authorization: `Bearer ${token}` });

describe('blocking (API 59)', () => {
  it('hides both people from each other everywhere, and unblocks', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar Man', 'o@example.com');
    const troll = await registerUser(app, 'Troll Person', 't@example.com');
    const q = await api.post(app, '/posts', troll.token, { title: 'Troll question', content: 'Burnout and stress' });
    const mine = await api.post(app, '/posts', me.token, { title: 'My question', content: 'Salary and bonus' });
    await api.post(app, `/posts/${mine.body.id}/comments`, troll.token, { content: 'A rude comment' });

    expect((await api.post(app, `/users/${troll.id}/block`, me.token)).status).toBe(204);
    expect((await api.post(app, `/users/${troll.id}/block`, me.token)).status).toBe(204); // idempotent
    expect((await api.post(app, `/users/${me.id}/block`, me.token)).status).toBe(422);

    // Search, feeds, comments, question page.
    expect((await api.get(app, '/users/search?q=troll', me.token)).body.items).toEqual([]);
    expect((await api.get(app, '/users/search?q=oscar', troll.token)).body.items).toEqual([]);
    const ids = (r: { body: { items: { id: string }[] } }) => r.body.items.map((p) => p.id);
    expect(ids(await api.get(app, '/posts', me.token))).not.toContain(q.body.id);
    expect(ids(await api.get(app, '/posts?mode=for_you', me.token))).not.toContain(q.body.id);
    expect(ids(await api.get(app, '/posts', troll.token))).not.toContain(mine.body.id);
    expect(ids(await api.get(app, '/posts/search?q=troll', me.token))).toEqual([]);
    expect((await api.get(app, `/posts/${mine.body.id}/comments`, me.token)).body.items).toEqual([]);
    expect((await api.get(app, `/posts/${q.body.id}`, me.token)).status).toBe(404);
    expect((await api.post(app, `/posts/${mine.body.id}/comments`, troll.token, { content: 'again' })).status).toBe(404);

    // Profiles: the blocked person gets 404; the blocker sees just enough to unblock.
    expect((await api.get(app, `/users/${me.id}/profile`, troll.token)).status).toBe(404);
    const theirs = await api.get(app, `/users/${troll.id}/profile`, me.token);
    expect(theirs.body).toMatchObject({ blocked_by_me: true, user: { name: 'Troll Person' } });
    expect(theirs.body.user.headline).toBeUndefined();
    expect((await api.get(app, `/users/${troll.id}/posts`, me.token)).status).toBe(404);

    // Neither can add the other to a group, and the error does not say who blocked.
    const g = await api.post(app, '/groups', me.token, { agenda: 'Team' });
    const add = await api.post(app, `/groups/${g.body.id}/members`, me.token, { user_id: troll.id });
    expect(add.status).toBe(403);
    expect(add.body.error.message).toBe('You cannot add this person.');

    const list = await api.get(app, '/users/me/blocked', me.token);
    expect(list.body.items).toEqual([{ id: troll.id, name: 'Troll Person', handle: null, avatar_url: null }]);

    expect((await del(app, `/users/${troll.id}/block`, me.token)).status).toBe(204);
    expect(ids(await api.get(app, '/posts', me.token))).toContain(q.body.id);
    expect((await api.get(app, `/users/${troll.id}/profile`, me.token)).body.blocked_by_me).toBe(false);
  });
});

describe('reporting a question (API 60)', () => {
  it('hides it from the reporter, then from everyone after enough reports', async () => {
    const app = testApp();
    const author = await registerUser(app, 'Author', 'a@example.com');
    const q = await api.post(app, '/posts', author.token, { content: 'Spammy question' });
    const reporters = [];
    for (let i = 0; i < REPORT_HIDE_THRESHOLD; i++) {
      reporters.push(await registerUser(app, `R${i}`, `r${i}@example.com`));
    }
    const viewer = await registerUser(app, 'Viewer', 'v@example.com');
    const ids = async (token: string) => (await api.get(app, '/posts', token)).body.items.map((p: { id: string }) => p.id);

    expect((await api.post(app, `/posts/${q.body.id}/report`, author.token, { reason: 'spam' })).status).toBe(422);
    expect((await api.post(app, `/posts/${q.body.id}/report`, reporters[0].token, { reason: 'nope' })).status).toBe(422);
    expect((await api.post(app, `/posts/${q.body.id}/report`, reporters[0].token, { reason: 'spam' })).status).toBe(204);
    expect(await ids(reporters[0].token)).not.toContain(q.body.id);
    expect(await ids(viewer.token)).toContain(q.body.id);

    // Withdrawing a report shows it again.
    expect((await del(app, `/posts/${q.body.id}/report`, reporters[0].token)).status).toBe(204);
    expect(await ids(reporters[0].token)).toContain(q.body.id);

    for (const r of reporters) {
      await api.post(app, `/posts/${q.body.id}/report`, r.token, { reason: 'spam' });
    }
    expect(await ids(viewer.token)).not.toContain(q.body.id);
    expect(await ids(author.token)).toContain(q.body.id);

    // Deleting the question removes its reports.
    await del(app, `/posts/${q.body.id}`, author.token);
    const left = await testPool().query('SELECT count(*)::int AS n FROM post_reports');
    expect(left.rows[0].n).toBe(0);
  });
});

describe('someone else\'s profile', () => {
  it('shows shared groups and their questions', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const them = await registerUser(app, 'Anita Gurung', 'anita@example.com');
    const g = await api.post(app, '/groups', me.token, { agenda: 'Team' });
    await api.post(app, `/groups/${g.body.id}/members`, me.token, { user_id: them.id });
    await acceptInvites(app, them.token);
    const q = await api.post(app, '/posts', them.token, { title: 'Her question', content: 'Hello' });

    const profile = await api.get(app, `/users/${them.id}/profile`, me.token);
    expect(profile.body).toMatchObject({ shared_groups: 1, blocked_by_me: false });
    expect(profile.body.user.email).toBeUndefined();
    const posts = await api.get(app, `/users/${them.id}/posts`, me.token);
    expect(posts.body.items.map((p: { id: string }) => p.id)).toEqual([q.body.id]);
    expect((await api.get(app, '/users/not-a-uuid/posts', me.token)).status).toBe(404);
  });

  it('lists who liked a question (API 64), you first, without blocked people', async () => {
    const app = testApp();
    const author = await registerUser(app, 'Author', 'a@example.com');
    const me = await registerUser(app, 'Me Person', 'me@example.com');
    const fan = await registerUser(app, 'Fan One', 'fan@example.com');
    const troll = await registerUser(app, 'Troll', 'troll@example.com');
    const q = await api.post(app, '/posts', author.token, { content: 'Liked question' });
    for (const u of [fan, me, troll]) {
      await api.post(app, `/posts/${q.body.id}/reactions`, u.token, { type: 'like' });
    }
    await api.post(app, `/users/${troll.id}/block`, me.token);
    const res = await api.get(app, `/posts/${q.body.id}/likes`, me.token);
    expect(res.status).toBe(200);
    expect(res.body.total).toBe(3);
    expect(res.body.items.map((i: { name: string }) => i.name)).toEqual(['Me Person', 'Fan One']);
    expect(res.body.items[0]).toMatchObject({ is_me: true, handle: null, avatar_url: null });
    expect(JSON.stringify(res.body)).not.toContain('@example');
    expect((await api.get(app, '/posts/not-a-uuid/likes', me.token)).status).toBe(404);
  });
});

