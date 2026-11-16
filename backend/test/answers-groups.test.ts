import supertest from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { findMentions } from '../src/mentions';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const req = (app: ReturnType<typeof testApp>, method: 'put' | 'patch' | 'delete', path: string, token: string, body?: object) =>
  supertest(app)[method](path).set({ Authorization: `Bearer ${token}` }).send(body ?? {});

async function notes(app: ReturnType<typeof testApp>, token: string) {
  return (await api.get(app, '/notifications', token)).body.items as Array<{
    type: string;
    group: { id: string } | null;
    post: { id: string; title: string } | null;
  }>;
}

describe('answers: votes, best answer, follow, edits (API 65, 66)', () => {
  it('upvotes answers, but not your own', async () => {
    const app = testApp();
    const asker = await registerUser(app, 'Asker', 'a@example.com');
    const helper = await registerUser(app, 'Helper', 'h@example.com');
    const fan = await registerUser(app, 'Fan', 'f@example.com');
    const q = await api.post(app, '/posts', asker.token, { title: 'How to ask for a raise?', content: 'Details' });
    const ans = await api.post(app, `/posts/${q.body.id}/comments`, helper.token, { content: 'Bring data.' });
    const path = `/posts/${q.body.id}/comments/${ans.body.id}/vote`;
    expect((await api.post(app, path, helper.token)).status).toBe(422);
    expect((await api.post(app, path, fan.token)).body).toEqual({ vote_count: 1, voted_by_me: true });
    expect((await api.post(app, path, fan.token)).body.vote_count).toBe(1); // once each
    await api.post(app, path, asker.token);
    const list = await api.get(app, `/posts/${q.body.id}/comments`, fan.token);
    expect(list.body.items[0]).toMatchObject({ vote_count: 2, voted_by_me: true, is_best: false, edited_at: null });
    expect((await req(app, 'delete', path, fan.token)).body).toEqual({ vote_count: 1, voted_by_me: false });
  });

  it('the asker marks a best answer; its author is told', async () => {
    const app = testApp();
    const asker = await registerUser(app, 'Asker', 'a@example.com');
    const helper = await registerUser(app, 'Helper', 'h@example.com');
    const q = await api.post(app, '/posts', asker.token, { content: 'Question?' });
    const ans = await api.post(app, `/posts/${q.body.id}/comments`, helper.token, { content: 'Answer' });
    expect((await req(app, 'put', `/posts/${q.body.id}/best`, helper.token, { comment_id: ans.body.id })).status).toBe(403);
    const best = await req(app, 'put', `/posts/${q.body.id}/best`, asker.token, { comment_id: ans.body.id });
    expect(best.body).toEqual({ best_comment_id: ans.body.id });
    const list = await api.get(app, `/posts/${q.body.id}/comments`, helper.token);
    expect(list.body.items[0].is_best).toBe(true);
    expect((await api.get(app, `/posts/${q.body.id}`, helper.token)).body.best_comment_id).toBe(ans.body.id);
    expect((await notes(app, helper.token)).map((n) => n.type)).toContain('answer_best');
    // Clearing it, and a comment from another question, are handled.
    expect((await req(app, 'put', `/posts/${q.body.id}/best`, asker.token, { comment_id: null })).body.best_comment_id).toBeNull();
    const other = await api.post(app, '/posts', asker.token, { content: 'Other' });
    expect((await req(app, 'put', `/posts/${other.body.id}/best`, asker.token, { comment_id: ans.body.id })).status).toBe(404);
  });

  it('followers hear about new answers; the asker follows automatically', async () => {
    const app = testApp();
    const asker = await registerUser(app, 'Asker', 'a@example.com');
    const reader = await registerUser(app, 'Reader', 'r@example.com');
    const helper = await registerUser(app, 'Helper', 'h@example.com');
    const q = await api.post(app, '/posts', asker.token, { title: 'Burnout help', content: 'Tired' });
    expect(q.body.following).toBe(true);
    expect((await api.post(app, `/posts/${q.body.id}/follow`, reader.token)).body).toEqual({ following: true });
    expect((await api.get(app, `/posts/${q.body.id}`, reader.token)).body.following).toBe(true);
    await api.post(app, `/posts/${q.body.id}/comments`, helper.token, { content: 'Take a break.' });
    for (const who of [asker, reader]) {
      const n = await notes(app, who.token);
      expect(n[0]).toMatchObject({ type: 'question_answered', group: null, post: { id: q.body.id, title: 'Burnout help' } });
    }
    expect(await notes(app, helper.token)).toEqual([]);
    // Answering followed the question for the helper.
    expect((await api.get(app, `/posts/${q.body.id}`, helper.token)).body.following).toBe(true);
    expect((await req(app, 'delete', `/posts/${q.body.id}/follow`, reader.token)).body).toEqual({ following: false });
    await api.post(app, `/posts/${q.body.id}/comments`, asker.token, { content: 'Thanks' });
    expect((await notes(app, reader.token))).toHaveLength(1);
    // Unread count includes feed notifications.
    expect((await api.get(app, '/notifications/unread-count', helper.token)).body.count).toBe(1);
  });

  it('authors edit questions and answers, marked as edited', async () => {
    const app = testApp();
    const asker = await registerUser(app, 'Asker', 'a@example.com');
    const helper = await registerUser(app, 'Helper', 'h@example.com');
    const q = await api.post(app, '/posts', asker.token, { title: 'Old title', content: 'Old text' });
    expect((await req(app, 'patch', `/posts/${q.body.id}`, helper.token, { title: 'Hacked' })).status).toBe(403);
    expect((await req(app, 'patch', `/posts/${q.body.id}`, asker.token, {})).status).toBe(422);
    const edited = await req(app, 'patch', `/posts/${q.body.id}`, asker.token, { title: 'New title' });
    expect(edited.body).toMatchObject({ title: 'New title', content: 'Old text' });
    expect(edited.body.edited_at).not.toBeNull();
    const ans = await api.post(app, `/posts/${q.body.id}/comments`, helper.token, { content: 'v1' });
    expect((await req(app, 'patch', `/posts/${q.body.id}/comments/${ans.body.id}`, asker.token, { content: 'x' })).status).toBe(403);
    const fixed = await req(app, 'patch', `/posts/${q.body.id}/comments/${ans.body.id}`, helper.token, { content: 'v2' });
    expect(fixed.body).toMatchObject({ content: 'v2' });
    expect(fixed.body.edited_at).not.toBeNull();
  });
});

describe('group info, mute and pin (API 67)', () => {
  it('controllers set a description and rules; members mute and pin for themselves', async () => {
    const app = testApp();
    const ctrl = await registerUser(app, 'Controller', 'c@example.com');
    const member = await registerUser(app, 'Member', 'm@example.com');
    const g = await api.post(app, '/groups', ctrl.token, { agenda: 'Retro' });
    await api.post(app, `/groups/${g.body.id}/members`, ctrl.token, { user_id: member.id });
    expect((await req(app, 'patch', `/groups/${g.body.id}`, member.token, { rules: 'x' })).status).toBe(403);
    expect((await req(app, 'patch', `/groups/${g.body.id}`, ctrl.token, {})).status).toBe(422);
    await req(app, 'patch', `/groups/${g.body.id}`, ctrl.token, { description: 'Weekly retro', rules: 'Be kind.' });
    const settings = await req(app, 'put', `/groups/${g.body.id}/settings`, member.token, { muted: true, pinned: true });
    expect(settings.body).toEqual({ muted: true, pinned: true });
    const detail = await api.get(app, `/groups/${g.body.id}`, member.token);
    expect(detail.body).toMatchObject({ description: 'Weekly retro', rules: 'Be kind.', member_count: 2, muted: true, pinned: true });
    // Mute and pin are per person.
    const ctrlView = await api.get(app, '/groups', ctrl.token);
    expect(ctrlView.body.items[0]).toMatchObject({ muted: false, pinned: false, member_count: 2 });
    expect((await req(app, 'put', `/groups/${g.body.id}/settings`, member.token, { pinned: false })).body).toEqual({ muted: true, pinned: false });
  });
});

describe('@mentions (API 68)', () => {
  const members = [
    { id: 'a', name: 'Anita Gurung', handle: 'anita.g' },
    { id: 'b', name: 'Bikash Thapa', handle: null },
    { id: 'c', name: 'Anil Rai', handle: null },
    { id: 'd', name: 'Rohan', handle: null },
  ];

  it('finds full names, handles and unique first names', () => {
    expect(findMentions('Thanks @Anita Gurung!', members)).toEqual(['a']);
    expect(findMentions('cc @anita.g', members)).toEqual(['a']);
    expect(findMentions('@bikash can you check?', members)).toEqual(['b']);
    expect(findMentions('@Rohan, @Anil Rai', members).sort()).toEqual(['c', 'd']);
    expect(findMentions('email me at rohan@example.com', members)).toEqual([]);
    expect(findMentions('@Rohanx is not Rohan', members)).toEqual([]);
    expect(findMentions('no mentions here', members)).toEqual([]);
  });

  it('a controller announcement notifies mentioned members, not the sender', async () => {
    const app = testApp();
    const ctrl = await registerUser(app, 'Controller Person', 'c@example.com');
    const maya = await registerUser(app, 'Maya Tamang', 'maya@example.com');
    const g = await api.post(app, '/groups', ctrl.token, { agenda: 'Team' });
    await api.post(app, `/groups/${g.body.id}/members`, ctrl.token, { user_id: maya.id });
    await api.post(app, `/groups/${g.body.id}/messages/controller`, ctrl.token, {
      text: '@Maya please share the notes. @Controller Person will review.',
    });
    expect((await notes(app, maya.token)).map((n) => [n.type, n.group?.id])).toEqual([['mentioned', g.body.id]]);
    expect(await notes(app, ctrl.token)).toEqual([]);
  });
});
