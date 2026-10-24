/**
 * STUB WORKER — placeholder for the real Team 1 NLP pipeline.
 *
 * This is clearly NOT NLP: the "rewrite" is a fixed prefix glued onto the
 * original text and the scores are constants. It exists so the moderation
 * flow (submit -> queued -> processing -> done -> controller accepts the
 * rewrite) works end to end before the real pipeline exists. Replace the
 * body of processJob with the real pipeline integration.
 *
 * The worker claims jobs with FOR UPDATE SKIP LOCKED so several processes
 * can run it concurrently, and every update it makes is guarded by
 * `status = 'pending'` so a decision (accept/reject) made while a job is in
 * flight is never overwritten by a late pipeline result.
 */
import { Pool } from 'pg';
import { withTransaction } from '../db';

export interface StubWorkerOptions {
  /** Jobs claimed per run (default 10). */
  batchSize?: number;
  /** Attempts before a job is marked failed (default 3). */
  maxAttempts?: number;
  /** TEST HOOK ONLY: makes the next job processing throw, to exercise retries. */
  shouldFailJob?: () => boolean;
}

export interface StubWorkerRunResult {
  claimed: number;
  done: number;
  failed: number;
  retried: number;
}

interface ClaimedJob {
  id: string;
  raw_message_id: string;
  /** Attempt count including this claim (after the claim's increment). */
  attempts: number;
}

async function claimJobs(
  pool: Pool,
  batchSize: number,
): Promise<ClaimedJob[]> {
  return withTransaction(pool, async (client) => {
    const { rows } = await client.query(
      `SELECT id, raw_message_id, attempts
       FROM jobs
       WHERE kind = 'process_raw_message' AND status = 'pending' AND run_after <= now()
       ORDER BY created_at
       FOR UPDATE SKIP LOCKED
       LIMIT $1`,
      [batchSize],
    );
    if (rows.length === 0) return [];
    const ids = rows.map((row) => row.id);
    await client.query('UPDATE jobs SET status = $2, attempts = attempts + 1 WHERE id = ANY($1)', [
      ids,
      'running',
    ]);
    return rows.map((row) => ({ ...row, attempts: row.attempts + 1 })) as ClaimedJob[];
  });
}

type JobOutcome = 'done' | 'failed' | 'retried';

async function processJob(
  pool: Pool,
  job: ClaimedJob,
  maxAttempts: number,
  options: StubWorkerOptions,
): Promise<JobOutcome> {
  try {
    if (options.shouldFailJob?.()) {
      throw new Error('injected pipeline failure (test hook)');
    }
    // queued -> processing ...
    await pool.query(
      `UPDATE raw_messages SET pipeline_status = 'processing'
       WHERE id = $1 AND status = 'pending' AND pipeline_status = 'queued'`,
      [job.raw_message_id],
    );
    // ... processing -> done, with the stub rewrite result.
    // Recomputed from original_text every time, so re-running the same job
    // writes the same values instead of stacking prefixes.
    const { rowCount } = await pool.query(
      `UPDATE raw_messages
       SET pipeline_status = 'done',
           rewritten_text = '[stub rewrite] ' || original_text,
           intent_preservation_score = 0.9,
           relevance_score = 0.8,
           relevance_label = 'relevant'
       WHERE id = $1 AND status = 'pending'`,
      [job.raw_message_id],
    );
    // rowCount 0 means the message was accepted/rejected before the result
    // landed. The decided message stays exactly as the controller left it.
    void rowCount;
    await pool.query(`UPDATE jobs SET status = 'done' WHERE id = $1`, [job.id]);
    return 'done';
  } catch (err) {
    // Log the error class only; the error cannot contain message text
    // because parameterized SQL never embeds row values.
    console.error(
      '[stub-worker] job error:',
      err instanceof Error ? `${err.name}: ${err.message}` : err,
    );
    if (job.attempts >= maxAttempts) {
      await pool.query(`UPDATE jobs SET status = 'failed' WHERE id = $1`, [job.id]);
      await pool.query(
        `UPDATE raw_messages SET pipeline_status = 'failed'
         WHERE id = $1 AND status = 'pending'`,
        [job.raw_message_id],
      );
      return 'failed';
    }
    const backoffMs = job.attempts * 2000;
    await pool.query(
      `UPDATE jobs SET status = 'pending', run_after = now() + make_interval(secs => $2)
       WHERE id = $1`,
      [job.id, backoffMs / 1000],
    );
    return 'retried';
  }
}

/** Claims due jobs once and processes them. Safe to call repeatedly. */
export async function runStubWorkerOnce(
  pool: Pool,
  options: StubWorkerOptions = {},
): Promise<StubWorkerRunResult> {
  const result: StubWorkerRunResult = { claimed: 0, done: 0, failed: 0, retried: 0 };
  const jobs = await claimJobs(pool, options.batchSize ?? 10);
  result.claimed = jobs.length;
  for (const job of jobs) {
    const outcome = await processJob(pool, job, options.maxAttempts ?? 3, options);
    result[outcome] += 1;
  }
  return result;
}

/** Runs the worker in-process on an interval (RUN_STUB_WORKER=true). */
export function startStubWorkerLoop(pool: Pool, intervalMs = 1500): () => void {
  const timer = setInterval(() => {
    runStubWorkerOnce(pool).catch((err) => {
      console.error(
        '[stub-worker] run failed:',
        err instanceof Error ? `${err.name}: ${err.message}` : err,
      );
    });
  }, intervalMs);
  if (typeof timer.unref === 'function') timer.unref();
  return () => clearInterval(timer);
}
