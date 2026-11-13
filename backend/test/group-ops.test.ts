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

describe('controller direct messages', () => {
  it('publishes immediately as the controller, attributed and never anonymous', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const res = await api.post(
      app,
      `/groups/${groupId}/messages/controller`,
      controller.token,
      { text: 'Meeting moved to 5pm.' },
    );
    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual([
      'display_sender',
      'group_id',
      'id',
      'published_at',
      'text',
    ]);
    expect(res.body.display_sender).toEqual({ id: controller.id, name: 'Cara Controller' });
    expect(res.body.text).toBe('Meeting moved to 5pm.');

    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(chat.body.items).toHaveLength(1);
    expect(chat.body.items[0].display_sender).toEqual({ id: controller.id, name: 'Cara Controller' });

    // No raw message, job, or review item was created.
    const raw = await testPool().query('SELECT count(*)::int AS n FROM raw_messages');
    const jobs = await testPool().query('SELECT count(*)::int AS n FROM jobs');
    const queue = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(raw.rows[0].n).toBe(0);
    expect(jobs.rows[0].n).toBe(0);
    expect(queue.body.items).toHaveLength(0);
  });

  it('contributors and outsiders get 403; empty text is 422; unknown group 404', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const outsider = await registerUser(app, 'Outsider', 'outsider2@example.com');

    expect(
      (
        await api.post(app, `/groups/${groupId}/messages/controller`, contributor.token, {
          text: 'hi',
        })
      ).status,
    ).toBe(403);
    expect(
      (
        await api.post(app, `/groups/${groupId}/messages/controller`, outsider.token, {
          text: 'hi',
        })
      ).status,
    ).toBe(403);
    expect(
      (
        await api.post(app, `/groups/${groupId}/messages/controller`, controller.token, {
          text: '   ',
        })
      ).status,
    ).toBe(422);
    expect(
      (
        await api.post(
          app,
          '/groups/00000000-0000-0000-0000-000000000000/messages/controller',
          controller.token,
          { text: 'hi' },
        )
      ).status,
    ).toBe(404);
  });
});

describe('deleting published messages', () => {
  it('controller deletes a message; a second call is 404; contributors cannot', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'delete me later',
      is_anonymous: true,
    });
    await runStubWorkerOnce(testPool());
    const accepted = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
    const publishedId = accepted.body.published_message_id as string;

    const del = await api.del(app, `/groups/${groupId}/messages/${publishedId}`, controller.token);
    expect(del.status).toBe(204);

    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(chat.body.items).toHaveLength(0);
    expect(JSON.stringify(chat.body)).not.toContain('delete me later');

    const again = await api.del(app, `/groups/${groupId}/messages/${publishedId}`, controller.token);
    expect(again.status).toBe(404);

    const asContributor = await api.del(
      app,
      `/groups/${groupId}/messages/${publishedId}`,
      contributor.token,
    );
    expect(asContributor.status).toBe(403);
  });

  it('cross-group deletion fails: the message must belong to that group', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const other = await seedGroup(app, { agenda: 'Another group' });
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'stays in group one',
      is_anonymous: false,
    });
    await runStubWorkerOnce(testPool());
    const accepted = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
    const publishedId = accepted.body.published_message_id as string;

    // other.controller is a controller, but not of the group the message is in.
    expect(
      (
        await api.del(app, `/groups/${other.groupId}/messages/${publishedId}`, other.controller.token)
      ).status,
    ).toBe(404);
    // The real controller with the wrong group id also gets 404.
    expect(
      (await api.del(app, `/groups/${other.groupId}/messages/${publishedId}`, controller.token))
        .status,
    ).toBe(403);
    // And it is still there.
    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(chat.body.items).toHaveLength(1);
  });

  it('deleting an anonymous message leaves no group-facing author trace', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'anonymous then deleted',
      is_anonymous: true,
    });
    await runStubWorkerOnce(testPool());
    const accepted = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
    const publishedId = accepted.body.published_message_id as string;

    const del = await api.del(app, `/groups/${groupId}/messages/${publishedId}`, controller.token);
    expect(del.status).toBe(204);

    const remaining = await testPool().query(
      'SELECT count(*)::int AS n FROM published_messages WHERE id = $1',
      [publishedId],
    );
    expect(remaining.rows[0].n).toBe(0);
    const mine = await api.get(app, `/groups/${groupId}/messages/mine`, contributor.token);
    expect(JSON.stringify(mine.body)).not.toContain(contributor.id);
  });
});

describe('removing members', () => {
  it('controller removes a member; pending items leave the queue; access is revoked', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'pending from soon-removed member',
      is_anonymous: true,
    });

    const queueBefore = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    const detailBefore = await api.get(app, `/groups/${groupId}`, controller.token);
    expect(queueBefore.body.items).toHaveLength(1);
    expect(detailBefore.body.pending_count).toBe(1);

    const res = await api.del(app, `/groups/${groupId}/members/${contributor.id}`, controller.token);
    expect(res.status).toBe(204);

    const queueAfter = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    const detailAfter = await api.get(app, `/groups/${groupId}`, controller.token);
    expect(queueAfter.body.items).toHaveLength(0);
    expect(detailAfter.body.pending_count).toBe(0);

    // Access revoked immediately.
    expect((await api.get(app, `/groups/${groupId}`, contributor.token)).status).toBe(403);
    expect((await api.get(app, `/groups/${groupId}/messages`, contributor.token)).status).toBe(403);

    // Raw rows stay for audit.
    const raw = await testPool().query(
      'SELECT count(*)::int AS n FROM raw_messages WHERE author_id = $1',
      [contributor.id],
    );
    expect(raw.rows[0].n).toBe(1);

    // Removing them again is 404.
    expect(
      (await api.del(app, `/groups/${groupId}/members/${contributor.id}`, controller.token))
        .status,
    ).toBe(404);
  });

  it('the controller cannot remove themselves; non-controllers cannot remove anyone', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const self = await api.del(app, `/groups/${groupId}/members/${controller.id}`, controller.token);
    expect(self.status).toBe(409);
    expect(self.body.error.message).toBe('The controller cannot remove themselves.');

    const byContributor = await api.del(
      app,
      `/groups/${groupId}/members/${controller.id}`,
      contributor.token,
    );
    expect(byContributor.status).toBe(403);

    const notAMember = await api.del(
      app,
      `/groups/${groupId}/members/00000000-0000-0000-0000-000000000000`,
      controller.token,
    );
    expect(notAMember.status).toBe(404);
  });

  it('removal is scoped to one group', async () => {
    const app = testApp();
    const { controller, contributor, contributorUsername, groupId } = await seedGroup(app);
    const other = await seedGroup(app, { agenda: 'Second group' });
    await api.post(app, `/groups/${other.groupId}/members`, other.controller.token, {
      username: contributorUsername,
      role: 'contributor',
    });

    expect(
      (await api.del(app, `/groups/${groupId}/members/${contributor.id}`, controller.token))
        .status,
    ).toBe(204);
    expect(
      (await api.get(app, `/groups/${other.groupId}`, contributor.token)).status,
    ).toBe(200);
    expect((await api.get(app, `/groups/${groupId}`, contributor.token)).status).toBe(403);
  });
});

describe('leaving groups', () => {
  it('a contributor leaves and loses access; the controller gets the exact 409', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);

    const leave = await api.post(app, `/groups/${groupId}/leave`, contributor.token);
    expect(leave.status).toBe(204);
    expect((await api.get(app, `/groups/${groupId}`, contributor.token)).status).toBe(403);
    const groups = await api.get(app, '/groups', contributor.token);
    expect(groups.body.items).toHaveLength(0);

    // The controller is now the only member: nobody can take over.
    const asController = await api.post(app, `/groups/${groupId}/leave`, controller.token);
    expect(asController.status).toBe(409);
    expect(asController.body.error.code).toBe('last_member');
    expect((await api.get(app, `/groups/${groupId}`, controller.token)).body.my_role).toBe(
      'controller',
    );
  });

  it('a leaving controller hands the group to the longest-standing member (D4)', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const later = await registerUser(app, 'Later Member', 'later-member@example.com');
    await api.post(app, `/groups/${groupId}/members`, controller.token, {
      username: 'later-member',
    });

    const leave = await api.post(app, `/groups/${groupId}/leave`, controller.token);
    expect(leave.status).toBe(204);
    expect((await api.get(app, `/groups/${groupId}`, controller.token)).status).toBe(403);

    // The earliest remaining member, not the latest, is the new controller.
    const asNew = await api.get(app, `/groups/${groupId}`, contributor.token);
    expect(asNew.body.my_role).toBe('controller');
    expect(asNew.body.controller_id).toBe(contributor.id);
    expect((await api.get(app, `/groups/${groupId}`, later.token)).body.my_role).toBe(
      'contributor',
    );
    expect(
      (await api.get(app, `/groups/${groupId}/review-queue`, contributor.token)).status,
    ).toBe(200);
    expect((await api.get(app, `/groups/${groupId}/review-queue`, later.token)).status).toBe(
      403,
    );
  });

  it('non-members get 403 and unknown groups 404; leaving one group keeps others', async () => {
    const app = testApp();
    const { controller, contributor, contributorUsername, groupId } = await seedGroup(app);
    const outsider = await registerUser(app, 'Outsider L', 'outsider-l@example.com');
    expect((await api.post(app, `/groups/${groupId}/leave`, outsider.token)).status).toBe(403);
    expect(
      (
        await api.post(app, '/groups/00000000-0000-0000-0000-000000000000/leave', outsider.token)
      ).status,
    ).toBe(404);

    const other = await seedGroup(app, { agenda: 'Keep me' });
    await api.post(app, `/groups/${other.groupId}/members`, other.controller.token, {
      username: contributorUsername,
      role: 'contributor',
    });
    await api.post(app, `/groups/${groupId}/leave`, contributor.token);
    expect((await api.get(app, `/groups/${other.groupId}`, contributor.token)).status).toBe(200);
    void controller;
  });
});
