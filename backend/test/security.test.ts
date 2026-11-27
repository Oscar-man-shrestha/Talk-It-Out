import jwt from 'jsonwebtoken';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { memoryOutbox } from '../src/mailer';
import {
  api,
  closePool,
  config,
  ensureSchema,
  registerUser,
  resetDb,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(async () => {
  await resetDb();
  memoryOutbox.length = 0;
});
afterAll(closePool);

const login = (a: ReturnType<typeof testApp>, email: string, password: string) =>
  api.post(a, '/auth/login', undefined, { email, password });

describe('token_version', () => {
  it('access tokens carry tv and still work normally', async () => {
    const a = testApp();
    const user = await registerUser(a, 'P', 'p@example.com');
    const claims = jwt.decode(user.token) as { tv?: number };
    expect(claims.tv).toBe(0);
    expect((await api.get(a, '/me', user.token)).status).toBe(200);
  });

  it('a token from before migration 009 (no tv) still works until sessions end', async () => {
    const a = testApp();
    const user = await registerUser(a, 'P', 'p@example.com');
    const legacy = jwt.sign({}, config.jwtSecret, {
      subject: user.id,
      expiresIn: '1h',
      algorithm: 'HS256',
    });
    expect((await api.get(a, '/me', legacy)).status).toBe(200);
    await api.post(a, '/auth/logout-all', user.token);
    expect((await api.get(a, '/me', legacy)).status).toBe(401);
  });
});

describe('POST /auth/logout-all', () => {
  it('ends every access and refresh token, including this one', async () => {
    const a = testApp();
    const first = await registerUser(a, 'P', 'p@example.com');
    const second = (await login(a, 'p@example.com', 'secret123')).body.token;
    const refresh = (await api.post(a, '/auth/refresh-tokens', second)).body.refresh_token;

    expect((await api.post(a, '/auth/logout-all', first.token)).status).toBe(204);
    expect((await api.get(a, '/me', first.token)).status).toBe(401);
    expect((await api.get(a, '/me', second)).status).toBe(401);
    expect(
      (await api.post(a, '/auth/refresh', undefined, { refresh_token: refresh })).status,
    ).toBe(401);

    // Signing in again works and gets the new version.
    const fresh = await login(a, 'p@example.com', 'secret123');
    expect(fresh.status).toBe(200);
    expect((jwt.decode(fresh.body.token) as { tv: number }).tv).toBe(1);
    expect((await api.get(a, '/me', fresh.body.token)).status).toBe(200);
  });

  it('needs a valid token', async () => {
    expect((await api.post(testApp(), '/auth/logout-all')).status).toBe(401);
  });
});

describe('POST /auth/change-password', () => {
  it('changes the password, keeps this device, signs out the others', async () => {
    const a = testApp();
    const me = await registerUser(a, 'P', 'p@example.com', 'old-password');
    const other = (await login(a, 'p@example.com', 'old-password')).body.token;
    const refresh = (await api.post(a, '/auth/refresh-tokens', other)).body.refresh_token;

    const res = await api.post(a, '/auth/change-password', me.token, {
      current_password: 'old-password',
      new_password: 'new-password',
    });
    expect(res.status).toBe(200);
    expect(Object.keys(res.body)).toEqual(['token']);

    expect((await api.get(a, '/me', res.body.token)).status).toBe(200);
    expect((await api.get(a, '/me', me.token)).status).toBe(401);
    expect((await api.get(a, '/me', other)).status).toBe(401);
    expect(
      (await api.post(a, '/auth/refresh', undefined, { refresh_token: refresh })).status,
    ).toBe(401);
    expect((await login(a, 'p@example.com', 'old-password')).status).toBe(401);
    expect((await login(a, 'p@example.com', 'new-password')).status).toBe(200);
  });

  it('a wrong current password is 403 and changes nothing', async () => {
    const a = testApp();
    const me = await registerUser(a, 'P', 'p@example.com', 'old-password');
    const res = await api.post(a, '/auth/change-password', me.token, {
      current_password: 'nope',
      new_password: 'new-password',
    });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('wrong_password');
    expect((await api.get(a, '/me', me.token)).status).toBe(200);
  });

  it('validates the new password', async () => {
    const a = testApp();
    const me = await registerUser(a, 'P', 'p@example.com', 'old-password');
    const short = await api.post(a, '/auth/change-password', me.token, {
      current_password: 'old-password',
      new_password: 'short',
    });
    expect(short.status).toBe(422);
    const same = await api.post(a, '/auth/change-password', me.token, {
      current_password: 'old-password',
      new_password: 'old-password',
    });
    expect(same.status).toBe(422);
  });
});

describe('password reset ends sessions', () => {
  it('a reset makes existing access tokens fail', async () => {
    const a = testApp({ mailTransport: 'memory' });
    const me = await registerUser(a, 'P', 'p@example.com', 'old-password');
    await api.post(a, '/auth/password-reset', undefined, { email: 'p@example.com' });
    let code = '';
    for (let i = 0; i < 50 && !code; i++) {
      const mail = memoryOutbox.find((m) => m.to === 'p@example.com');
      if (mail) code = /(\d{6})/.exec(mail.text)![1];
      else await new Promise((r) => setTimeout(r, 10));
    }
    const done = await api.post(a, '/auth/password-reset/confirm', undefined, {
      email: 'p@example.com',
      code,
      new_password: 'new-password',
    });
    expect(done.status).toBe(204);
    expect((await api.get(a, '/me', me.token)).status).toBe(401);
    const { rows } = await testPool().query('SELECT token_version FROM users');
    expect(rows[0].token_version).toBe(1);
  });
});
