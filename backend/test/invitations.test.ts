import supertest from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const del = (app: ReturnType<typeof testApp>, path: string, token: string) =>
  supertest(app).delete(path).set({ Authorization: `Bearer ${token}` });

async function setup() {
  const app = testApp();
  const ctrl = await registerUser(app, 'Controller', 'c@example.com');
  const maya = await registerUser(app, 'Maya', 'maya@example.com');
  const g = await api.post(app, '/groups', ctrl.token, { agenda: 'Retro' });
  return { app, ctrl, maya, gid: g.body.id as string };
}

const isMember = async (app: ReturnType<typeof testApp>, gid: string, token: string) =>
  (await api.get(app, `/groups/${gid}`, token)).status === 200;

describe('group invitations (API 69)', () => {
  it('adding asks first: the person is notified and joins only by accepting', async () => {
    const { app, ctrl, maya, gid } = await setup();
    const add = await api.post(app, `/groups/${gid}/members`, ctrl.token, { user_id: maya.id });
    expect(add.status).toBe(202);
    expect(await isMember(app, gid, maya.token)).toBe(false);

    const notes = await api.get(app, '/notifications', maya.token);
    expect(notes.body.items[0]).toMatchObject({ type: 'group_invitation', group: { id: gid, agenda: 'Retro' } });
    const mine = await api.get(app, '/invitations', maya.token);
    expect(mine.body.items).toEqual([
      expect.objectContaining({ group: { id: gid, agenda: 'Retro', member_count: 1 }, invited_by: 'Controller' }),
    ]);

    const accepted = await api.post(app, `/invitations/${mine.body.items[0].id}/accept`, maya.token);
    expect(accepted.body).toEqual({ group_id: gid, joined: true });
    expect(await isMember(app, gid, maya.token)).toBe(true);
    // Answered invitations leave the lists.
    expect((await api.get(app, '/invitations', maya.token)).body.items).toEqual([]);
    expect((await api.get(app, '/notifications', maya.token)).body.items).toEqual([]);
    // An invitation can be used once.
    expect((await api.post(app, `/invitations/${mine.body.items[0].id}/accept`, maya.token)).status).toBe(404);
  });

  it('declining keeps you out; you can be invited again later', async () => {
    const { app, ctrl, maya, gid } = await setup();
    await api.post(app, `/groups/${gid}/members`, ctrl.token, { user_id: maya.id });
    const inv = (await api.get(app, '/invitations', maya.token)).body.items[0];
    expect((await api.post(app, `/invitations/${inv.id}/decline`, maya.token)).status).toBe(204);
    expect(await isMember(app, gid, maya.token)).toBe(false);
    // The controller's pending list no longer shows her, and a new invite works.
    expect((await api.get(app, `/groups/${gid}/invitations`, ctrl.token)).body.items).toEqual([]);
    expect((await api.post(app, `/groups/${gid}/members`, ctrl.token, { user_id: maya.id })).status).toBe(202);
  });

  it('controllers see and cancel pending invitations; others cannot', async () => {
    const { app, ctrl, maya, gid } = await setup();
    const other = await registerUser(app, 'Other', 'o@example.com');
    await api.post(app, `/groups/${gid}/members`, ctrl.token, { user_id: maya.id });
    const pending = await api.get(app, `/groups/${gid}/invitations`, ctrl.token);
    expect(pending.body.items).toEqual([expect.objectContaining({ user: { id: maya.id, name: 'Maya' } })]);
    expect((await api.get(app, `/groups/${gid}/invitations`, other.token)).status).toBe(403);

    expect((await del(app, `/groups/${gid}/invitations/${pending.body.items[0].id}`, ctrl.token)).status).toBe(204);
    expect((await api.get(app, '/invitations', maya.token)).body.items).toEqual([]);
    expect((await api.get(app, '/notifications', maya.token)).body.items).toEqual([]);
  });

  it('nobody else can answer your invitation', async () => {
    const { app, ctrl, maya, gid } = await setup();
    const other = await registerUser(app, 'Other', 'o@example.com');
    await api.post(app, `/groups/${gid}/members`, ctrl.token, { user_id: maya.id });
    const inv = (await api.get(app, '/invitations', maya.token)).body.items[0];
    expect((await api.post(app, `/invitations/${inv.id}/accept`, other.token)).status).toBe(404);
    expect(await isMember(app, gid, other.token)).toBe(false);
    expect((await api.post(app, '/invitations/not-a-uuid/accept', maya.token)).status).toBe(404);
  });

  it('a block made after inviting stops the join', async () => {
    const { app, ctrl, maya, gid } = await setup();
    await api.post(app, `/groups/${gid}/members`, ctrl.token, { user_id: maya.id });
    const inv = (await api.get(app, '/invitations', maya.token)).body.items[0];
    await api.post(app, `/users/${maya.id}/block`, ctrl.token);
    expect((await api.post(app, `/invitations/${inv.id}/accept`, maya.token)).status).toBe(403);
    expect(await isMember(app, gid, maya.token)).toBe(false);
  });
});
