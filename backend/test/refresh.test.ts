import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import {
  api,
  closePool,
  ensureSchema,
  registerUser,
  resetDb,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

describe('refresh tokens', () => {
  it('login response is unchanged; refresh tokens are opt-in', async () => {
    const app = testApp();
    await registerUser(app, 'P', 'p@example.com');
    const login = await api.post(app, '/auth/login', undefined, {
      email: 'p@example.com',
      password: 'secret123',
    });
    expect(Object.keys(login.body).sort()).toEqual(['token', 'user']);
  });

  it('issues, rotates, and exchanges a refresh token for a working access token', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');

    const issued = await api.post(app, '/auth/refresh-tokens', user.token);
    expect(issued.status).toBe(201);
    expect(Object.keys(issued.body).sort()).toEqual(['expires_at', 'refresh_token']);

    const refreshed = await api.post(app, '/auth/refresh', undefined, {
      refresh_token: issued.body.refresh_token,
    });
    expect(refreshed.status).toBe(200);
    expect(Object.keys(refreshed.body).sort()).toEqual(['expires_at', 'refresh_token', 'token']);
    expect(refreshed.body.refresh_token).not.toBe(issued.body.refresh_token);

    const me = await api.get(app, '/me', refreshed.body.token);
    expect(me.status).toBe(200);
    expect(me.body.id).toBe(user.id);

    // Works under /api/v1 too.
    const again = await api.post(app, '/api/v1/auth/refresh', undefined, {
      refresh_token: refreshed.body.refresh_token,
    });
    expect(again.status).toBe(200);
  });

  it('stores only hashes', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');
    const issued = await api.post(app, '/auth/refresh-tokens', user.token);
    const { rows } = await testPool().query('SELECT token_hash FROM refresh_tokens');
    expect(rows).toHaveLength(1);
    expect(rows[0].token_hash).not.toBe(issued.body.refresh_token);
    expect(rows[0].token_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('reuse of a rotated token revokes the whole family', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');
    const first = (await api.post(app, '/auth/refresh-tokens', user.token)).body.refresh_token;
    const second = (await api.post(app, '/auth/refresh', undefined, { refresh_token: first })).body
      .refresh_token;

    const replay = await api.post(app, '/auth/refresh', undefined, { refresh_token: first });
    expect(replay.status).toBe(401);
    expect(replay.body.error.code).toBe('unauthorized');
    // The legitimate newer token died with the family.
    const after = await api.post(app, '/auth/refresh', undefined, { refresh_token: second });
    expect(after.status).toBe(401);
  });

  it('rejects unknown, expired, and revoked tokens', async () => {
    const app = testApp();
    const user = await registerUser(app, 'P', 'p@example.com');
    const unknown = await api.post(app, '/auth/refresh', undefined, {
      refresh_token: 'x'.repeat(43),
    });
    expect(unknown.status).toBe(401);
    expect((await api.post(app, '/auth/refresh', undefined, {})).status).toBe(422);

    const token = (await api.post(app, '/auth/refresh-tokens', user.token)).body.refresh_token;
    await testPool().query("UPDATE refresh_tokens SET expires_at = now() - interval '1 second'");
    expect((await api.post(app, '/auth/refresh', undefined, { refresh_token: token })).status).toBe(
      401,
    );

    const live = (await api.post(app, '/auth/refresh-tokens', user.token)).body.refresh_token;
    expect((await api.del(app, '/auth/refresh-tokens', user.token)).status).toBe(204);
    expect((await api.post(app, '/auth/refresh', undefined, { refresh_token: live })).status).toBe(
      401,
    );
  });

  it('issuing requires an access token', async () => {
    const app = testApp();
    expect((await api.post(app, '/auth/refresh-tokens')).status).toBe(401);
  });
});
