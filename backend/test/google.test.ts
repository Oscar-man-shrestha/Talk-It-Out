import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { setGoogleKeysForTests } from '../src/google';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp, testPool } from './helpers';

const CLIENT_ID = 'test-client.apps.googleusercontent.com';
const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const other = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });

beforeAll(async () => {
  await ensureSchema();
  setGoogleKeysForTests({ 'kid-1': publicKey });
});
beforeEach(resetDb);
afterAll(async () => {
  setGoogleKeysForTests(null);
  await closePool();
});

function idToken(
  claims: Record<string, unknown> = {},
  opts: { key?: crypto.KeyObject; kid?: string; aud?: string; iss?: string; exp?: string } = {},
): string {
  const { sub = 'google-sub-1', ...rest } = claims;
  return jwt.sign(
    { email: 'maya@gmail.com', email_verified: true, name: 'Maya Lin', ...rest },
    opts.key ?? privateKey,
    {
      algorithm: 'RS256',
      keyid: opts.kid ?? 'kid-1',
      subject: sub as string,
      audience: opts.aud ?? CLIENT_ID,
      issuer: opts.iss ?? 'https://accounts.google.com',
      expiresIn: (opts.exp ?? '1h') as jwt.SignOptions['expiresIn'],
    },
  );
}

const app = () => testApp({ googleClientIds: [CLIENT_ID] });
const google = (a: ReturnType<typeof testApp>, token: string) =>
  api.post(a, '/auth/google', undefined, { id_token: token });

describe('POST /auth/google', () => {
  it('creates an account with no password and returns the login shape', async () => {
    const a = app();
    const res = await google(a, idToken());
    expect(res.status).toBe(200);
    expect(Object.keys(res.body).sort()).toEqual(['token', 'user']);
    expect(res.body.user).toMatchObject({ name: 'Maya Lin', email: 'maya@gmail.com' });
    expect((await api.get(a, '/me', res.body.token)).status).toBe(200);

    const { rows } = await testPool().query(
      'SELECT password_hash, google_sub FROM users WHERE email = $1',
      ['maya@gmail.com'],
    );
    expect(rows[0]).toEqual({ password_hash: null, google_sub: 'google-sub-1' });

    // Signing in again finds the same account.
    const again = await google(a, idToken());
    expect(again.body.user.id).toBe(res.body.user.id);
  });

  it('password login for a Google-only account fails like a wrong password', async () => {
    const a = app();
    await google(a, idToken());
    const res = await api.post(a, '/auth/login', undefined, {
      email: 'maya@gmail.com',
      password: 'anything-at-all',
    });
    expect(res.status).toBe(401);
    expect(res.body.error.message).toBe('Email or password is incorrect.');
  });

  it('links an existing email account, clears its password and ends its sessions', async () => {
    const a = app();
    const existing = await registerUser(a, 'Maya', 'maya@gmail.com', 'someone-elses-pw');
    const res = await google(a, idToken());
    expect(res.status).toBe(200);
    expect(res.body.user.id).toBe(existing.id);
    // Whoever registered the email with a password is locked out.
    expect((await api.get(a, '/me', existing.token)).status).toBe(401);
    const pw = await api.post(a, '/auth/login', undefined, {
      email: 'maya@gmail.com',
      password: 'someone-elses-pw',
    });
    expect(pw.status).toBe(401);
    expect((await api.get(a, '/me', res.body.token)).status).toBe(200);
  });

  it('refuses a different Google account for an already linked email', async () => {
    const a = app();
    await google(a, idToken());
    const res = await google(a, idToken({ sub: 'google-sub-2' }));
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('google_account_mismatch');
  });

  it.each([
    ['wrong audience', () => idToken({}, { aud: 'someone-else.apps.googleusercontent.com' })],
    ['wrong issuer', () => idToken({}, { iss: 'https://evil.example.com' })],
    ['expired', () => idToken({}, { exp: '-10s' })],
    ['unverified email', () => idToken({ email_verified: false })],
    ['signed by another key', () => idToken({}, { key: other.privateKey })],
    ['unknown key id', () => idToken({}, { kid: 'kid-unknown' })],
  ])('rejects a token with %s', async (_label, make) => {
    const res = await google(app(), make());
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('unauthorized');
  });

  it('rejects a forged HS256 token', async () => {
    const forged = jwt.sign({ email: 'x@gmail.com', email_verified: true }, 'secret', {
      algorithm: 'HS256',
      keyid: 'kid-1',
      subject: 'x',
      audience: CLIENT_ID,
      issuer: 'https://accounts.google.com',
    });
    expect((await google(app(), forged)).status).toBe(401);
  });

  it('is 503 when no client id is configured, 422 without a token', async () => {
    const off = await google(testApp({ googleClientIds: [] }), idToken());
    expect(off.status).toBe(503);
    expect(off.body.error.code).toBe('google_not_configured');
    expect((await api.post(app(), '/auth/google', undefined, {})).status).toBe(422);
  });

  it('Google-only accounts are told to set a password first', async () => {
    const a = app();
    const { token } = (await google(a, idToken())).body;
    const change = await api.post(a, '/auth/change-password', token, {
      current_password: 'x',
      new_password: 'new-password',
    });
    expect(change.status).toBe(409);
    expect(change.body.error.code).toBe('no_password');
    const del = await api.del(a, '/users/me', token).send({ password: 'x' });
    expect(del.status).toBe(409);
    expect(del.body.error.code).toBe('no_password');
  });
});
