import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import supertest from 'supertest';
import { Pool } from 'pg';
import { loadConfig, validateSecrets } from '../src/config';
import { createPool } from '../src/db';
import { buildApp } from '../src/app';
import { closePool, ensureSchema, resetDb, testApp } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

describe('security headers', () => {
  it('sets helmet API defaults and hides x-powered-by', async () => {
    const res = await supertest(testApp()).get('/health');
    expect(res.status).toBe(200);
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-powered-by']).toBeUndefined();
    expect(String(res.headers['content-security-policy'] ?? '')).not.toBe('undefined');
  });
});

describe('request body limits', () => {
  it('an oversized JSON body returns a 413 envelope', async () => {
    const app = testApp({ jsonBodyLimit: '1kb' });
    const res = await supertest(app)
      .post('/auth/register')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify({ name: 'Big', email: 'big@example.com', password: 'x'.repeat(3000) }));
    expect(res.status).toBe(413);
    expect(res.body.error.code).toBe('body_too_large');
    expect(typeof res.body.error.message).toBe('string');
  });
});

describe('rate limiting', () => {
  it('the strict auth limiter returns 429 with Retry-After and the envelope', async () => {
    const app = testApp({ rateLimitAuthMax: 2 });
    const attempt = () =>
      supertest(app)
        .post('/auth/login')
        .set('Content-Type', 'application/json')
        .send({ email: 'nobody@example.com', password: 'wrongpassword' });

    expect((await attempt()).status).toBe(401);
    expect((await attempt()).status).toBe(401);
    const throttled = await attempt();
    expect(throttled.status).toBe(429);
    expect(throttled.body.error.code).toBe('rate_limited');
    expect(Number(throttled.headers['retry-after'])).toBeGreaterThan(0);
  });

  it('the global limiter applies to public routes', async () => {
    const app = testApp({ rateLimitGlobalMax: 2 });
    expect((await supertest(app).get('/health')).status).toBe(200);
    expect((await supertest(app).get('/health')).status).toBe(200);
    const throttled = await supertest(app).get('/health');
    expect(throttled.status).toBe(429);
    expect(throttled.body.error.code).toBe('rate_limited');
    expect(Number(throttled.headers['retry-after'])).toBeGreaterThan(0);
  });

  it('the internal limiter is generous enough for a polling worker', async () => {
    const app = testApp({ pipelineApiKey: 'worker-key' });
    for (let i = 0; i < 6; i += 1) {
      const res = await supertest(app)
        .post('/internal/pipeline/claim')
        .set({ 'X-Pipeline-Key': 'worker-key', 'Content-Type': 'application/json' })
        .send('{}');
      expect(res.status).toBe(200);
    }
  });
});

describe('readiness', () => {
  it('GET /ready returns 200 when the database answers', async () => {
    const res = await supertest(testApp()).get('/ready');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ready' });
  });

  it('GET /ready returns a 503 envelope when the database is down; /health stays cheap', async () => {
    const deadPool = createPool('postgres://127.0.0.1:59999/none', {
      connectionTimeoutMillis: 300,
      statementTimeoutMillis: 300,
    });
    const app = buildApp(deadPool, loadConfig({ ...process.env, NODE_ENV: 'test' }));
    const ready = await supertest(app).get('/ready');
    expect(ready.status).toBe(503);
    expect(ready.body.error.code).toBe('not_ready');
    expect(JSON.stringify(ready.body)).not.toContain('postgres');

    const health = await supertest(app).get('/health');
    expect(health.status).toBe(200);
    await deadPool.end().catch(() => undefined);
  });
});

describe('error handling', () => {
  it('a 500 response leaks no stack or internal message', async () => {
    const goodApp = testApp();
    const { registerUser } = await import('./helpers');
    const user = await registerUser(goodApp, 'Leak Check', 'leak-check@example.com');

    const explodingPool = {
      query: () => {
        throw new Error('secret internal detail with a very unique string');
      },
    } as unknown as Pool;
    const app = buildApp(explodingPool, loadConfig({ ...process.env, NODE_ENV: 'test' }));

    const res = await supertest(app)
      .get('/groups')
      .set('Authorization', `Bearer ${user.token}`);
    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('internal_error');
    const body = JSON.stringify(res.body);
    expect(body).not.toContain('secret internal detail');
    expect(body).not.toContain('at ');
    expect(body).not.toContain('Error');
  });
});

describe('startup secret validation (AMENDMENT)', () => {
  const BASE = { NODE_ENV: 'production', DATABASE_URL: 'x' } as NodeJS.ProcessEnv;

  it('rejects a missing, short, or placeholder JWT_SECRET outside tests', () => {
    expect(() => validateSecrets({ ...BASE })).toThrow(/JWT_SECRET/);
    expect(() => validateSecrets({ ...BASE, JWT_SECRET: 'short' })).toThrow(/at least 32/);
    expect(() =>
      validateSecrets({ ...BASE, JWT_SECRET: '<generate-a-long-random-secret>' }),
    ).toThrow(/placeholder/);
  });

  it('accepts a strong JWT_SECRET with or without PIPELINE_API_KEY', () => {
    const strong = 'a'.repeat(40);
    expect(() => validateSecrets({ ...BASE, JWT_SECRET: strong })).not.toThrow();
    expect(() =>
      validateSecrets({ ...BASE, JWT_SECRET: strong, PIPELINE_API_KEY: '' }),
    ).not.toThrow();
  });

  it('rejects a short or placeholder PIPELINE_API_KEY when one is set', () => {
    const strong = 'a'.repeat(40);
    expect(() =>
      validateSecrets({ ...BASE, JWT_SECRET: strong, PIPELINE_API_KEY: 'short' }),
    ).toThrow(/PIPELINE_API_KEY/);
    expect(() =>
      validateSecrets({
        ...BASE,
        JWT_SECRET: strong,
        PIPELINE_API_KEY: '<generate-a-long-random-secret-or-leave-unset>',
      }),
    ).toThrow(/placeholder/);
    expect(() =>
      validateSecrets({
        ...BASE,
        JWT_SECRET: strong,
        PIPELINE_API_KEY: 'b'.repeat(40),
      }),
    ).not.toThrow();
  });

  it('never runs under NODE_ENV=test', () => {
    expect(() =>
      validateSecrets({ NODE_ENV: 'test', JWT_SECRET: '', PIPELINE_API_KEY: '<x>' }),
    ).not.toThrow();
  });
});
