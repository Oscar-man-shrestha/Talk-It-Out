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

describe('groups', () => {
  it('POST /groups makes the caller the controller and returns the Group shape', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Priya', 'priya@example.com');
    const res = await api.post(app, '/groups', user.token, {
      agenda: 'Making NLP notes',
    });
    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual([
      'agenda',
      'controller_id',
      'created_at',
      'id',
      'my_role',
      'pending_count',
      'source_post_id',
    ]);
    expect(res.body.agenda).toBe('Making NLP notes');
    expect(res.body.controller_id).toBe(user.id);
    expect(res.body.source_post_id).toBeNull();
    expect(res.body.my_role).toBe('controller');
    expect(res.body.pending_count).toBe(0);
  });

  it('rejects an empty agenda with 422', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Priya', 'priya@example.com');
    const res = await api.post(app, '/groups', user.token, { agenda: '   ' });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('validation');
  });

  it('GET /groups lists the caller\'s groups; pending_count is null for contributors', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'A message that will sit pending',
      is_anonymous: false,
    });

    const controllerList = await api.get(app, '/groups', controller.token);
    expect(controllerList.status).toBe(200);
    expect(controllerList.body.items).toHaveLength(1);
    expect(controllerList.body.items[0].my_role).toBe('controller');
    expect(controllerList.body.items[0].pending_count).toBe(1);

    const contributorList = await api.get(app, '/groups', contributor.token);
    expect(contributorList.body.items).toHaveLength(1);
    expect(contributorList.body.items[0].my_role).toBe('contributor');
    expect(contributorList.body.items[0].pending_count).toBeNull();
  });

  it('GET /groups/:groupId works for members; 403 for non-members; 404 unknown', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const outsider = await registerUser(app, 'Outsider', 'outsider@example.com');

    const ok = await api.get(app, `/groups/${groupId}`, contributor.token);
    expect(ok.status).toBe(200);
    expect(ok.body.my_role).toBe('contributor');
    expect(ok.body.pending_count).toBeNull();

    const forbidden = await api.get(app, `/groups/${groupId}`, outsider.token);
    expect(forbidden.status).toBe(403);

    const missing = await api.get(
      app,
      '/groups/00000000-0000-0000-0000-000000000000',
      controller.token,
    );
    expect(missing.status).toBe(404);
  });

  it('controllers cannot submit messages for review', async () => {
    const app = testApp();
    const { controller, groupId } = await seedGroup(app);
    const res = await api.post(app, `/groups/${groupId}/messages`, controller.token, {
      text: 'controller trying to submit',
      is_anonymous: false,
    });
    expect(res.status).toBe(403);
  });

  it('non-members cannot submit either; unknown group is 404', async () => {
    const app = testApp();
    const { groupId } = await seedGroup(app);
    const outsider = await registerUser(app, 'Outsider', 'outsider@example.com');
    const forbidden = await api.post(app, `/groups/${groupId}/messages`, outsider.token, {
      text: 'sneaky message',
      is_anonymous: false,
    });
    expect(forbidden.status).toBe(403);

    const missing = await api.post(
      app,
      '/groups/00000000-0000-0000-0000-000000000000/messages',
      outsider.token,
      { text: 'hello', is_anonymous: false },
    );
    expect(missing.status).toBe(404);
  });

  it('adds a member by username (case-insensitive) and returns {user_id,name,role}', async () => {
    const app = testApp();
    const { controller, contributor, contributorUsername, groupId: _firstGroupId } = await seedGroup(app);
    // already a member via seedGroup; add them to a *second* group by uppercase username
    const created = await api.post(app, '/groups', controller.token, {
      agenda: 'Dashboard improvements',
    });
    const res = await api.post(
      app,
      `/groups/${created.body.id}/members`,
      controller.token,
      { username: contributorUsername.toUpperCase(), role: 'contributor' },
    );
    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual(['name', 'role', 'user_id']);
    expect(res.body.user_id).toBe(contributor.id);
    expect(res.body.role).toBe('contributor');
  });

  it('adding a member with role controller returns 422', async () => {
    const app = testApp();
    const { controller, contributorUsername, groupId } = await seedGroup(app);
    const res = await api.post(app, `/groups/${groupId}/members`, controller.token, {
      username: contributorUsername,
      role: 'controller',
    });
    expect(res.status).toBe(422);
    expect(res.body.error.message).toContain('contributors');
  });

  it('unknown username is 404; duplicate member is 409; non-controller is 403', async () => {
    const app = testApp();
    const { controller, contributor, contributorUsername, groupId } = await seedGroup(app);

    const unknown = await api.post(app, `/groups/${groupId}/members`, controller.token, {
      username: 'no-such-user',
      role: 'contributor',
    });
    expect(unknown.status).toBe(404);

    const duplicate = await api.post(app, `/groups/${groupId}/members`, controller.token, {
      username: contributorUsername,
      role: 'contributor',
    });
    expect(duplicate.status).toBe(409);

    const byContributor = await api.post(
      app,
      `/groups/${groupId}/members`,
      contributor.token,
      { username: contributorUsername, role: 'contributor' },
    );
    expect(byContributor.status).toBe(403);
  });

  it('lists members for members only, with controller and contributor roles', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const res = await api.get(app, `/groups/${groupId}/members`, contributor.token);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(2);
    const roles = Object.fromEntries(
      res.body.items.map((m: { user_id: string; role: string }) => [m.user_id, m.role]),
    );
    expect(roles[controller.id]).toBe('controller');
    expect(roles[contributor.id]).toBe('contributor');
    for (const member of res.body.items) {
      expect(Object.keys(member).sort()).toEqual(['name', 'role', 'user_id']);
    }
  });

  it('pending_count drops back to zero after the queue is decided', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'temp message',
      is_anonymous: false,
    });
    await runStubWorkerOnce(testPool());
    await api.post(app, `/messages/${sent.body.id}/reject`, controller.token);
    const detail = await api.get(app, `/groups/${groupId}`, controller.token);
    expect(detail.body.pending_count).toBe(0);
  });
});
