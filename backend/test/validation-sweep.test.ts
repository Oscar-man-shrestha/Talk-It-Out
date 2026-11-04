import { beforeAll, beforeEach, afterAll, describe, expect, it, vi } from 'vitest';
import supertest from 'supertest';
import { setupGracefulShutdown } from '../src/shutdown';
import { migrate } from '../src/migrate';
import { api, closePool, ensureSchema, registerUser, resetDb, seedGroup, testApp, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

describe('malformed UUID path params return 404, never 500', () => {
  const BAD = 'not-a-uuid';

  it('covers every parametrized route', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Sweep', 'sweep@example.com');
    const auth = { Authorization: `Bearer ${user.token}` };
    const json = { ...auth, 'Content-Type': 'application/json' };

    const cases: Array<[string, string]> = [
      ['get', `/groups/${BAD}`],
      ['get', `/groups/${BAD}/members`],
      ['post', `/groups/${BAD}/members`],
      ['delete', `/groups/${BAD}/members/${BAD}`],
      ['get', `/groups/${BAD}/messages`],
      ['get', `/groups/${BAD}/messages/mine`],
      ['post', `/groups/${BAD}/messages`],
      ['post', `/groups/${BAD}/messages/controller`],
      ['delete', `/groups/${BAD}/messages/${BAD}`],
      ['get', `/groups/${BAD}/review-queue`],
      ['get', `/groups/${BAD}/review-queue/${BAD}`],
      ['post', `/groups/${BAD}/leave`],
      ['post', `/messages/${BAD}/accept`],
      ['post', `/messages/${BAD}/reject`],
      ['post', `/notifications/${BAD}/read`],
      ['get', `/posts/${BAD}`],
      ['post', `/posts/${BAD}/reactions`],
      ['delete', `/posts/${BAD}/reactions`],
      ['get', `/posts/${BAD}/comments`],
      ['post', `/posts/${BAD}/comments`],
      ['post', `/posts/${BAD}/group`],
    ];

    for (const [method, path] of cases) {
      const res = await supertest(app)[method](path).set(json).send({});
      expect(res.status, `${method.toUpperCase()} ${path}`).toBe(404);
      expect(res.body.error?.code, `${method.toUpperCase()} ${path}`).toBe('not_found');
    }
  });
});

describe('string length caps return 422 envelopes', () => {
  it('rejects overlong agenda, name, username, post, and comment', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Caps', 'caps@example.com');
    const group = await api.post(app, '/groups', user.token, { agenda: 'caps group' });
    const groupId = group.body.id as string;

    const agenda = await api.post(app, '/groups', user.token, { agenda: 'a'.repeat(501) });
    expect(agenda.status).toBe(422);

    const name = await api.post(app, '/auth/register', undefined, {
      name: 'n'.repeat(201),
      email: 'longname@example.com',
      password: 'secret123',
    });
    expect(name.status).toBe(422);

    const username = await api.post(app, `/groups/${groupId}/members`, user.token, {
      username: 'u'.repeat(101),
      role: 'contributor',
    });
    expect(username.status).toBe(422);

    const post = await api.post(app, '/posts', user.token, { content: 'c'.repeat(5001) });
    expect(post.status).toBe(422);

    const createdPost = await api.post(app, '/posts', user.token, { content: 'fine post' });
    const comment = await api.post(
      app,
      `/posts/${createdPost.body.id}/comments`,
      user.token,
      { content: 'c'.repeat(5001) },
    );
    expect(comment.status).toBe(422);
  });
});

describe('cursor parsing never throws 500', () => {
  it('garbage cursors return 400 envelopes on every list endpoint', async () => {
    const app = testApp();
    const { controller, groupId } = await seedGroup(app);
    const post = await api.post(app, '/posts', controller.token, { content: 'cursor post' });

    const paths = [
      `/groups?cursor=zzz`,
      `/groups/${groupId}/members?cursor=zzz`,
      `/groups/${groupId}/messages?cursor=zzz`,
      `/groups/${groupId}/messages/mine?cursor=zzz`,
      `/groups/${groupId}/review-queue?cursor=zzz`,
      `/posts?cursor=zzz`,
      `/posts/${post.body.id}/comments?cursor=zzz`,
      `/notifications?cursor=zzz`,
    ];
    for (const path of paths) {
      const res = await api.get(app, path, controller.token);
      expect(res.status, path).toBe(400);
      expect(res.body.error?.code, path).toBe('invalid_cursor');
    }
  });
});

describe('graceful shutdown', () => {
  it('stops workers, closes the server and pool, and exits 0', async () => {
    const close = vi.fn((cb?: () => void) => {
      cb?.();
      return null as unknown as ReturnType<import('node:http').Server['close']>;
    });
    const closeIdle = vi.fn();
    const end = vi.fn(async () => undefined);
    const stop = vi.fn();
    const exit = vi.fn();

    const cancel = setupGracefulShutdown({
      server: { close, closeIdleConnections: closeIdle } as never,
      pools: [{ end }],
      stop: [stop],
      exit,
      signals: ['SIGUSR2'],
    });

    process.emit('SIGUSR2');
    // Let the async pool end promise resolve.
    await new Promise((resolve) => setImmediate(resolve));
    await new Promise((resolve) => setImmediate(resolve));

    expect(stop).toHaveBeenCalledTimes(1);
    expect(closeIdle).toHaveBeenCalledTimes(1);
    expect(close).toHaveBeenCalledTimes(1);
    expect(end).toHaveBeenCalledTimes(1);
    expect(exit).toHaveBeenCalledWith(0);
    expect(exit).toHaveBeenCalledTimes(1);

    cancel();
    process.emit('SIGUSR2');
    await new Promise((resolve) => setImmediate(resolve));
    expect(exit).toHaveBeenCalledTimes(1); // listeners removed
  });
});

describe('migrations', () => {
  it('the runner is idempotent: re-running applies nothing', async () => {
    const ran = await migrate(testPool());
    expect(ran).toEqual([]);
    const applied = await testPool().query(
      'SELECT filename FROM schema_migrations ORDER BY filename',
    );
    expect(applied.rows.map((row) => row.filename)).toEqual([
      '001_init.sql',
      '002_feed.sql',
      '003_one_group_per_post.sql',
      '004_performance_indexes.sql',
      '005_profiles.sql',
      '006_message_reactions.sql',
      '007_refresh_tokens.sql',
    ]);
  });
});
