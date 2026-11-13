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

describe('POST /messages/:id/rewrite (fresh AI rewrite)', () => {
  it('the controller can ask again; the old rewrite is cleared and a new one arrives', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'the deadlines are honestly unrealistic',
      is_anonymous: true,
    });
    const id = sent.body.id as string;
    await runStubWorkerOnce(testPool());

    const res = await api.post(app, `/messages/${id}/rewrite`, controller.token);
    expect(res.status).toBe(202);
    expect(res.body).toEqual({ id, status: 'pending', pipeline_status: 'queued' });

    const { rows } = await testPool().query(
      'SELECT pipeline_status, rewritten_text FROM raw_messages WHERE id = $1',
      [id],
    );
    expect(rows[0]).toEqual({ pipeline_status: 'queued', rewritten_text: null });
    // Nothing stale can be accepted meanwhile.
    expect((await api.post(app, `/messages/${id}/accept`, controller.token)).status).toBe(409);
    // A second request while one is queued is refused.
    const again = await api.post(app, `/messages/${id}/rewrite`, controller.token);
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('rewrite_in_progress');

    await runStubWorkerOnce(testPool());
    const after = await testPool().query(
      'SELECT pipeline_status, rewritten_text FROM raw_messages WHERE id = $1',
      [id],
    );
    expect(after.rows[0].pipeline_status).toBe('done');
    expect(after.rows[0].rewritten_text).toBeTruthy();
    expect((await api.post(app, `/messages/${id}/accept`, controller.token)).status).toBe(200);
  });

  it('only the group controller may ask, and only for pending messages', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'please look at the on-call rota',
      is_anonymous: false,
    });
    const id = sent.body.id as string;
    await runStubWorkerOnce(testPool());

    const outsider = await registerUser(app, 'Outsider', 'outsider-rw@example.com');
    expect((await api.post(app, `/messages/${id}/rewrite`, contributor.token)).status).toBe(403);
    expect((await api.post(app, `/messages/${id}/rewrite`, outsider.token)).status).toBe(403);
    expect(
      (await api.post(app, '/messages/00000000-0000-4000-8000-000000000000/rewrite', controller.token))
        .status,
    ).toBe(404);

    await api.post(app, `/messages/${id}/reject`, controller.token);
    const late = await api.post(app, `/messages/${id}/rewrite`, controller.token);
    expect(late.status).toBe(409);
    expect(late.body.error.code).toBe('already_decided');
  });
});
