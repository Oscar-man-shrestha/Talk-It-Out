import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
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

async function publish(
  app: ReturnType<typeof testApp>,
  groupId: string,
  author: { token: string },
  controller: { token: string },
  text: string,
  extra: Record<string, unknown> = {},
) {
  const sent = await api.post(app, `/groups/${groupId}/messages`, author.token, {
    text,
    is_anonymous: false,
    ...extra,
  });
  expect(sent.status).toBe(201);
  await runStubWorkerOnce(testPool());
  const acc = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
  return acc.body.published_message_id as string;
}

describe('replies', () => {
  it('a reply carries a quote of what the group already sees, anonymous stays anonymous', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const anonSent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'the rota is unfair',
      is_anonymous: true,
    });
    await runStubWorkerOnce(testPool());
    const acc = await api.post(app, `/messages/${anonSent.body.id}/accept`, controller.token);
    const original = acc.body.published_message_id as string;

    const replyId = await publish(app, groupId, contributor, controller, 'agree, lets fix it', {
      reply_to_id: original,
    });
    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    const reply = chat.body.items.find((m: { id: string }) => m.id === replyId);
    expect(reply.reply_to.id).toBe(original);
    expect(reply.reply_to.display_sender).toBeNull();
    expect(typeof reply.reply_to.text).toBe('string');
    // The quote of an anonymous message never reveals its author.
    expect(JSON.stringify(reply.reply_to)).not.toContain(contributor.id);

    const bad = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'reply to nothing',
      reply_to_id: '00000000-0000-4000-8000-000000000000',
    });
    expect(bad.status).toBe(400);
    expect(bad.body.error.code).toBe('invalid_reply');
  });
});

describe('withdraw', () => {
  it('the sender can take back a pending message; not someone else, not after a decision', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'actually never mind',
      is_anonymous: true,
    });
    const id = sent.body.id as string;
    expect((await api.post(app, `/messages/${id}/withdraw`, controller.token)).status).toBe(404);
    expect((await api.post(app, `/messages/${id}/withdraw`, contributor.token)).status).toBe(204);
    const { rows } = await testPool().query(
      `SELECT (SELECT count(*)::int FROM raw_messages) AS raw,
              (SELECT count(*)::int FROM jobs) AS jobs,
              (SELECT count(*)::int FROM notifications WHERE type = 'message_pending_review') AS notes`,
    );
    expect(rows[0]).toEqual({ raw: 0, jobs: 0, notes: 0 });

    const second = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'keep this one',
    });
    await api.post(app, `/messages/${second.body.id}/reject`, controller.token);
    const late = await api.post(app, `/messages/${second.body.id}/withdraw`, contributor.token);
    expect(late.status).toBe(409);
  });
});

describe('rewrite preview', () => {
  it('shows the sender the AI wording first; the controller sees nothing until it is sent', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const pv = await api.post(app, `/groups/${groupId}/messages/preview`, contributor.token, {
      text: 'the deploys keep breaking',
      is_anonymous: true,
    });
    expect(pv.status).toBe(202);
    const previewId = pv.body.id as string;

    // Invisible to the controller while it is a preview.
    expect((await api.get(app, `/groups/${groupId}/review-queue`, controller.token)).body.items).toEqual([]);
    expect((await api.get(app, `/groups/${groupId}/review-counts`, controller.token)).body.pending).toBe(0);
    expect((await api.get(app, `/groups/${groupId}/review-queue/${previewId}`, controller.token)).status).toBe(404);
    expect((await api.post(app, `/messages/${previewId}/accept`, controller.token)).status).toBe(404);
    expect((await api.get(app, `/groups/${groupId}/messages/mine`, contributor.token)).body.items).toEqual([]);
    expect((await api.get(app, '/notifications', controller.token)).body.items).toEqual([]);

    await runStubWorkerOnce(testPool());
    const ready = await api.get(app, `/groups/${groupId}/messages/preview/${previewId}`, contributor.token);
    expect(ready.body.pipeline_status).toBe('done');
    expect(typeof ready.body.rewritten_text).toBe('string');
    // Only the author can read their preview.
    expect(
      (await api.get(app, `/groups/${groupId}/messages/preview/${previewId}`, controller.token)).status,
    ).toBe(404);

    const sent = await api.post(
      app,
      `/groups/${groupId}/messages/preview/${previewId}/send`,
      contributor.token,
      { is_anonymous: true },
    );
    expect(sent.status).toBe(201);
    expect(sent.body.status).toBe('pending');
    const queue = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(queue.body.items).toHaveLength(1);
    expect(queue.body.items[0].pipeline_status).toBe('done'); // no second wait
    expect((await api.get(app, '/notifications', controller.token)).body.items).toHaveLength(1);
  });

  it('a discarded preview is gone; old previews are cleaned up', async () => {
    const app = testApp();
    const { contributor, groupId } = await seedGroup(app);
    const pv = await api.post(app, `/groups/${groupId}/messages/preview`, contributor.token, {
      text: 'draft one',
    });
    expect((await api.del(app, `/groups/${groupId}/messages/preview/${pv.body.id}`, contributor.token)).status).toBe(204);
    const old = await api.post(app, `/groups/${groupId}/messages/preview`, contributor.token, {
      text: 'draft two',
    });
    await testPool().query("UPDATE raw_messages SET created_at = now() - interval '2 hours' WHERE id = $1", [
      old.body.id,
    ]);
    await api.post(app, `/groups/${groupId}/messages/preview`, contributor.token, { text: 'draft three' });
    const { rows } = await testPool().query('SELECT original_text FROM raw_messages');
    expect(rows.map((r) => r.original_text)).toEqual(['draft three']);
  });
});

describe('history and search', () => {
  it('pages backwards from the latest, in reading order; search finds older messages', async () => {
    const app = testApp();
    const { controller, groupId } = await seedGroup(app);
    for (let i = 1; i <= 5; i++) {
      await api.post(app, `/groups/${groupId}/messages/controller`, controller.token, {
        text: `update number ${i}`,
      });
    }
    const latest = await api.get(app, `/groups/${groupId}/messages?before=&limit=2`, controller.token);
    expect(latest.body.items.map((m: { text: string }) => m.text)).toEqual(['update number 4', 'update number 5']);
    const older = await api.get(
      app,
      `/groups/${groupId}/messages?before=${latest.body.prev_cursor}&limit=2`,
      controller.token,
    );
    expect(older.body.items.map((m: { text: string }) => m.text)).toEqual(['update number 2', 'update number 3']);
    const oldest = await api.get(
      app,
      `/groups/${groupId}/messages?before=${older.body.prev_cursor}&limit=2`,
      controller.token,
    );
    expect(oldest.body.items.map((m: { text: string }) => m.text)).toEqual(['update number 1']);
    expect(oldest.body.prev_cursor).toBeNull();

    const found = await api.get(app, `/groups/${groupId}/messages/search?q=NUMBER%202`, controller.token);
    expect(found.body.items.map((m: { text: string }) => m.text)).toEqual(['update number 2']);
    expect((await api.get(app, `/groups/${groupId}/messages/search?q=%25`, controller.token)).status).toBe(400);
    const outsider = await registerUser(app, 'Out', 'out-search@example.com');
    expect((await api.get(app, `/groups/${groupId}/messages/search?q=update`, outsider.token)).status).toBe(403);
  });
});

describe('pins and polls', () => {
  it('the controller pins; members vote; only totals are shown', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const ann = await api.post(app, `/groups/${groupId}/messages/controller`, controller.token, {
      text: 'Retro is on Friday',
    });
    expect((await api.post(app, `/groups/${groupId}/messages/${ann.body.id}/pin`, contributor.token)).status).toBe(403);
    expect((await api.post(app, `/groups/${groupId}/messages/${ann.body.id}/pin`, controller.token)).status).toBe(204);

    const poll = await api.post(app, `/groups/${groupId}/polls`, controller.token, {
      question: 'Which day suits the retro?',
      options: ['Thursday', 'Friday'],
    });
    expect(poll.status).toBe(201);
    expect(poll.body.poll.options).toEqual([
      { text: 'Thursday', votes: 0 },
      { text: 'Friday', votes: 0 },
    ]);
    const pollId = poll.body.poll.id as string;
    expect((await api.post(app, `/groups/${groupId}/polls`, contributor.token, { question: 'x', options: ['a', 'b'] })).status).toBe(403);

    expect((await api.post(app, `/groups/${groupId}/polls/${pollId}/vote`, contributor.token, { option_index: 1 })).status).toBe(204);
    expect((await api.post(app, `/groups/${groupId}/polls/${pollId}/vote`, controller.token, { option_index: 1 })).status).toBe(204);
    // Changing your vote replaces it.
    await api.post(app, `/groups/${groupId}/polls/${pollId}/vote`, controller.token, { option_index: 0 });
    expect((await api.post(app, `/groups/${groupId}/polls/${pollId}/vote`, contributor.token, { option_index: 5 })).status).toBe(400);

    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    const pinned = chat.body.items.find((m: { id: string }) => m.id === ann.body.id);
    expect(pinned.pinned).toBe(true);
    const pollMsg = chat.body.items.find((m: { poll: unknown }) => m.poll);
    expect(pollMsg.poll.options.map((o: { votes: number }) => o.votes)).toEqual([1, 1]);
    expect(pollMsg.poll.total_votes).toBe(2);
    expect(pollMsg.poll.my_vote).toBe(1);
    // Nobody sees who voted.
    expect(JSON.stringify(pollMsg.poll)).not.toContain(controller.id);
    expect(JSON.stringify(pollMsg.poll)).not.toContain(contributor.id);

    await api.del(app, `/groups/${groupId}/polls/${pollId}/vote`, contributor.token);
    const after = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(after.body.items.find((m: { poll: unknown }) => m.poll).poll.my_vote).toBeNull();
  });
});
