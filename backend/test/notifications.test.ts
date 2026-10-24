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

describe('notifications', () => {
  it('submission notifies the controller; rejection notifies the author with no reason', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);

    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'notify flow text',
      is_anonymous: true,
    });

    const unread = await api.get(app, '/notifications/unread-count', controller.token);
    expect(unread.status).toBe(200);
    expect(unread.body).toEqual({ count: 1 });

    const list = await api.get(app, '/notifications', controller.token);
    expect(list.status).toBe(200);
    expect(list.body.items).toHaveLength(1);
    const notification = list.body.items[0];
    expect(Object.keys(notification).sort()).toEqual([
      'created_at',
      'group',
      'id',
      'read_at',
      'ref_id',
      'type',
    ]);
    expect(notification.type).toBe('message_pending_review');
    expect(notification.ref_id).toBe(sent.body.id);
    expect(notification.group).toEqual({ id: groupId, agenda: 'Making NLP notes' });
    expect(notification.read_at).toBeNull();

    await runStubWorkerOnce(testPool());
    const rejected = await api.post(app, `/messages/${sent.body.id}/reject`, controller.token);
    expect(rejected.status).toBe(200);

    const authorList = await api.get(app, '/notifications', contributor.token);
    expect(authorList.body.items).toHaveLength(1);
    const authorNotification = authorList.body.items[0];
    expect(authorNotification.type).toBe('message_rejected');
    expect(authorNotification.read_at).toBeNull();
    // No reason field exists anywhere on a rejection notification.
    expect(Object.keys(authorNotification)).not.toContain('reason');
    expect(JSON.stringify(authorNotification)).not.toContain('notify flow text');
  });

  it('mark-read sets read_at; a second call stays 204; unread count drops', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'to be read',
      is_anonymous: false,
    });
    const list = await api.get(app, '/notifications', controller.token);
    const id = list.body.items[0].id as string;

    const mark = await api.post(app, `/notifications/${id}/read`, controller.token);
    expect(mark.status).toBe(204);

    const after = await api.get(app, '/notifications', controller.token);
    expect(after.body.items[0].read_at).not.toBeNull();
    expect(new Date(after.body.items[0].read_at).toString()).not.toBe('Invalid Date');

    const unread = await api.get(app, '/notifications/unread-count', controller.token);
    expect(unread.body.count).toBe(0);

    const again = await api.post(app, `/notifications/${id}/read`, controller.token);
    expect(again.status).toBe(204);
  });

  it('notifications are recipient-only', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'private notification',
      is_anonymous: false,
    });
    const controllerList = await api.get(app, '/notifications', controller.token);
    const id = controllerList.body.items[0].id as string;

    // The contributor cannot see or mark the controller's notification.
    const contributorList = await api.get(app, '/notifications', contributor.token);
    expect(contributorList.body.items).toHaveLength(0);

    const markAsOther = await api.post(app, `/notifications/${id}/read`, contributor.token);
    expect(markAsOther.status).toBe(404);

    const stranger = await registerUser(app, 'Stranger', 'stranger@example.com');
    const markAsStranger = await api.post(app, `/notifications/${id}/read`, stranger.token);
    expect(markAsStranger.status).toBe(404);
  });

  it('unread-count only counts the caller\'s unread rows', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const second = await registerUser(app, 'Second Ctrl', 'second-ctrl@example.com');
    await api.post(app, '/groups', second.token, { agenda: 'Second group' });
    await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'one for the controller',
      is_anonymous: true,
    });

    const controllerCount = await api.get(app, '/notifications/unread-count', controller.token);
    const secondCount = await api.get(app, '/notifications/unread-count', second.token);
    const contributorCount = await api.get(app, '/notifications/unread-count', contributor.token);
    expect(controllerCount.body.count).toBe(1);
    expect(secondCount.body.count).toBe(0);
    expect(contributorCount.body.count).toBe(0);
  });
});
