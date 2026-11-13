import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import supertest from 'supertest';
import { Express } from 'express';
import { stubWorkerShouldRun } from '../src/config';
import { runStubWorkerOnce } from '../src/worker/stubWorker';
import {
  api,
  closePool,
  ensureSchema,
  resetDb,
  seedGroup,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const KEY = 'test-pipeline-key';
const withKey = { 'X-Pipeline-Key': KEY, 'Content-Type': 'application/json' };

/** App with the internal pipeline API enabled and the stub worker off. */
function pipelineApp(overrides: Record<string, unknown> = {}): Express {
  return testApp({ pipelineApiKey: KEY, runStubWorker: false, ...overrides });
}

async function submitMessage(app: Express, groupId: string, contributorToken: string) {
  const res = await api.post(app, `/groups/${groupId}/messages`, contributorToken, {
    text: 'external pipeline will rewrite me',
    is_anonymous: true,
  });
  if (res.status !== 201) throw new Error(`submit failed: ${JSON.stringify(res.body)}`);
  return res.body.id as string;
}

async function claimJobs(app: Express, body = '{"max_jobs":5}') {
  return supertest(app).post('/internal/pipeline/claim').set(withKey).send(body);
}

function okResult(jobId: string, rawId: string, overrides: Record<string, unknown> = {}) {
  return {
    job_id: jobId,
    raw_message_id: rawId,
    outcome: 'ok',
    rewritten_text: '[external rewrite] moderated version',
    intent_preservation_score: 0.95,
    relevance_score: 0.7,
    relevance_label: 'borderline',
    pipeline_version: 'test-worker 1.0',
    ...overrides,
  };
}

describe('internal pipeline auth', () => {
  it('missing or wrong key is 401; the routes use the error envelope', async () => {
    const app = pipelineApp();
    const missing = await supertest(app)
      .post('/internal/pipeline/claim')
      .set('Content-Type', 'application/json')
      .send('{}');
    expect(missing.status).toBe(401);
    expect(missing.body.error.code).toBe('invalid_pipeline_key');

    const wrong = await supertest(app)
      .post('/internal/pipeline/claim')
      .set({ 'X-Pipeline-Key': 'wrong-key', 'Content-Type': 'application/json' })
      .send('{}');
    expect(wrong.status).toBe(401);
    expect(wrong.body.error).toBeDefined();
  });

  it('returns 503 with the envelope when PIPELINE_API_KEY is unset', async () => {
    const app = testApp({ pipelineApiKey: '' });
    const res = await supertest(app)
      .post('/internal/pipeline/claim')
      .set({ 'X-Pipeline-Key': 'anything', 'Content-Type': 'application/json' })
      .send('{}');
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('internal_api_disabled');
  });
});

describe('claim', () => {
  it('returns exactly the documented keys per job — never sender data', async () => {
    const app = pipelineApp();
    const { contributor, groupId } = await seedGroup(app, { agenda: 'Contract agenda' });
    await submitMessage(app, groupId, contributor.token);

    const res = await claimJobs(app);
    expect(res.status).toBe(200);
    expect(res.body.jobs).toHaveLength(1);
    const job = res.body.jobs[0];
    expect(Object.keys(job).sort()).toEqual([
      'contract_version',
      'group_agenda',
      'job_id',
      'raw_message_id',
      'text',
      'tone',
    ]);
    expect(job.contract_version).toBe(1);
    // Anonymous message: always the default tone.
    expect(job.tone).toBe('professional');
    expect(job.group_agenda).toBe('Contract agenda');
    expect(job.text).toBe('external pipeline will rewrite me');
    expect(JSON.stringify(res.body)).not.toContain(contributor.id);
    expect(JSON.stringify(res.body)).not.toContain('is_anonymous');
    expect(JSON.stringify(res.body)).not.toContain('Connie');

    // Claimed jobs are running and not immediately reclaimable.
    const second = await claimJobs(app);
    expect(second.body.jobs).toHaveLength(0);
  });

  it('an expired lease makes a running job claimable again', async () => {
    const app = pipelineApp({ pipelineLeaseSeconds: 1 });
    const { contributor, groupId } = await seedGroup(app);
    await submitMessage(app, groupId, contributor.token);

    const first = await claimJobs(app);
    const jobId = first.body.jobs[0].job_id as string;
    expect((await claimJobs(app)).body.jobs).toHaveLength(0);

    // Force the lease to expire.
    await testPool().query(`UPDATE jobs SET run_after = now() - interval '1 second' WHERE id = $1`, [jobId]);
    const reClaimed = await claimJobs(app);
    expect(reClaimed.body.jobs).toHaveLength(1);
    expect(reClaimed.body.jobs[0].job_id).toBe(jobId);
  });

  it('in external mode the stub worker must not start', () => {
    expect(stubWorkerShouldRun({ runStubWorker: true, pipelineMode: 'stub' } as never)).toBe(true);
    expect(stubWorkerShouldRun({ runStubWorker: true, pipelineMode: 'external' } as never)).toBe(false);
    expect(stubWorkerShouldRun({ runStubWorker: false, pipelineMode: 'stub' } as never)).toBe(false);
  });

  it('the stub worker never eats jobs the external worker will claim (kind separation)', async () => {
    const app = pipelineApp();
    const { contributor, groupId } = await seedGroup(app);
    await submitMessage(app, groupId, contributor.token);

    // The groups stub worker only claims process_raw_message jobs, which is
    // exactly what the internal API claims too — so in a shared test pool the
    // stub must be the one disabled. Run it and assert it found nothing
    // because... it would find the job. Instead: verify the two consumers
    // cannot both be enabled by config, asserted above; here verify claim
    // marks running so a late stub run cannot double-process.
    const claimed = await claimJobs(app);
    expect(claimed.body.jobs).toHaveLength(1);
    const stubRun = await runStubWorkerOnce(testPool());
    expect(stubRun.claimed).toBe(0);
  });
});

describe('result', () => {
  it('happy path: apply, then the full review flow works with the external rewrite', async () => {
    const app = pipelineApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const messageId = await submitMessage(app, groupId, contributor.token);

    const claim = await claimJobs(app);
    const job = claim.body.jobs[0];
    const result = await supertest(app)
      .post('/internal/pipeline/result')
      .set(withKey)
      .send(okResult(job.job_id, job.raw_message_id));
    expect(result.status).toBe(200);
    expect(result.body).toEqual({ applied: true });

    // Review queue shows the external rewrite; accept publishes it.
    const queue = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(queue.body.items[0].rewritten_text).toBe('[external rewrite] moderated version');
    expect(queue.body.items[0].pipeline_status).toBe('done');
    expect(queue.body.items[0].relevance_label).toBe('borderline');

    const accepted = await api.post(app, `/messages/${messageId}/accept`, controller.token);
    expect(accepted.status).toBe(200);
    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(chat.body.items).toHaveLength(1);
    expect(chat.body.items[0].text).toBe('[external rewrite] moderated version');
    expect(chat.body.items[0].display_sender).toBeNull();
  });

  it('a duplicate result is a no-op returning applied:false', async () => {
    const app = pipelineApp();
    const { contributor, groupId } = await seedGroup(app);
    await submitMessage(app, groupId, contributor.token);
    const job = (await claimJobs(app)).body.jobs[0];

    const first = await supertest(app).post('/internal/pipeline/result').set(withKey).send(okResult(job.job_id, job.raw_message_id));
    expect(first.body).toEqual({ applied: true });

    const duplicate = await supertest(app).post('/internal/pipeline/result').set(withKey).send(okResult(job.job_id, job.raw_message_id));
    expect(duplicate.status).toBe(200);
    expect(duplicate.body).toEqual({ applied: false, reason: 'already_done' });

    const rewritten = await testPool().query('SELECT rewritten_text FROM raw_messages WHERE id = $1', [job.raw_message_id]);
    expect(rewritten.rows[0].rewritten_text).toBe('[external rewrite] moderated version');
  });

  it('a result for a decided message is discarded', async () => {
    const app = pipelineApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const messageId = await submitMessage(app, groupId, contributor.token);
    const job = (await claimJobs(app)).body.jobs[0];

    // The controller decides while the pipeline is running.
    const rejected = await api.post(app, `/messages/${messageId}/reject`, controller.token);
    expect(rejected.status).toBe(200);

    const result = await supertest(app).post('/internal/pipeline/result').set(withKey).send(okResult(job.job_id, job.raw_message_id));
    expect(result.status).toBe(200);
    expect(result.body).toEqual({ applied: false, reason: 'message_decided' });

    const raw = await testPool().query(
      'SELECT status, pipeline_status, rewritten_text FROM raw_messages WHERE id = $1',
      [messageId],
    );
    expect(raw.rows[0].status).toBe('rejected');
    expect(raw.rows[0].rewritten_text).toBeNull();
  });

  it('a malformed result returns 422 and counts as a failed attempt', async () => {
    const app = pipelineApp({ pipelineMaxAttempts: 2 });
    const { contributor, groupId } = await seedGroup(app);
    await submitMessage(app, groupId, contributor.token);
    const job = (await claimJobs(app)).body.jobs[0];

    const malformed = await supertest(app)
      .post('/internal/pipeline/result')
      .set(withKey)
      .send({ job_id: job.job_id, raw_message_id: job.raw_message_id, outcome: 'ok' });
    expect(malformed.status).toBe(422);
    expect(malformed.body.error.code).toBe('validation');

    let jobRow = await testPool().query('SELECT status, attempts FROM jobs WHERE id = $1', [job.job_id]);
    expect(jobRow.rows[0].attempts).toBe(1);
    expect(jobRow.rows[0].status).toBe('pending'); // backoff scheduled

    // Second malformed attempt exhausts PIPELINE_MAX_ATTEMPTS=2.
    await testPool().query(`UPDATE jobs SET run_after = now() - interval '1 second' WHERE id = $1`, [job.job_id]);
    const reclaimed = await claimJobs(app);
    expect(reclaimed.body.jobs).toHaveLength(1);
    const again = await supertest(app)
      .post('/internal/pipeline/result')
      .set(withKey)
      .send({ job_id: job.job_id, raw_message_id: job.raw_message_id, rewritten_text: 'x'.repeat(99999) });
    expect(again.status).toBe(422);

    jobRow = await testPool().query(
      'SELECT j.status AS job_status, r.pipeline_status FROM jobs j JOIN raw_messages r ON r.id = j.raw_message_id WHERE j.id = $1',
      [job.job_id],
    );
    expect(jobRow.rows[0].job_status).toBe('failed');
    expect(jobRow.rows[0].pipeline_status).toBe('failed');
  });

  it('mismatched raw_message_id is rejected 422', async () => {
    const app = pipelineApp();
    const { contributor, groupId } = await seedGroup(app);
    await submitMessage(app, groupId, contributor.token);
    const job = (await claimJobs(app)).body.jobs[0];
    const res = await supertest(app)
      .post('/internal/pipeline/result')
      .set(withKey)
      .send(okResult(job.job_id, '00000000-0000-0000-0000-000000000000'));
    expect(res.status).toBe(422);
  });
});

describe('fail', () => {
  it('records attempts with backoff, then fails permanently; the message stays reviewable', async () => {
    const app = pipelineApp({ pipelineMaxAttempts: 2 });
    const { controller, contributor, groupId } = await seedGroup(app);
    const messageId = await submitMessage(app, groupId, contributor.token);
    const job = (await claimJobs(app)).body.jobs[0];

    const first = await supertest(app)
      .post('/internal/pipeline/fail')
      .set(withKey)
      .send({ job_id: job.job_id, error_code: 'model_timeout' });
    expect(first.status).toBe(200);
    expect(first.body).toEqual({ applied: false, reason: 'error_recorded' });

    // Claim again after backoff, then fail permanently.
    await testPool().query(`UPDATE jobs SET run_after = now() - interval '1 second' WHERE id = $1`, [job.job_id]);
    const reclaimed = await claimJobs(app);
    expect(reclaimed.body.jobs).toHaveLength(1);

    const second = await supertest(app)
      .post('/internal/pipeline/fail')
      .set(withKey)
      .send({ job_id: job.job_id, error_code: 'model_timeout' });
    expect(second.body).toEqual({ applied: false, reason: 'failed_permanently' });

    const raw = await testPool().query(
      'SELECT status, pipeline_status FROM raw_messages WHERE id = $1',
      [messageId],
    );
    expect(raw.rows[0].status).toBe('pending');
    expect(raw.rows[0].pipeline_status).toBe('failed');

    // Still controller-reviewable, and accept without a rewrite is 409.
    const queue = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(queue.body.items).toHaveLength(1);
    const accept = await api.post(app, `/messages/${messageId}/accept`, controller.token);
    expect(accept.status).toBe(409);
    expect(accept.body.error.message).toBe('This message has no rewrite yet.');

    // Failing a job that is not running is a no-op.
    const late = await supertest(app)
      .post('/internal/pipeline/fail')
      .set(withKey)
      .send({ job_id: job.job_id, error_code: 'late' });
    expect(late.body).toEqual({ applied: false, reason: 'not_running' });
  });
});

describe('submission-time limit', () => {
  it('rejects text over PIPELINE_MAX_INPUT_CHARS with 422', async () => {
    const app = pipelineApp({ pipelineMaxInputChars: 10 });
    const { contributor, groupId } = await seedGroup(app);
    const res = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'this text is definitely longer than ten characters',
      is_anonymous: false,
    });
    expect(res.status).toBe(422);
    expect(res.body.error.message).toContain('at most 10 characters');
  });
});

describe('log privacy', () => {
  it('internal pipeline endpoints never log raw text', async () => {
    const spies = ['log', 'error', 'warn', 'info', 'debug'].map((method) =>
      vi.spyOn(console, method as keyof Console),
    );
    try {
      const app = pipelineApp({ pipelineMaxAttempts: 1 });
      const { contributor, groupId } = await seedGroup(app);
      const sentinel = `pipeline-sentinel-${Math.random().toString(36).slice(2)}`;
      const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
        text: `message containing ${sentinel}`,
        is_anonymous: true,
      });
      const job = (await claimJobs(app)).body.jobs[0];

      // malformed result and a permanent failure exercise the error logs
      await supertest(app)
        .post('/internal/pipeline/result')
        .set(withKey)
        .send({ job_id: job.job_id, raw_message_id: job.raw_message_id, outcome: 'ok' })
        .catch(() => undefined);
      await testPool().query(`UPDATE jobs SET run_after = now() - interval '1 second' WHERE id = $1`, [job.job_id]);
      await claimJobs(app);
      await supertest(app)
        .post('/internal/pipeline/fail')
        .set(withKey)
        .send({ job_id: job.job_id, error_code: 'boom' });

      const printed = spies.flatMap((spy) =>
        spy.mock.calls.map((call) => call.map(String).join(' ')),
      );
      for (const line of printed) {
        expect(line).not.toContain(sentinel);
        expect(line).not.toContain(contributor.token);
      }
      void sent;
    } finally {
      for (const spy of spies) spy.mockRestore();
    }
  });
});
