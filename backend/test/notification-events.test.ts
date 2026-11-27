import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { runStubWorkerOnce } from '../src/worker/stubWorker';
import { api, closePool, ensureSchema, registerUser, resetDb, seedGroup, testApp, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

async function types(app: ReturnType<typeof testApp>, token: string): Promise<string[]> {
  const res = await api.get(app, '/notifications', token);
  return res.body.items.map((n: { type: string }) => n.type);
}

describe('notification events (API.md 73)', () => {
  it('the sender hears that their message was published (anonymous ones too)', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'please share the deck',
      is_anonymous: true,
    });
    await runStubWorkerOnce(testPool());
    const accepted = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
    expect(accepted.status).toBe(200);
    expect(await types(app, contributor.token)).toContain('message_published');
    // Nobody else is told who wrote it.
    expect(await types(app, controller.token)).not.toContain('message_published');
  });

  it('the controller hears when someone joins by invitation or by link', async () => {
    const app = testApp();
    const { controller, groupId } = await seedGroup(app);
    const joins = async () =>
      (await types(app, controller.token)).filter((t) => t === 'member_joined').length;
    const before = await joins(); // the seeded member's own join
    const invited = await registerUser(app, 'Invited Person', 'invited@example.com');
    const invite = await api.post(app, `/groups/${groupId}/members`, controller.token, {
      user_id: invited.id,
    });
    expect(invite.status).toBeLessThan(300);
    const list = await api.get(app, '/invitations', invited.token);
    await api.post(app, `/invitations/${list.body.items[0].id}/accept`, invited.token);
    expect(await joins()).toBe(before + 1);

    const linkUser = await registerUser(app, 'Link Person', 'link@example.com');
    const link = await api.post(app, `/groups/${groupId}/invites`, controller.token, {});
    const join = await api.post(app, `/invites/${link.body.code}/accept`, linkUser.token);
    expect(join.status).toBe(201);
    expect(await joins()).toBe(before + 2);
  });

  it('new likes notify the author once per unread batch, never for their own like', async () => {
    const app = testApp();
    const author = await registerUser(app, 'Author', 'author@example.com');
    const a = await registerUser(app, 'Liker A', 'likera@example.com');
    const b = await registerUser(app, 'Liker B', 'likerb@example.com');
    const post = await api.post(app, '/posts', author.token, { content: 'How do retros stay honest?' });
    const like = (token: string) =>
      api.post(app, `/posts/${post.body.id}/reactions`, token, { type: 'like' });

    await like(author.token);
    expect(await types(app, author.token)).not.toContain('question_liked');
    await like(a.token);
    await like(a.token); // idempotent
    await like(b.token);
    expect((await types(app, author.token)).filter((t) => t === 'question_liked')).toHaveLength(1);

    // After reading, the next like starts a new notification.
    await api.post(app, '/notifications/read-all', author.token);
    await api.del(app, `/posts/${post.body.id}/reactions`, b.token);
    await like(b.token);
    expect((await types(app, author.token)).filter((t) => t === 'question_liked')).toHaveLength(2);
  });
});
