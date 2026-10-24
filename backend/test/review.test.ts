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

describe('review permissions and state rules', () => {
  it('a contributor and an unrelated controller get 403 on another group\'s review data', async () => {
    const app = testApp();
    const { contributor, groupId } = await seedGroup(app);

    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'message under review',
      is_anonymous: true,
    });
    const messageId = sent.body.id as string;

    // Contributor of the group is not the controller.
    const queueAsContributor = await api.get(
      app,
      `/groups/${groupId}/review-queue`,
      contributor.token,
    );
    expect(queueAsContributor.status).toBe(403);
    const detailAsContributor = await api.get(
      app,
      `/groups/${groupId}/review-queue/${messageId}`,
      contributor.token,
    );
    expect(detailAsContributor.status).toBe(403);

    // A controller of an unrelated group is still an outsider here.
    const otherController = await registerUser(app, 'Other Controller', 'other-controller@example.com');
    await api.post(app, '/groups', otherController.token, { agenda: 'Unrelated group' });
    const queueAsOutsider = await api.get(
      app,
      `/groups/${groupId}/review-queue`,
      otherController.token,
    );
    expect(queueAsOutsider.status).toBe(403);
    const detailAsOutsider = await api.get(
      app,
      `/groups/${groupId}/review-queue/${messageId}`,
      otherController.token,
    );
    expect(detailAsOutsider.status).toBe(403);
  });

  it('a contributor and an unrelated controller get 403 on accept and reject', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'permission check message',
      is_anonymous: false,
    });
    await runStubWorkerOnce(testPool());
    const messageId = sent.body.id as string;

    const outsider = await registerUser(app, 'Outsider Ctrl', 'outsider-ctrl@example.com');
    await api.post(app, '/groups', outsider.token, { agenda: 'Outsider group' });

    expect(
      (await api.post(app, `/messages/${messageId}/accept`, contributor.token)).status,
    ).toBe(403);
    expect(
      (await api.post(app, `/messages/${messageId}/reject`, contributor.token)).status,
    ).toBe(403);
    expect((await api.post(app, `/messages/${messageId}/accept`, outsider.token)).status).toBe(403);
    expect((await api.post(app, `/messages/${messageId}/reject`, outsider.token)).status).toBe(403);

    // The real controller can still decide it.
    const accepted = await api.post(app, `/messages/${messageId}/accept`, controller.token);
    expect(accepted.status).toBe(200);
  });

  it('accept on an unknown or malformed message id is 404', async () => {
    const app = testApp();
    const { controller } = await seedGroup(app);
    expect(
      (
        await api.post(
          app,
          '/messages/00000000-0000-0000-0000-000000000000/accept',
          controller.token,
        )
      ).status,
    ).toBe(404);
    expect(
      (await api.post(app, '/messages/not-a-uuid/reject', controller.token)).status,
    ).toBe(404);
  });

  it('accept before the worker finishes returns 409 "This message has no rewrite yet."', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'too early to accept',
      is_anonymous: true,
    });
    const res = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
    expect(res.status).toBe(409);
    expect(res.body.error.message).toBe('This message has no rewrite yet.');
  });

  it('reject followed by a late worker result stays rejected and unpublished', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'reject me fast',
      is_anonymous: true,
    });
    const messageId = sent.body.id as string;

    // Reject while the pipeline is still queued.
    const rejected = await api.post(app, `/messages/${messageId}/reject`, controller.token);
    expect(rejected.status).toBe(200);

    // The late pipeline result must not touch the decided row.
    await runStubWorkerOnce(testPool());
    const { rows } = await testPool().query(
      'SELECT status, pipeline_status, rewritten_text FROM raw_messages WHERE id = $1',
      [messageId],
    );
    expect(rows[0].status).toBe('rejected');
    expect(rows[0].pipeline_status).toBe('queued');
    expect(rows[0].rewritten_text).toBeNull();

    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(chat.body.items).toHaveLength(0);
  });

  it('repeated decisions return 409 and create no extra rows', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'only decide me once',
      is_anonymous: false,
    });
    await runStubWorkerOnce(testPool());
    const messageId = sent.body.id as string;

    expect((await api.post(app, `/messages/${messageId}/accept`, controller.token)).status).toBe(200);
    const secondAccept = await api.post(app, `/messages/${messageId}/accept`, controller.token);
    expect(secondAccept.status).toBe(409);
    const afterReject = await api.post(app, `/messages/${messageId}/reject`, controller.token);
    expect(afterReject.status).toBe(409);

    const published = await testPool().query(
      'SELECT count(*)::int AS n FROM published_messages',
    );
    expect(published.rows[0].n).toBe(1);

    // And the same for a rejected message.
    const sent2 = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'reject me twice',
      is_anonymous: false,
    });
    await runStubWorkerOnce(testPool());
    expect((await api.post(app, `/messages/${sent2.body.id}/reject`, controller.token)).status).toBe(200);
    const secondReject = await api.post(app, `/messages/${sent2.body.id}/reject`, controller.token);
    expect(secondReject.status).toBe(409);
    const afterAccept = await api.post(app, `/messages/${sent2.body.id}/accept`, controller.token);
    expect(afterAccept.status).toBe(409);
    expect(afterAccept.body.error.message).toBe('This message has already been decided.');
  });

  it('review detail returns the RawMessage; 404 when the message is from another group', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'detail view',
      is_anonymous: true,
    });
    const res = await api.get(
      app,
      `/groups/${groupId}/review-queue/${sent.body.id}`,
      controller.token,
    );
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(sent.body.id);
    expect(res.body.original_text).toBe('detail view');

    const other = await seedGroup(app, { agenda: 'Another agenda' });
    const wrongGroup = await api.get(
      app,
      `/groups/${other.groupId}/review-queue/${sent.body.id}`,
      other.controller.token,
    );
    expect(wrongGroup.status).toBe(404);
  });
});
