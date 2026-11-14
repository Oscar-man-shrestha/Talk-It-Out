/**
 * Response keys and nullability must match the Flutter client's generated
 * models (the .g.dart files under lib/features and lib/core/models):
 * those files are the contract, and they crash on wrong key names/types.
 */
import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import { runStubWorkerOnce } from '../src/worker/stubWorker';
import {
  api,
  closePool,
  ensureSchema,
  resetDb,
  seedGroup,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const RAW_MESSAGE_KEYS = [
  'attachment_id',
  'created_at',
  'decided_at',
  'group_id',
  'id',
  'intent_preservation_score',
  'is_anonymous',
  'original_text',
  'pipeline_status',
  'relevance_label',
  'relevance_score',
  'rewritten_text',
  'sender_id',
  'sender_name',
  'status',
].sort();

function expectIso(value: unknown) {
  expect(typeof value).toBe('string');
  expect(new Date(value as string).toString()).not.toBe('Invalid Date');
}

describe('client-model contract', () => {
  it('auth session, user, and /me match AuthSession.g.dart / user.g.dart', async () => {
    const app = testApp();
    const reg = await api.post(app, '/auth/register', undefined, {
      name: 'Contract User',
      email: 'contract@example.com',
      password: 'secret123',
    });
    expect(Object.keys(reg.body).sort()).toEqual(['token', 'user']);
    expect(typeof reg.body.token).toBe('string');
    expect(Object.keys(reg.body.user).sort()).toEqual(['email', 'id', 'name']);

    const login = await api.post(app, '/auth/login', undefined, {
      email: 'contract@example.com',
      password: 'secret123',
    });
    expect(Object.keys(login.body).sort()).toEqual(['token', 'user']);

    const me = await api.get(app, '/me', reg.body.token);
    expect(me.status).toBe(200);
    expect(Object.keys(me.body).sort()).toEqual(['email', 'id', 'name']);
  });

  it('Group matches group.g.dart, including pending_count null for contributors', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app, {
      agenda: 'Contract agenda',
    });
    const detail = await api.get(app, `/groups/${groupId}`, controller.token);
    expect(Object.keys(detail.body).sort()).toEqual([
      'agenda',
      'controller_id',
      'created_at',
      'id',
      'my_role',
      'pending_count',
      'source_post_id',
    ]);
    expectIso(detail.body.created_at);
    expect(detail.body.source_post_id).toBeNull();
    expect(['controller', 'contributor']).toContain(detail.body.my_role);
    expect(typeof detail.body.pending_count).toBe('number');

    const asContributor = await api.get(app, `/groups/${groupId}`, contributor.token);
    expect(asContributor.body.pending_count).toBeNull();
    expect(asContributor.body.my_role).toBe('contributor');

    // List uses the same model.
    const list = await api.get(app, '/groups', controller.token);
    expect(Object.keys(list.body).sort()).toEqual(['items', 'next_cursor']);
    expect(list.body.next_cursor).toBeNull();
    expect(Object.keys(list.body.items[0]).sort()).toEqual([
      'agenda',
      'controller_id',
      'created_at',
      'id',
      'my_role',
      'pending_count',
      'source_post_id',
    ]);
  });

  it('PublishedMessage matches published_message.g.dart for both anonymity states', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const anon = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'anon contract',
      is_anonymous: true,
    });
    const signed = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'signed contract',
      is_anonymous: false,
    });
    await runStubWorkerOnce(testPool());
    await api.post(app, `/messages/${anon.body.id}/accept`, controller.token);
    await api.post(app, `/messages/${signed.body.id}/accept`, controller.token);

    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    const items = chat.body.items as Array<Record<string, unknown>>;
    expect(items).toHaveLength(2);
    for (const item of items) {
      expect(Object.keys(item).sort()).toEqual([
        'attachment_id',
        'display_sender',
        'group_id',
        'id',
        'published_at',
        'text',
      ]);
      expectIso(item.published_at);
    }
    const anonItem = items.find((i) => i.text === '[stub rewrite] anon contract');
    const signedItem = items.find((i) => i.text === '[stub rewrite] signed contract');
    expect(anonItem!.display_sender).toBeNull();
    expect(Object.keys(signedItem!.display_sender as object).sort()).toEqual(['id', 'name']);
  });

  it('SentMessage and MyMessageStatus match sent_message.g.dart / my_message_status.g.dart', async () => {
    const app = testApp();
    const { contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'status shapes',
      is_anonymous: true,
    });
    expect(Object.keys(sent.body).sort()).toEqual(['created_at', 'group_id', 'id', 'status']);
    expectIso(sent.body.created_at);
    expect(['pending', 'accepted', 'rejected']).toContain(sent.body.status);

    const mine = await api.get(app, `/groups/${groupId}/messages/mine`, contributor.token);
    const item = mine.body.items[0];
    expect(Object.keys(item).sort()).toEqual([
      'created_at',
      'group_id',
      'id',
      'is_anonymous',
      'status',
    ]);
    expect(typeof item.is_anonymous).toBe('boolean');
    expectIso(item.created_at);
  });

  it('RawMessage matches raw_message.g.dart before and after the worker', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'raw shape',
      is_anonymous: true,
    });

    const before = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    const item = before.body.items[0];
    expect(Object.keys(item).sort()).toEqual(RAW_MESSAGE_KEYS);
    // Nullable until the worker runs.
    expect(item.rewritten_text).toBeNull();
    expect(item.intent_preservation_score).toBeNull();
    expect(item.relevance_score).toBeNull();
    expect(item.relevance_label).toBeNull();
    expect(['queued', 'processing', 'done', 'failed']).toContain(item.pipeline_status);
    expect(typeof item.sender_id).toBe('string');
    expect(typeof item.sender_name).toBe('string');
    expectIso(item.created_at);

    await runStubWorkerOnce(testPool());
    const after = await api.get(
      app,
      `/groups/${groupId}/review-queue/${sent.body.id}`,
      controller.token,
    );
    expect(Object.keys(after.body).sort()).toEqual(RAW_MESSAGE_KEYS);
    // Scores serialize as JSON numbers, not strings.
    expect(after.body.intent_preservation_score).toBe(0.9);
    expect(after.body.relevance_score).toBe(0.8);
    expect(['relevant', 'borderline', 'off_topic']).toContain(after.body.relevance_label);
  });

  it('AcceptResult and RejectResult match review_result.g.dart', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const acceptMe = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'accept result',
      is_anonymous: false,
    });
    const rejectMe = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'reject result',
      is_anonymous: false,
    });
    await runStubWorkerOnce(testPool());
    const accepted = await api.post(app, `/messages/${acceptMe.body.id}/accept`, controller.token);
    expect(Object.keys(accepted.body).sort()).toEqual(['id', 'published_message_id', 'status']);
    expect(typeof accepted.body.published_message_id).toBe('string');
    expect(accepted.body.status).toBe('accepted');

    const rejected = await api.post(app, `/messages/${rejectMe.body.id}/reject`, controller.token);
    expect(Object.keys(rejected.body).sort()).toEqual(['id', 'status']);
    expect(rejected.body.status).toBe('rejected');
  });

  it('AppNotification and UnreadCount match app_notification.g.dart / unread_count.g.dart', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app, { agenda: 'Notify agenda' });
    await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'notification shape',
      is_anonymous: false,
    });
    const list = await api.get(app, '/notifications', controller.token);
    const item = list.body.items[0];
    expect(Object.keys(item).sort()).toEqual([
      'created_at',
      'group',
      'id',
      'read_at',
      'ref_id',
      'type',
    ]);
    expect(Object.keys(item.group).sort()).toEqual(['agenda', 'id']);
    expect(['message_pending_review', 'message_rejected']).toContain(item.type);
    expectIso(item.created_at);
    expect(item.read_at).toBeNull();

    const unread = await api.get(app, '/notifications/unread-count', controller.token);
    expect(Object.keys(unread.body)).toEqual(['count']);
    expect(typeof unread.body.count).toBe('number');
  });

  it('the accept transaction records decided_at/decided_by and links the published row', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'decision metadata',
      is_anonymous: true,
    });
    await runStubWorkerOnce(testPool());
    const accepted = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);

    const raw = await testPool().query(
      'SELECT status, published_message_id, decided_at, decided_by FROM raw_messages WHERE id = $1',
      [sent.body.id],
    );
    expect(raw.rows[0].status).toBe('accepted');
    expect(raw.rows[0].published_message_id).toBe(accepted.body.published_message_id);
    expect(raw.rows[0].decided_at).not.toBeNull();
    expect(raw.rows[0].decided_by).toBe(controller.id);
  });
});
