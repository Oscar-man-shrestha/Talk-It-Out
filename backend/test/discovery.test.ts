import supertest from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { pruneFeedEvents } from '../src/retention';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp, testPool, acceptInvites } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

async function makeGroup(app: ReturnType<typeof testApp>, token: string, agenda = 'Team') {
  const res = await api.post(app, '/groups', token, { agenda });
  expect(res.status).toBe(201);
  return res.body.id as string;
}

describe('people search (API 52)', () => {
  it('finds names by prefix, typo and sound, people you know first', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar Man', 'oscar@example.com');
    const rohan = await registerUser(app, 'Rohan Shrestha', 'rohan@example.com');
    const rohanB = await registerUser(app, 'Rohan Basnet', 'rb@example.com');
    await registerUser(app, 'Priya Rao', 'priya.private@example.com');

    // I share a group with Rohan Basnet only.
    const g = await makeGroup(app, me.token);
    await api.post(app, `/groups/${g}/members`, me.token, { user_id: rohanB.id });
    await acceptInvites(app, rohanB.token);

    const prefix = await api.get(app, '/users/search?q=roh', me.token);
    expect(prefix.status).toBe(200);
    expect(prefix.body.items.map((p: { id: string }) => p.id)).toEqual([rohanB.id, rohan.id]);
    expect(prefix.body.items[0]).toMatchObject({ match: 'prefix', shared_groups: 1, handle: null });
    expect(prefix.body.similar_only).toBe(false);

    const typo = await api.get(app, '/users/search?q=rhoan', me.token);
    expect(typo.body.items.map((p: { name: string }) => p.name)).toContain('Rohan Shrestha');
    expect(typo.body.similar_only).toBe(true);

    const sound = await api.get(app, '/users/search?q=shresta', me.token);
    expect(sound.body.items[0]?.id).toBe(rohan.id);

    // Never the caller, never the email-derived username by prefix.
    const self = await api.get(app, '/users/search?q=oscar', me.token);
    expect(self.body.items).toEqual([]);
    const hidden = await api.get(app, '/users/search?q=priya.priv', me.token);
    expect(hidden.body.items.find((p: { name: string }) => p.name === 'Priya Rao')?.match).not.toBe('exact');
    // Results never carry an email or the private username.
    expect(JSON.stringify(prefix.body)).not.toMatch(/example\.com|"username"/);
  });

  it('marks people already in the group and checks group access', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const a = await registerUser(app, 'Anita', 'a@example.com');
    const outsider = await registerUser(app, 'Out', 'out@example.com');
    const g = await makeGroup(app, me.token);
    await api.post(app, `/groups/${g}/members`, me.token, { user_id: a.id });
    await acceptInvites(app, a.token);
    const res = await api.get(app, `/users/search?q=ani&group_id=${g}`, me.token);
    expect(res.body.items[0]).toMatchObject({ id: a.id, in_group: true });
    const denied = await api.get(app, `/users/search?q=ani&group_id=${g}`, outsider.token);
    expect(denied.status).toBe(404);
    const empty = await api.get(app, '/users/search?q=', me.token);
    expect(empty.status).toBe(422);
  });

  it('suggests people from your groups who are not in this group', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const a = await registerUser(app, 'Anita', 'a@example.com');
    const b = await registerUser(app, 'Bikash', 'b@example.com');
    const g1 = await makeGroup(app, me.token, 'One');
    await api.post(app, `/groups/${g1}/members`, me.token, { user_id: a.id });
    await acceptInvites(app, a.token);
    await api.post(app, `/groups/${g1}/members`, me.token, { user_id: b.id });
    await acceptInvites(app, b.token);
    const g2 = await makeGroup(app, me.token, 'Two');
    await api.post(app, `/groups/${g2}/members`, me.token, { user_id: a.id });
    await acceptInvites(app, a.token);

    const res = await api.get(app, `/users/suggested?group_id=${g2}`, me.token);
    expect(res.status).toBe(200);
    expect(res.body.items.map((p: { id: string }) => p.id)).toEqual([b.id]);
    expect(res.body.items[0].reason).toBe('In one of your groups');
  });

  it('invites a member by user id; they join only by accepting', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const a = await registerUser(app, 'Anita', 'a@example.com');
    const g = await makeGroup(app, me.token);
    const added = await api.post(app, `/groups/${g}/members`, me.token, { user_id: a.id });
    expect(added.status).toBe(202);
    expect(added.body).toMatchObject({ user_id: a.id, status: 'invited' });
    const twice = await api.post(app, `/groups/${g}/members`, me.token, { user_id: a.id });
    expect(twice.body.error.code).toBe('already_invited');
    expect(await acceptInvites(app, a.token)).toBe(1);
    const again = await api.post(app, `/groups/${g}/members`, me.token, { user_id: a.id });
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('already_member');
    const none = await api.post(app, `/groups/${g}/members`, me.token, {});
    expect(none.status).toBe(422);
  });
});

describe('@handles (API 53)', () => {
  it('chooses a handle, rejects bad or taken ones with suggestions', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar Shrestha', 'oscar@example.com');
    const other = await registerUser(app, 'Other', 'other@example.com');

    const ideas = await api.get(app, '/users/me/handle', me.token);
    expect(ideas.body.handle).toBeNull();
    expect(ideas.body.suggestions[0]).toBe('oscar.shrestha');

    expect((await api.put(app, '/users/me/handle', me.token, { handle: '.bad' })).status).toBe(422);
    expect((await api.put(app, '/users/me/handle', me.token, { handle: 'admin' })).status).toBe(422);
    const ok = await api.put(app, '/users/me/handle', me.token, { handle: '@Oscar.S' });
    expect(ok.status).toBe(200);
    expect(ok.body.handle).toBe('oscar.s');

    const taken = await api.put(app, '/users/me/handle', other.token, { handle: 'oscar.s' });
    expect(taken.status).toBe(409);
    expect(taken.body.error.code).toBe('handle_taken');
    expect(taken.body.suggestions.length).toBeGreaterThan(0);

    const check = await api.get(app, '/users/handle-available?handle=oscar.s', other.token);
    expect(check.body).toMatchObject({ available: false, problem: 'That handle is taken.' });
    const free = await api.get(app, '/users/handle-available?handle=someone.new', other.token);
    expect(free.body.available).toBe(true);

    // A chosen handle is searchable by prefix and shown on the profile.
    const found = await api.get(app, '/users/search?q=@oscar.', other.token);
    expect(found.body.items[0]).toMatchObject({ id: me.id, handle: 'oscar.s' });
    const profile = await api.get(app, `/users/${me.id}/profile`, other.token);
    expect(profile.body.user.handle).toBe('oscar.s');
  });

  it('hides the email-derived username on other people\'s profiles', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'secret.local@example.com');
    const other = await registerUser(app, 'Other', 'other@example.com');
    const theirs = await api.get(app, `/users/${me.id}/profile`, other.token);
    expect(theirs.body.user.username).toBeNull();
    expect(theirs.body.user.handle).toBeNull();
    const mine = await api.get(app, `/users/${me.id}/profile`, me.token);
    expect(mine.body.user.username).toBe('secret.local');
  });
});

describe('interests and For You (API 54, 55)', () => {
  it('stores picked interests; the picker counts as done even when skipped', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const before = await api.get(app, '/users/me/interests', me.token);
    expect(before.body).toMatchObject({ interests: [], chosen: false });
    expect(before.body.available).toHaveLength(30);
    expect(before.body.available[0]).toHaveProperty('icon');

    const bad = await api.put(app, '/users/me/interests', me.token, { interests: ['astrology'] });
    expect(bad.status).toBe(422);
    const put = await api.put(app, '/users/me/interests', me.token, {
      interests: ['career_growth', 'wellbeing', 'career_growth'],
    });
    expect(put.body).toEqual({ interests: ['career_growth', 'wellbeing'], chosen: true });
    const skipped = await registerUser(app, 'Skip', 's@example.com');
    await api.put(app, '/users/me/interests', skipped.token, { interests: [] });
    expect((await api.get(app, '/users/me/interests', skipped.token)).body.chosen).toBe(true);
  });

  it('ranks by interest, explains why, hides "Not interested", pages', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const author = await registerUser(app, 'Author', 'author@example.com');
    const pay = await api.post(app, '/posts', author.token, {
      title: 'Negotiating a raise', content: 'How do I ask for a salary raise and a bonus?',
    });
    const burn = await api.post(app, '/posts', author.token, {
      title: 'Burnout', content: 'I am exhausted from working every weekend.',
    });
    await api.post(app, '/posts', author.token, { content: 'Our code review takes days.' });
    await api.put(app, '/users/me/interests', me.token, { interests: ['wellbeing'] });

    const feed = await api.get(app, '/posts?mode=for_you&limit=2', me.token);
    expect(feed.status).toBe(200);
    expect(feed.body.items[0].id).toBe(burn.body.id);
    expect(feed.body.items[0].reason).toMatchObject({
      kind: 'interest', text: 'Because you follow Wellbeing & burnout', interest: 'wellbeing',
    });
    expect(feed.body.items[0].interests[0]).toBe('wellbeing');
    expect(feed.body.next_cursor).toBeTruthy();
    const page2 = await api.get(app, `/posts?mode=for_you&limit=2&cursor=${feed.body.next_cursor}`, me.token);
    expect(page2.body.items).toHaveLength(1);
    expect(page2.body.next_cursor).toBeNull();

    const hide = await api.post(app, `/posts/${burn.body.id}/signals`, me.token, { kind: 'not_interested' });
    expect(hide.status).toBe(204);
    const after = await api.get(app, '/posts?mode=for_you', me.token);
    expect(after.body.items.map((p: { id: string }) => p.id)).not.toContain(burn.body.id);
    await api.post(app, `/posts/${burn.body.id}/signals`, me.token, { kind: 'not_interested', on: false });
    const back = await api.get(app, '/posts?mode=for_you', me.token);
    expect(back.body.items.map((p: { id: string }) => p.id)).toContain(burn.body.id);

    // Plain feed is unchanged and has no reasons.
    const latest = await api.get(app, '/posts', me.token);
    expect(latest.body.items[0]).not.toHaveProperty('reason');
    expect(latest.body.items).toHaveLength(3);
    expect(pay.status).toBe(201);
  });

  it('learns from likes', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const author = await registerUser(app, 'Author', 'author@example.com');
    const liked = await api.post(app, '/posts', author.token, { content: 'Remote work across time zones is hard' });
    const remote2 = await api.post(app, '/posts', author.token, { content: 'Hybrid work and return to office rules' });
    await api.post(app, '/posts', author.token, { content: 'Salary negotiation and bonus' });
    await api.post(app, `/posts/${liked.body.id}/reactions`, me.token, { type: 'like' });
    const feed = await api.get(app, '/posts?mode=for_you', me.token);
    expect(feed.body.items[0].id).toBe(remote2.body.id);
    expect(feed.body.items[0].reason.kind).toBe('learned');
  });

  it('rejects bad cursors and signals', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const bad = await api.get(app, '/posts?mode=for_you&cursor=nope', me.token);
    expect(bad.status).toBe(400);
    const p = await api.post(app, '/posts', me.token, { content: 'hello' });
    expect((await api.post(app, `/posts/${p.body.id}/signals`, me.token, { kind: 'stare' })).status).toBe(422);
    expect((await api.post(app, '/posts/00000000-0000-4000-8000-000000000000/signals', me.token, { kind: 'open' })).status).toBe(404);
  });
});

describe('feed search and topic ideas (API 56)', () => {
  it('searches with word families and typos', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const promo = await api.post(app, '/posts', me.token, { title: 'Promotion', content: 'How was your promotion decided?' });
    await api.post(app, '/posts', me.token, { content: 'Lunch options near the office' });
    const res = await api.get(app, '/posts/search?q=promoted', me.token);
    expect(res.status).toBe(200);
    expect(res.body.items.map((p: { id: string }) => p.id)).toEqual([promo.body.id]);
    const typo = await api.get(app, '/posts/search?q=promtion', me.token);
    expect(typo.body.items[0].id).toBe(promo.body.id);
    expect(typo.body.did_you_mean).toBe('promotion');
  });

  it('suggests a topic for a draft', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const res = await api.post(app, '/posts/classify', me.token, {
      title: 'Is my pay fair?', content: 'My salary is lower than peers and there is no bonus.',
    });
    expect(res.body.topic).toBe('compensation');
    expect(res.body.interests[0]).toMatchObject({ id: 'compensation', label: 'Pay & equity', icon: 'payments' });
    const nothing = await api.post(app, '/posts/classify', me.token, { content: 'hmm' });
    expect(nothing.body).toEqual({ topic: null, interests: [] });
  });

  it('deleting an account removes interests and signals', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com', 'secret123');
    const author = await registerUser(app, 'Author', 'author@example.com');
    const p = await api.post(app, '/posts', author.token, { content: 'hello there' });
    await api.put(app, '/users/me/interests', me.token, { interests: ['learning'] });
    await api.post(app, `/posts/${p.body.id}/signals`, me.token, { kind: 'save' });
    const del = await supertest(app)
      .delete('/users/me')
      .set({ Authorization: `Bearer ${me.token}` })
      .send({ password: 'secret123' });
    expect(del.status).toBe(204);
    const left = await testPool().query(
      'SELECT (SELECT count(*) FROM user_interests)::int AS i, (SELECT count(*) FROM feed_events)::int AS e',
    );
    expect(left.rows[0]).toEqual({ i: 0, e: 0 });
  });

  it('personalisation off: no interests or activity used, opens not stored', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const author = await registerUser(app, 'Author', 'author@example.com');
    const burn = await api.post(app, '/posts', author.token, { content: 'Burnout and stress every weekend' });
    const hot = await api.post(app, '/posts', author.token, { content: 'Code review takes days' });
    const other = await registerUser(app, 'Other', 'other@example.com');
    await api.post(app, `/posts/${hot.body.id}/reactions`, other.token, { type: 'like' });
    await api.put(app, '/users/me/interests', me.token, { interests: ['wellbeing'] });

    expect((await api.get(app, '/users/me/feed-settings', me.token)).body).toEqual({ personalized: true });
    const on = await api.get(app, '/posts?mode=for_you', me.token);
    expect(on.body.items[0].id).toBe(burn.body.id);

    const off = await api.put(app, '/users/me/feed-settings', me.token, { personalized: false });
    expect(off.body).toEqual({ personalized: false });
    expect((await api.get(app, '/users/me/interests', me.token)).body.personalized).toBe(false);
    const plain = await api.get(app, '/posts?mode=for_you', me.token);
    expect(plain.body.items[0].id).toBe(hot.body.id);
    expect(plain.body.items.every((p: { reason: { kind: string } }) => ['popular', 'new'].includes(p.reason.kind))).toBe(true);

    await api.post(app, `/posts/${burn.body.id}/signals`, me.token, { kind: 'open' });
    const stored = await testPool().query("SELECT count(*)::int AS n FROM feed_events WHERE kind = 'open'");
    expect(stored.rows[0].n).toBe(0);
    expect((await api.put(app, '/users/me/feed-settings', me.token, { personalized: 'no' })).status).toBe(422);
  });

  it('lists similar questions for a draft', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const q = await api.post(app, '/posts', me.token, { title: 'How should I ask for a raise?', content: 'My salary has not changed in two years.' });
    await api.post(app, '/posts', me.token, { content: 'Best lunch spots near the office' });
    const res = await api.post(app, '/posts/similar', me.token, { title: 'Asking for a salary raise', content: 'Two years with no change in salary' });
    expect(res.status).toBe(200);
    expect(res.body.items.map((i: { id: string }) => i.id)).toEqual([q.body.id]);
    expect(res.body.items[0]).toMatchObject({ title: 'How should I ask for a raise?', comment_count: 0 });
    const none = await api.post(app, '/posts/similar', me.token, { content: 'Totally unrelated gardening tips' });
    expect(none.body.items).toEqual([]);
  });

  it('prunes feed signals older than 180 days', async () => {
    const app = testApp();
    const me = await registerUser(app, 'Oscar', 'o@example.com');
    const p = await api.post(app, '/posts', me.token, { content: 'hello there' });
    await api.post(app, `/posts/${p.body.id}/signals`, me.token, { kind: 'open' });
    await api.post(app, `/posts/${p.body.id}/signals`, me.token, { kind: 'save' });
    await testPool().query(
      "UPDATE feed_events SET created_at = now() - interval '181 days' WHERE kind = 'open'",
    );
    expect(await pruneFeedEvents(testPool())).toBe(1);
    const left = await testPool().query('SELECT kind FROM feed_events');
    expect(left.rows.map((r) => r.kind)).toEqual(['save']);
  });
});

