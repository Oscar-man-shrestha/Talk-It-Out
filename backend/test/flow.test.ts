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

const FORBIDDEN_GROUP_KEYS = ['raw_message_id', 'original_text', 'sender_id', 'is_anonymous'];

/** Collects every key that appears anywhere in a value, dot-separated. */
function deepKeys(value: unknown, prefix = ''): string[] {
  if (Array.isArray(value)) {
    return value.flatMap((item) => deepKeys(item, prefix));
  }
  if (value && typeof value === 'object') {
    return Object.entries(value).flatMap(([key, inner]) => [
      prefix ? `${prefix}.${key}` : key,
      ...deepKeys(inner, prefix ? `${prefix}.${key}` : key),
    ]);
  }
  return [];
}

describe('full moderation flow', () => {
  it('submit -> queue -> worker -> accept -> chat, and reject never reaches chat', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);

    // 1. Anonymous submission
    const originalText = 'the slide deck needs a better intro slide';
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: originalText,
      is_anonymous: true,
    });
    expect(sent.status).toBe(201);
    expect(Object.keys(sent.body).sort()).toEqual(['created_at', 'group_id', 'id', 'status']);
    expect(sent.body.status).toBe('pending');
    expect(sent.body.group_id).toBe(groupId);
    const messageId = sent.body.id as string;

    // 2. Queue shows it to the controller
    const queueBefore = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(queueBefore.status).toBe(200);
    expect(queueBefore.body.items).toHaveLength(1);
    expect(queueBefore.body.items[0].id).toBe(messageId);
    expect(queueBefore.body.items[0].original_text).toBe(originalText);
    expect(queueBefore.body.items[0].rewritten_text).toBeNull();

    // 3. Stub worker runs
    const workerRun = await runStubWorkerOnce(testPool());
    expect(workerRun).toMatchObject({ claimed: 1, done: 1 });

    const queueAfter = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    const item = queueAfter.body.items[0];
    expect(item.pipeline_status).toBe('done');
    expect(item.rewritten_text).toBe(`[stub rewrite] ${originalText}`);
    expect(item.intent_preservation_score).toBe(0.9);
    expect(item.relevance_score).toBe(0.8);
    expect(item.relevance_label).toBe('relevant');

    // 4. Accept
    const accepted = await api.post(app, `/messages/${messageId}/accept`, controller.token);
    expect(accepted.status).toBe(200);
    expect(Object.keys(accepted.body).sort()).toEqual(['id', 'published_message_id', 'status']);
    expect(accepted.body.status).toBe('accepted');

    // 5. Group chat shows exactly the rewrite with no sender for the anonymous one
    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(chat.status).toBe(200);
    expect(chat.body.items).toHaveLength(1);
    const published = chat.body.items[0];
    expect(Object.keys(published).sort()).toEqual([
      'display_sender',
      'group_id',
      'id',
      'published_at',
      'text',
    ]);
    expect(published.display_sender).toBeNull();
    expect(published.text).toBe(`[stub rewrite] ${originalText}`);
    expect(published.id).toBe(accepted.body.published_message_id);

    // Group-facing JSON must never leak review-side fields
    const allKeys = deepKeys(chat.body);
    for (const forbidden of FORBIDDEN_GROUP_KEYS) {
      expect(allKeys).not.toContain(forbidden);
    }

    // 6. Contributor sees status accepted on their own message
    const mine = await api.get(app, `/groups/${groupId}/messages/mine`, contributor.token);
    expect(mine.status).toBe(200);
    expect(mine.body.items).toHaveLength(1);
    const mineItem = mine.body.items[0];
    expect(Object.keys(mineItem).sort()).toEqual([
      'created_at',
      'group_id',
      'id',
      'is_anonymous',
      'status',
    ]);
    expect(mineItem.status).toBe('accepted');
    expect(mineItem.is_anonymous).toBe(true);

    // 7. A second message is rejected and never appears in chat
    const rejectedText = 'off topic rant that should never be published';
    const sent2 = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: rejectedText,
      is_anonymous: false,
    });
    await runStubWorkerOnce(testPool());
    const rejected = await api.post(app, `/messages/${sent2.body.id}/reject`, controller.token);
    expect(rejected.status).toBe(200);
    expect(rejected.body).toEqual({ id: sent2.body.id, status: 'rejected' });

    const chatAfter = await api.get(app, `/groups/${groupId}/messages`, controller.token);
    expect(chatAfter.body.items).toHaveLength(1);
    expect(JSON.stringify(chatAfter.body)).not.toContain(rejectedText);
    expect(chatAfter.body.items[0].id).not.toBe(sent2.body.id);

    const mineAfter = await api.get(app, `/groups/${groupId}/messages/mine`, contributor.token);
    expect(mineAfter.body.items).toHaveLength(2);
    const byStatus = Object.fromEntries(
      mineAfter.body.items.map((m: { id: string; status: string }) => [m.id, m.status]),
    );
    expect(byStatus[messageId]).toBe('accepted');
    expect(byStatus[sent2.body.id]).toBe('rejected');
  });

  it('non-anonymous accepted message shows display_sender {id,name}', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'signed suggestion',
      is_anonymous: false,
    });
    await runStubWorkerOnce(testPool());
    await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);

    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(chat.body.items).toHaveLength(1);
    expect(chat.body.items[0].display_sender).toEqual({
      id: contributor.id,
      name: 'Connie Contributor',
    });
  });

  it('/messages/mine returns only the caller\'s rows', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const other = await registerUser(app, 'Other Person', 'other-person@example.com');
    await api.post(app, `/groups/${groupId}/members`, controller.token, {
      username: 'other-person',
      role: 'contributor',
    });

    await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'mine only A',
      is_anonymous: true,
    });
    await api.post(app, `/groups/${groupId}/messages`, other.token, {
      text: 'mine only B',
      is_anonymous: true,
    });

    const mine = await api.get(app, `/groups/${groupId}/messages/mine`, contributor.token);
    expect(mine.body.items).toHaveLength(1);
    expect(mine.body.items[0].is_anonymous).toBe(true);

    const otherMine = await api.get(app, `/groups/${groupId}/messages/mine`, other.token);
    expect(otherMine.body.items).toHaveLength(1);
  });

  it('every item in every group-facing list has exactly the documented keys', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'shape check',
      is_anonymous: true,
    });
    await runStubWorkerOnce(testPool());
    await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);

    const chat = await api.get(app, `/groups/${groupId}/messages`, controller.token);
    expect(Object.keys(chat.body).sort()).toEqual(['items', 'next_cursor']);
    for (const item of chat.body.items) {
      expect(Object.keys(item).sort()).toEqual([
        'display_sender',
        'group_id',
        'id',
        'published_at',
        'text',
      ]);
      expect(new Date(item.published_at).toString()).not.toBe('Invalid Date');
    }

    const groupsList = await api.get(app, '/groups', contributor.token);
    for (const group of groupsList.body.items) {
      expect(Object.keys(group).sort()).toEqual([
        'agenda',
        'controller_id',
        'created_at',
        'id',
        'my_role',
        'pending_count',
        'source_post_id',
      ]);
      // group list/detail is group-facing too
      const keys = deepKeys(group);
      for (const forbidden of FORBIDDEN_GROUP_KEYS) {
        expect(keys).not.toContain(forbidden);
      }
    }
  });
});
