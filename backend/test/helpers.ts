import supertest from 'supertest';
import { Pool } from 'pg';
import { Express } from 'express';
import { loadConfig, Config } from '../src/config';
import { createPool } from '../src/db';
import { migrate } from '../src/migrate';
import { buildApp } from '../src/app';
import { resetLoginThrottle } from '../src/routes/auth';

export const config: Config = loadConfig();

let pool: Pool | undefined;

export function testPool(): Pool {
  if (!pool) pool = createPool(config.testDatabaseUrl);
  return pool;
}

export function testApp(overrides: Partial<Config> = {}): Express {
  return buildApp(testPool(), { ...config, ...overrides });
}

export async function ensureSchema(): Promise<void> {
  await migrate(testPool());
}

export async function resetDb(): Promise<void> {
  resetLoginThrottle();
  await testPool().query(
    'TRUNCATE notifications, jobs, published_messages, raw_messages, group_members, groups, posts, comments, post_likes, users CASCADE',
  );
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}

export interface TestUser {
  token: string;
  id: string;
  name: string;
  email: string;
}

/** Registers a user through the API and returns their token and id. */
export async function registerUser(
  app: Express,
  name: string,
  email: string,
  password = 'secret123',
): Promise<TestUser> {
  const res = await supertest(app)
    .post('/auth/register')
    .send({ name, email, password });
  if (res.status !== 201) {
    throw new Error(
      `registerUser failed for ${email}: ${res.status} ${JSON.stringify(res.body)}`,
    );
  }
  return {
    token: res.body.token,
    id: res.body.user.id,
    name: res.body.user.name,
    email: res.body.user.email,
  };
}

/** Convenience wrappers for authorized requests against the app. */
export const api = {
  get: (app: Express, path: string, token?: string) =>
    supertest(app).get(path).set(token ? { Authorization: `Bearer ${token}` } : {}),
  post: (app: Express, path: string, token?: string, body?: unknown) =>
    supertest(app)
      .post(path)
      .set(token ? { Authorization: `Bearer ${token}` } : {})
      .send(body ?? {}),
  del: (app: Express, path: string, token: string) =>
    supertest(app).delete(path).set({ Authorization: `Bearer ${token}` }),
};

/**
 * Registers a controller and a contributor and puts both in one new group.
 * The contributor's derived username is `<localPart>@...` minus the domain,
 * so it equals the email local-part (all valid chars, already lowercase).
 */
export async function seedGroup(
  app: Express,
  opts: { agenda?: string } = {},
): Promise<{
  controller: TestUser;
  contributor: TestUser;
  contributorUsername: string;
  groupId: string;
}> {
  const suffix = Math.random().toString(36).slice(2, 8);
  const controller = await registerUser(
    app,
    'Cara Controller',
    `controller-${suffix}@example.com`,
  );
  const contributorEmail = `contributor-${suffix}@example.com`;
  const contributor = await registerUser(app, 'Connie Contributor', contributorEmail);
  const created = await api.post(app, '/groups', controller.token, {
    agenda: opts.agenda ?? 'Making NLP notes',
  });
  if (created.status !== 201) {
    throw new Error(`seedGroup create failed: ${JSON.stringify(created.body)}`);
  }
  const contributorUsername = `contributor-${suffix}`;
  const added = await api.post(
    app,
    `/groups/${created.body.id}/members`,
    controller.token,
    { username: contributorUsername, role: 'contributor' },
  );
  if (added.status !== 201) {
    throw new Error(`seedGroup add member failed: ${JSON.stringify(added.body)}`);
  }
  return { controller, contributor, contributorUsername, groupId: created.body.id };
}

/** Submits a contributor message and runs the stub worker until it is done. */
export async function submitAndProcess(
  app: Express,
  groupId: string,
  contributor: TestUser,
  text: string,
  isAnonymous: boolean,
): Promise<string> {
  const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
    text,
    is_anonymous: isAnonymous,
  });
  if (sent.status !== 201) {
    throw new Error(`submit failed: ${JSON.stringify(sent.body)}`);
  }
  return sent.body.id as string;
}
