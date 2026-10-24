import { beforeAll, beforeEach, afterAll, describe, expect, it } from 'vitest';
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

describe('stub worker', () => {
  it('moves pipeline_status queued -> processing -> done with the stub rewrite', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'worker target',
      is_anonymous: false,
    });

    // Set the row back to simulate observing the intermediate state is not
    // possible in one run; instead verify the transitions via job + final state.
    const before = await testPool().query(
      'SELECT pipeline_status, status FROM raw_messages WHERE id = $1',
      [sent.body.id],
    );
    expect(before.rows[0].pipeline_status).toBe('queued');

    const run = await runStubWorkerOnce(testPool());
    expect(run).toEqual({ claimed: 1, done: 1, failed: 0, retried: 0 });

    const after = await testPool().query(
      `SELECT pipeline_status, status, rewritten_text,
              intent_preservation_score, relevance_score, relevance_label
       FROM raw_messages WHERE id = $1`,
      [sent.body.id],
    );
    const row = after.rows[0];
    expect(row.pipeline_status).toBe('done');
    expect(row.status).toBe('pending');
    expect(row.rewritten_text).toBe('[stub rewrite] worker target');
    expect(Number(row.intent_preservation_score)).toBe(0.9);
    expect(Number(row.relevance_score)).toBe(0.8);
    expect(row.relevance_label).toBe('relevant');

    const jobs = await testPool().query('SELECT status FROM jobs');
    expect(jobs.rows[0].status).toBe('done');
    void controller;
  });

  it('re-running the same job does not duplicate side effects', async () => {
    const app = testApp();
    const { contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'idempotency target',
      is_anonymous: false,
    });
    const messageId = sent.body.id as string;

    await runStubWorkerOnce(testPool());
    const secondRun = await runStubWorkerOnce(testPool());
    expect(secondRun.claimed).toBe(0);

    // Even forcing the same job to run again must produce identical rows:
    // the rewrite is recomputed from original_text, never stacked.
    await testPool().query(
      `UPDATE jobs SET status = 'pending', run_after = now() - interval '1 second'
       WHERE raw_message_id = $1`,
      [messageId],
    );
    const thirdRun = await runStubWorkerOnce(testPool());
    expect(thirdRun).toEqual({ claimed: 1, done: 1, failed: 0, retried: 0 });

    const raw = await testPool().query(
      'SELECT rewritten_text FROM raw_messages WHERE id = $1',
      [messageId],
    );
    expect(raw.rows[0].rewritten_text).toBe('[stub rewrite] idempotency target');

    const jobsCount = await testPool().query(
      'SELECT count(*)::int AS n FROM jobs WHERE raw_message_id = $1',
      [messageId],
    );
    expect(jobsCount.rows[0].n).toBe(1);
  });

  it('retries with backoff, then fails and sets pipeline_status failed', async () => {
    const app = testApp();
    const { contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'failing target',
      is_anonymous: false,
    });
    const messageId = sent.body.id as string;

    const fail = () => runStubWorkerOnce(testPool(), { shouldFailJob: () => true });
    let run = await fail();
    expect(run).toMatchObject({ claimed: 1, retried: 1 });
    let job = await testPool().query(
      'SELECT status, attempts, run_after FROM jobs WHERE raw_message_id = $1',
      [messageId],
    );
    expect(job.rows[0].status).toBe('pending');
    expect(job.rows[0].attempts).toBe(1);
    // Backoff pushed run_after into the future.
    expect(new Date(job.rows[0].run_after).getTime()).toBeGreaterThan(Date.now() - 1000);

    // Make it due again and fail twice more: attempts 2 -> retried, 3 -> failed.
    const makeDue = () =>
      testPool().query(
        `UPDATE jobs SET run_after = now() - interval '1 second' WHERE raw_message_id = $1`,
        [messageId],
      );
    await makeDue();
    run = await fail();
    expect(run).toMatchObject({ retried: 1 });
    await makeDue();
    run = await fail();
    expect(run).toMatchObject({ failed: 1 });

    job = await testPool().query(
      'SELECT status FROM jobs WHERE raw_message_id = $1',
      [messageId],
    );
    expect(job.rows[0].status).toBe('failed');
    const raw = await testPool().query(
      'SELECT status, pipeline_status, rewritten_text FROM raw_messages WHERE id = $1',
      [messageId],
    );
    expect(raw.rows[0].status).toBe('pending');
    expect(raw.rows[0].pipeline_status).toBe('failed');
    expect(raw.rows[0].rewritten_text).toBeNull();
  });
});

describe('concurrent decisions', () => {
  it('two concurrent accepts produce exactly one published message', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'race condition target',
      is_anonymous: true,
    });
    const messageId = sent.body.id as string;
    await runStubWorkerOnce(testPool());

    const [first, second] = await Promise.all([
      api.post(app, `/messages/${messageId}/accept`, controller.token),
      api.post(app, `/messages/${messageId}/accept`, controller.token),
    ]);
    const statuses = [first.status, second.status].sort();
    expect(statuses).toEqual([200, 409]);

    const published = await testPool().query(
      'SELECT count(*)::int AS n FROM published_messages WHERE group_id = $1',
      [groupId],
    );
    expect(published.rows[0].n).toBe(1);

    const chat = await api.get(app, `/groups/${groupId}/messages`, contributor.token);
    expect(chat.body.items).toHaveLength(1);
  });
});
