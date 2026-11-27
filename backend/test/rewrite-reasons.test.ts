import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import supertest from 'supertest';
import { Express } from 'express';
import { api, closePool, ensureSchema, resetDb, seedGroup, testApp, testPool } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const KEY = 'test-pipeline-key';
const withKey = { 'X-Pipeline-Key': KEY, 'Content-Type': 'application/json' };
const pipelineApp = (): Express => testApp({ pipelineApiKey: KEY, runStubWorker: false });

async function submitAndClaim(app: Express, groupId: string, token: string) {
  const sent = await api.post(app, `/groups/${groupId}/messages`, token, {
    text: 'you idiots fix the login',
    is_anonymous: false,
  });
  expect(sent.status).toBe(201);
  const claim = await supertest(app).post('/internal/pipeline/claim').set(withKey).send('{"max_jobs":1}');
  return claim.body.jobs[0] as { job_id: string; raw_message_id: string };
}

function result(app: Express, body: Record<string, unknown>) {
  return supertest(app).post('/internal/pipeline/result').set(withKey).send(body);
}

describe('moderation flags and rewrite reasons (API.md 72)', () => {
  it('stores advisory flags with a rewrite and shows them to the controller only', async () => {
    const app = pipelineApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const job = await submitAndClaim(app, groupId, contributor.token);
    const res = await result(app, {
      job_id: job.job_id,
      raw_message_id: job.raw_message_id,
      outcome: 'ok',
      rewritten_text: 'Please fix the login; I am frustrated it is still broken.',
      intent_preservation_score: 1,
      relevance_score: 0.5,
      relevance_label: 'borderline',
      pipeline_version: 'test 1',
      moderation_flags: ['abusive_language', 'abusive_language'],
    });
    expect(res.body).toEqual({ applied: true });
    const queue = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(queue.body.items[0].moderation_flags).toEqual(['abusive_language']);
    expect(queue.body.items[0].rewrite_error_code).toBeNull();
    // Flags never hide or reject: the message is still pending review.
    expect(queue.body.items[0].status).toBe('pending');
    expect((await api.get(app, `/groups/${groupId}/review-queue`, contributor.token)).status).toBe(403);
  });

  it('rejects unknown flag codes', async () => {
    const app = pipelineApp();
    const { contributor, groupId } = await seedGroup(app);
    const job = await submitAndClaim(app, groupId, contributor.token);
    const res = await result(app, {
      job_id: job.job_id,
      raw_message_id: job.raw_message_id,
      outcome: 'ok',
      rewritten_text: 'ok',
      intent_preservation_score: 1,
      relevance_score: 0.5,
      relevance_label: 'borderline',
      pipeline_version: 'test 1',
      moderation_flags: ['who_wrote_it'],
    });
    expect(res.status).toBe(422);
  });

  it('keeps the latest failure reason for the controller', async () => {
    const app = pipelineApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const job = await submitAndClaim(app, groupId, contributor.token);
    const res = await result(app, {
      job_id: job.job_id,
      raw_message_id: job.raw_message_id,
      outcome: 'error',
      error_code: 'intent_not_preserved',
    });
    expect(res.body.reason).toBe('error_recorded');
    const detail = await api.get(
      app,
      `/groups/${groupId}/review-queue/${job.raw_message_id}`,
      controller.token,
    );
    expect(detail.body.rewrite_error_code).toBe('intent_not_preserved');
  });

  it('a failure a retry cannot change ends the job at once', async () => {
    const app = pipelineApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const job = await submitAndClaim(app, groupId, contributor.token);
    const res = await result(app, {
      job_id: job.job_id,
      raw_message_id: job.raw_message_id,
      outcome: 'error',
      error_code: 'unsupported_language',
    });
    expect(res.body.reason).toBe('failed_permanently');
    const queue = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(queue.body.items[0]).toMatchObject({
      pipeline_status: 'failed',
      rewrite_error_code: 'unsupported_language',
      status: 'pending',
    });
    const jobs = await testPool().query('SELECT status FROM jobs WHERE id = $1', [job.job_id]);
    expect(jobs.rows[0].status).toBe('failed');
  });
});
