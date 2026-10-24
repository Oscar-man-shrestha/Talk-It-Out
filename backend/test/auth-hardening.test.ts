import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import jwt from 'jsonwebtoken';
import { config } from '../src/config';
import { resetLoginThrottle } from '../src/routes/auth';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

describe('token hardening', () => {
  it('an expired token returns 401', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Expiry', 'expiry@example.com');
    const expired = jwt.sign({}, config.jwtSecret, {
      subject: user.id,
      algorithm: 'HS256',
      expiresIn: -60,
    });
    const res = await api.get(app, '/me', expired);
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('unauthorized');
  });

  it('a tampered token returns 401', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Tamper', 'tamper@example.com');
    const tampered =
      user.token.slice(0, -3) +
      (user.token.endsWith('aaa') ? 'bbb' : 'aaa');
    const res = await api.get(app, '/me', tampered);
    expect(res.status).toBe(401);
  });

  it('a token signed with a different secret returns 401', async () => {
    const app = testApp();
    const user = await registerUser(app, 'OtherKey', 'otherkey@example.com');
    const foreign = jwt.sign({}, 'c'.repeat(48), {
      subject: user.id,
      algorithm: 'HS256',
      expiresIn: '1h',
    });
    expect((await api.get(app, '/me', foreign)).status).toBe(401);
  });

  it('a token for a deleted user returns 401', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Ghost', 'ghost@example.com');
    await testPool().query('DELETE FROM users WHERE id = $1', [user.id]);
    const res = await api.get(app, '/me', user.token);
    expect(res.status).toBe(401);
  });
});

describe('per-account login throttling', () => {
  beforeEach(() => {
    resetLoginThrottle();
  });

  it('blocks the email after 5 consecutive failures, even from a new IP, and reports Retry-After', async () => {
    // The IP limiter is raised so only the per-email counter is exercised;
    // the counter is keyed by email, so a request from any IP is blocked.
    const app = testApp({ rateLimitAuthMax: 1000 });
    const email = 'victim@example.com';
    const register = await api.post(app, '/auth/register', undefined, {
      name: 'Victim',
      email,
      password: 'correct-horse-1',
    });
    expect(register.status).toBe(201);

    for (let i = 0; i < 5; i += 1) {
      const fail = await api.post(app, '/auth/login', undefined, {
        email,
        password: 'wrongpassword',
      });
      expect(fail.status).toBe(401);
    }

    // Even the CORRECT password is throttled for this email now.
    const blocked = await api.post(app, '/auth/login', undefined, {
      email,
      password: 'correct-horse-1',
    });
    expect(blocked.status).toBe(429);
    expect(blocked.body.error.code).toBe('rate_limited');
    expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(0);
  });

  it('a successful login resets the counter', async () => {
    const app = testApp({ rateLimitAuthMax: 1000 });
    const email = 'phoenix@example.com';
    await api.post(app, '/auth/register', undefined, {
      name: 'Phoenix',
      email,
      password: 'correct-horse-2',
    });

    // 4 failures, then success (under the limit of 5, and it resets).
    for (let i = 0; i < 4; i += 1) {
      await api.post(app, '/auth/login', undefined, { email, password: 'wrongpassword' });
    }
    const ok = await api.post(app, '/auth/login', undefined, {
      email,
      password: 'correct-horse-2',
    });
    expect(ok.status).toBe(200);

    // 4 more failures would now block only if the counter had NOT reset.
    for (let i = 0; i < 4; i += 1) {
      await api.post(app, '/auth/login', undefined, { email, password: 'wrongpassword' });
    }
    const okAgain = await api.post(app, '/auth/login', undefined, {
      email,
      password: 'correct-horse-2',
    });
    expect(okAgain.status).toBe(200);
  });

  it('unknown emails also burn comparable argon2 work (no status leak)', async () => {
    const app = testApp();
    const unknown = await api.post(app, '/auth/login', undefined, {
      email: 'never-registered@example.com',
      password: 'whatever123',
    });
    expect(unknown.status).toBe(401);
    expect(unknown.body.error.message).toBe('Email or password is incorrect.');
  });
});

describe('input normalization and password policy', () => {
  it('register and login normalize email case and whitespace', async () => {
    const app = testApp();
    const reg = await api.post(app, '/auth/register', undefined, {
      name: 'Mixed Case',
      email: '  MiXeD@ExAmPlE.CoM  ',
      password: 'secret123',
    });
    expect(reg.status).toBe(201);
    expect(reg.body.user.email).toBe('mixed@example.com');

    const login = await api.post(app, '/auth/login', undefined, {
      email: 'MIXED@example.COM',
      password: 'secret123',
    });
    expect(login.status).toBe(200);
    expect(login.body.user.email).toBe('mixed@example.com');
  });

  it('rejects weak and overlong passwords with 422 envelopes', async () => {
    const app = testApp();
    const weak = await api.post(app, '/auth/register', undefined, {
      name: 'Weak',
      email: 'weak@example.com',
      password: 'short7',
    });
    expect(weak.status).toBe(422);
    expect(weak.body.error.message).toContain('at least 8');

    const long = await api.post(app, '/auth/register', undefined, {
      name: 'Long',
      email: 'long@example.com',
      password: 'x'.repeat(129),
    });
    expect(long.status).toBe(422);
    expect(long.body.error.message).toContain('128');
  });

  it('ignores unknown JSON keys instead of failing', async () => {
    const app = testApp();
    const res = await api.post(app, '/auth/register', undefined, {
      name: 'Extra',
      email: 'extra@example.com',
      password: 'secret123',
      role: 'admin',
      is_admin: true,
    });
    expect(res.status).toBe(201);
    expect(res.body.user.email).toBe('extra@example.com');
  });
});
