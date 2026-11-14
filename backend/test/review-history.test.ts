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

describe('review history (?status=accepted|rejected) and counts', () => {
  it('lists decided messages newest decision first, with counts per tab', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const ids: string[] = [];
    for (const text of ['first point about rota', 'second point about rota', 'third point']) {
      const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
        text,
        is_anonymous: false,
      });
      ids.push(sent.body.id as string);
    }
    await runStubWorkerOnce(testPool());
    await runStubWorkerOnce(testPool());
    await runStubWorkerOnce(testPool());

    await api.post(app, `/messages/${ids[0]}/accept`, controller.token);
    await api.post(app, `/messages/${ids[1]}/accept`, controller.token);

    const counts = await api.get(app, `/groups/${groupId}/review-counts`, controller.token);
    expect(counts.status).toBe(200);
    expect(counts.body).toEqual({ pending: 1, accepted: 2, rejected: 0 });

    const accepted = await api.get(
      app,
      `/groups/${groupId}/review-queue?status=accepted&limit=1`,
      controller.token,
    );
    expect(accepted.status).toBe(200);
    expect(accepted.body.items.map((m: { id: string }) => m.id)).toEqual([ids[1]]);
    expect(accepted.body.items[0].status).toBe('accepted');
    expect(typeof accepted.body.items[0].decided_at).toBe('string');
    const next = await api.get(
      app,
      `/groups/${groupId}/review-queue?status=accepted&limit=1&cursor=${accepted.body.next_cursor}`,
      controller.token,
    );
    expect(next.body.items.map((m: { id: string }) => m.id)).toEqual([ids[0]]);
    expect(next.body.next_cursor).toBeNull();

    await api.post(app, `/messages/${ids[2]}/reject`, controller.token);
    const rejected = await api.get(
      app,
      `/groups/${groupId}/review-queue?status=rejected`,
      controller.token,
    );
    expect(rejected.body.items.map((m: { id: string }) => m.id)).toEqual([ids[2]]);
    // Pending stays the default and is now empty.
    const pending = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(pending.body.items).toEqual([]);
    expect(pending.body.items.length).toBe(0);
    const after = await api.get(app, `/groups/${groupId}/review-counts`, controller.token);
    expect(after.body).toEqual({ pending: 0, accepted: 2, rejected: 1 });
  });

  it('is controller only and rejects an unknown status', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    expect(
      (await api.get(app, `/groups/${groupId}/review-queue?status=accepted`, contributor.token))
        .status,
    ).toBe(403);
    expect((await api.get(app, `/groups/${groupId}/review-counts`, contributor.token)).status).toBe(
      403,
    );
    const bad = await api.get(app, `/groups/${groupId}/review-queue?status=all`, controller.token);
    expect(bad.status).toBe(400);
  });
});
