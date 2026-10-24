import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
import supertest from 'supertest';
import { closePool, ensureSchema, resetDb, testApp } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

describe('health, mounting, CORS, and the error envelope', () => {
  it('GET /health returns {"status":"ok"} publicly', async () => {
    const res = await supertest(testApp()).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('the same router is mounted at /api/v1', async () => {
    const res = await supertest(testApp()).get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('unknown routes return the error envelope with 404', async () => {
    const res = await supertest(testApp()).get('/definitely-not-a-route');
    expect(res.status).toBe(404);
    expect(res.body.error).toBeDefined();
    expect(typeof res.body.error.code).toBe('string');
    expect(typeof res.body.error.message).toBe('string');
  });

  it('malformed JSON bodies return a 400 envelope, not a stack trace', async () => {
    const res = await supertest(testApp())
      .post('/auth/register')
      .set('Content-Type', 'application/json')
      .send('{this is not json');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('invalid_json');
  });

  it('GET /me without a token returns a 401 envelope', async () => {
    const res = await supertest(testApp()).get('/me');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('unauthorized');
  });

  it('GET /me with a garbage token returns a 401 envelope', async () => {
    const res = await supertest(testApp())
      .get('/me')
      .set('Authorization', 'Bearer not-a-real-token');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('unauthorized');
  });

  it('allows the Flutter web origin through CORS preflight', async () => {
    const origin = 'http://127.0.0.1:52000';
    const res = await supertest(
      testApp({ corsOrigins: [origin, 'http://localhost:52000'] }),
    )
      .options('/auth/login')
      .set('Origin', origin)
      .set('Access-Control-Request-Method', 'POST')
      .set('Access-Control-Request-Headers', 'authorization, content-type');
    expect(res.status).toBeLessThan(400);
    expect(res.headers['access-control-allow-origin']).toBe(origin);
    expect(res.headers['access-control-allow-headers']).toContain('Authorization');
  });

  it('does not allow an unknown origin', async () => {
    const res = await supertest(
      testApp({ corsOrigins: ['http://127.0.0.1:52000', 'http://localhost:52000'] }),
    )
      .options('/auth/login')
      .set('Origin', 'http://evil.example')
      .set('Access-Control-Request-Method', 'POST');
    expect(res.headers['access-control-allow-origin']).toBeUndefined();
  });
});
