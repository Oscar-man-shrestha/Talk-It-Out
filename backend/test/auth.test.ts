import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

describe('auth', () => {
  it('register returns 201 {token, user:{id,name,email}}', async () => {
    const app = testApp();
    const res = await api.post(app, '/auth/register', undefined, {
      name: 'Priya',
      email: 'priya@example.com',
      password: 'secret123',
    });
    expect(res.status).toBe(201);
    expect(Object.keys(res.body).sort()).toEqual(['token', 'user']);
    expect(typeof res.body.token).toBe('string');
    expect(Object.keys(res.body.user).sort()).toEqual(['email', 'id', 'name']);
    expect(res.body.user.name).toBe('Priya');
    expect(res.body.user.email).toBe('priya@example.com');
  });

  it('duplicate email returns a 409 envelope', async () => {
    const app = testApp();
    await registerUser(app, 'Priya', 'priya@example.com');
    const res = await api.post(app, '/auth/register', undefined, {
      name: 'Someone Else',
      email: 'priya@example.com',
      password: 'secret123',
    });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBeDefined();
    expect(res.body.error.message).toContain('already registered');
  });

  it('login returns 200 with a session for the right password', async () => {
    const app = testApp();
    await registerUser(app, 'Priya', 'priya@example.com', 'secret123');
    const res = await api.post(app, '/auth/login', undefined, {
      email: 'priya@example.com',
      password: 'secret123',
    });
    expect(res.status).toBe(200);
    expect(typeof res.body.token).toBe('string');
    expect(res.body.user.email).toBe('priya@example.com');
  });

  it('wrong password returns 401; unknown email returns 401 (no 404 leak)', async () => {
    const app = testApp();
    await registerUser(app, 'Priya', 'priya@example.com', 'secret123');
    const wrong = await api.post(app, '/auth/login', undefined, {
      email: 'priya@example.com',
      password: 'wrongpassword',
    });
    const unknown = await api.post(app, '/auth/login', undefined, {
      email: 'nobody@example.com',
      password: 'whatever123',
    });
    expect(wrong.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(wrong.body.error.message).toBe('Email or password is incorrect.');
  });

  it('GET /me returns the authenticated user', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Priya', 'priya@example.com');
    const res = await api.get(app, '/me', user.token);
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ id: user.id, name: 'Priya', email: 'priya@example.com' });
  });

  it('logout returns 204', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Priya', 'priya@example.com');
    const res = await api.post(app, '/auth/logout', user.token);
    expect(res.status).toBe(204);
  });

  it('validation failures return 422 envelopes', async () => {
    const app = testApp();
    const cases = [
      { name: '', email: 'priya@example.com', password: 'secret123' },
      { name: 'Priya', email: 'not-an-email', password: 'secret123' },
      { name: 'Priya', email: 'priya@example.com', password: 'short' },
      { email: 'priya@example.com', password: 'secret123' },
    ];
    for (const body of cases) {
      const res = await api.post(app, '/auth/register', undefined, body);
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('validation');
      expect(typeof res.body.error.message).toBe('string');
    }
  });

  it('derives the username from the email local-part and suffixes on collision', async () => {
    const app = testApp();
    const first = await registerUser(app, 'First', 'sameperson@example.com');
    const second = await registerUser(app, 'Second', 'sameperson@otherdomain.org');

    const { rows } = await testPool().query(
      'SELECT id, username FROM users WHERE id = ANY($1)',
      [[first.id, second.id]],
    );
    const byId = new Map(rows.map((row) => [row.id, row.username]));
    expect(byId.get(first.id)).toBe('sameperson');
    // Spec: on collision, append "-" plus the first 4 hex chars of the new user id.
    expect(byId.get(second.id)).toBe(`sameperson-${second.id.slice(0, 4)}`);
  });

  it('strips characters outside [a-z0-9._-] from the derived username', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Weird Local', 'Priya+Tag.Sub_1-x@Example.COM');
    const { rows } = await testPool().query(
      'SELECT username FROM users WHERE id = $1',
      [user.id],
    );
    expect(rows[0].username).toBe('priyatag.sub_1-x');
  });
});
