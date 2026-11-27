import supertest from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { MAX_ACTIVE_INVITES, newInviteCode } from '../src/routes/invites';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const del = (app: ReturnType<typeof testApp>, path: string, token: string) =>
  supertest(app).delete(path).set({ Authorization: `Bearer ${token}` });

async function setup() {
  const app = testApp();
  const ctrl = await registerUser(app, 'Controller', 'c@example.com');
  const friend = await registerUser(app, 'Friend', 'f@example.com');
  const g = await api.post(app, '/groups', ctrl.token, { agenda: 'Sprint retro' });
  return { app, ctrl, friend, gid: g.body.id as string };
}

describe('invite links (API 61)', () => {
  it('codes are 10 unambiguous characters', () => {
    for (let i = 0; i < 50; i++) expect(newInviteCode()).toMatch(/^[a-z2-9]{10}$/);
  });

  it('a controller shares a link and a friend joins as a contributor', async () => {
    const { app, ctrl, friend, gid } = await setup();
    const inv = await api.post(app, `/groups/${gid}/invites`, ctrl.token, {});
    expect(inv.status).toBe(201);
    expect(inv.body.url).toBe(`http://localhost:52001/#/join/${inv.body.code}`);
    expect(inv.body.app_url).toBe(`talkitout://app/join/${inv.body.code}`);
    expect(new Date(inv.body.expires_at).getTime()).toBeGreaterThan(Date.now() + 6 * 86400000);

    const preview = await api.get(app, `/invites/${inv.body.code}`, friend.token);
    expect(preview.body).toMatchObject({
      group: { id: gid, agenda: 'Sprint retro', member_count: 1 },
      invited_by: 'Controller',
      already_member: false,
    });

    const join = await api.post(app, `/invites/${inv.body.code}/accept`, friend.token);
    expect(join.status).toBe(201);
    expect(join.body).toEqual({ group_id: gid, joined: true });
    const members = await api.get(app, `/groups/${gid}/members`, ctrl.token);
    expect(members.body.items.find((m: { user_id: string }) => m.user_id === friend.id)?.role).toBe('contributor');

    // Joining again is harmless and does not use up the link.
    const again = await api.post(app, `/invites/${inv.body.code}/accept`, friend.token);
    expect(again.status).toBe(200);
    expect(again.body.joined).toBe(false);
    const list = await api.get(app, `/groups/${gid}/invites`, ctrl.token);
    expect(list.body.items[0].uses).toBe(1);
  });

  it('only controllers manage links; members get 403, others 404', async () => {
    const { app, ctrl, friend, gid } = await setup();
    expect((await api.post(app, `/groups/${gid}/invites`, friend.token, {})).status).toBe(404);
    const inv = await api.post(app, `/groups/${gid}/invites`, ctrl.token, {});
    await api.post(app, `/invites/${inv.body.code}/accept`, friend.token);
    expect((await api.post(app, `/groups/${gid}/invites`, friend.token, {})).status).toBe(403);
    expect((await api.get(app, `/groups/${gid}/invites`, friend.token)).status).toBe(403);
  });

  it('use limits, expiry and revoking turn a link off', async () => {
    const { app, ctrl, friend, gid } = await setup();
    const third = await registerUser(app, 'Third', 't@example.com');

    const once = await api.post(app, `/groups/${gid}/invites`, ctrl.token, { max_uses: 1 });
    await api.post(app, `/invites/${once.body.code}/accept`, friend.token);
    const used = await api.post(app, `/invites/${once.body.code}/accept`, third.token);
    expect(used.status).toBe(404);
    expect(used.body.error.code).toBe('invite_invalid');

    const old = await api.post(app, `/groups/${gid}/invites`, ctrl.token, { expires_in_days: 1 });
    await testPool().query("UPDATE group_invites SET expires_at = now() - interval '1 minute' WHERE code = $1", [old.body.code]);
    expect((await api.get(app, `/invites/${old.body.code}`, third.token)).status).toBe(404);

    const forever = await api.post(app, `/groups/${gid}/invites`, ctrl.token, { expires_in_days: null });
    expect(forever.body.expires_at).toBeNull();
    expect((await del(app, `/groups/${gid}/invites/${forever.body.code}`, ctrl.token)).status).toBe(204);
    expect((await api.post(app, `/invites/${forever.body.code}/accept`, third.token)).status).toBe(404);

    expect((await api.post(app, `/groups/${gid}/invites`, ctrl.token, { expires_in_days: 3 })).status).toBe(422);
    expect((await api.post(app, `/groups/${gid}/invites`, ctrl.token, { max_uses: 0 })).status).toBe(422);
    expect((await api.get(app, '/invites/NOT-A-CODE', third.token)).status).toBe(404);
  });

  it('caps active links and respects blocks', async () => {
    const { app, ctrl, friend, gid } = await setup();
    for (let i = 0; i < MAX_ACTIVE_INVITES; i++) await api.post(app, `/groups/${gid}/invites`, ctrl.token, {});
    expect((await api.post(app, `/groups/${gid}/invites`, ctrl.token, {})).status).toBe(409);

    const list = await api.get(app, `/groups/${gid}/invites`, ctrl.token);
    await api.post(app, `/users/${ctrl.id}/block`, friend.token);
    const code = list.body.items[0].code;
    expect((await api.get(app, `/invites/${code}`, friend.token)).status).toBe(404);
    expect((await api.post(app, `/invites/${code}/accept`, friend.token)).status).toBe(404);
  });

  it('needs sign-in', async () => {
    const { app } = await setup();
    expect((await supertest(app).get('/invites/abcdefghjk')).status).toBe(401);
  });
});
