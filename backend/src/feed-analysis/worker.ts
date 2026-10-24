/**
 * Feed analysis worker — consumes 'analyze_feed_content' outbox jobs.
 *
 * Deliberately separate from the groups stub worker (separate claim
 * queries by job kind, separate loop) so feed/provider problems can never
 * block groups message processing. The job carries only content type, id,
 * and revision; text is read from the database at processing time and sent
 * only to the provider through the versioned internal contract.
 */
import { Pool } from 'pg';
import { withTransaction } from '../db';
import {
  createFakeFeedProvider,
  FeedAnalysisProvider,
  FeedAnalysisRequest,
  feedAnalysisResultSchema,
} from './provider';

export interface FeedWorkerOptions {
  provider?: FeedAnalysisProvider;
  batchSize?: number;
  maxAttempts?: number;
  perCallTimeoutMs?: number;
}

export interface FeedWorkerRunResult {
  claimed: number;
  completed: number;
  unavailable: number;
  discarded: number;
  failed: number;
  retried: number;
}

interface ClaimedFeedJob {
  id: string;
  content_type: 'post' | 'comment';
  content_id: string;
  content_revision: number;
  /** Attempt count including this claim (after the claim's increment). */
  attempts: number;
}

const CONTENT_TABLES = {
  post: 'posts',
  comment: 'comments',
} as const;

async function claimFeedJobs(pool: Pool, batchSize: number): Promise<ClaimedFeedJob[]> {
  return withTransaction(pool, async (client) => {
    const { rows } = await client.query(
      `SELECT id, content_type, content_id, content_revision, attempts
       FROM jobs
       WHERE kind = 'analyze_feed_content' AND status = 'pending' AND run_after <= now()
       ORDER BY created_at
       FOR UPDATE SKIP LOCKED
       LIMIT $1`,
      [batchSize],
    );
    if (rows.length === 0) return [];
    const ids = rows.map((row) => row.id);
    await client.query(
      'UPDATE jobs SET status = $2, attempts = attempts + 1 WHERE id = ANY($1)',
      [ids, 'running'],
    );
    return rows.map((row) => ({ ...row, attempts: row.attempts + 1 }));
  });
}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('provider_timeout')), ms);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (err) => {
        clearTimeout(timer);
        reject(err);
      },
    );
  });
}

async function setContentStatus(
  pool: Pool,
  job: ClaimedFeedJob,
  status: 'complete' | 'failed' | 'unavailable',
  fields?: { nsfw: boolean; flags: Record<string, unknown>; providerVersion: string },
): Promise<boolean> {
  const table = CONTENT_TABLES[job.content_type];
  if (status === 'complete' && fields) {
    // The content_revision guard discards results for content that changed
    // after the job was enqueued (stale results are never applied).
    const { rowCount } = await pool.query(
      `UPDATE ${table}
       SET analysis_status = 'complete', analysis_nsfw = $2,
           analysis_flags = $3::jsonb, analysis_provider_version = $4
       WHERE id = $1 AND content_revision = $5`,
      [job.content_id, fields.nsfw, JSON.stringify(fields.flags), fields.providerVersion, job.content_revision],
    );
    return (rowCount ?? 0) > 0;
  }
  await pool.query(
    `UPDATE ${table} SET analysis_status = $2 WHERE id = $1 AND content_revision = $3`,
    [job.content_id, status, job.content_revision],
  );
  return true;
}

type FeedJobOutcome = 'completed' | 'unavailable' | 'discarded' | 'failed' | 'retried';

async function processFeedJob(
  pool: Pool,
  job: ClaimedFeedJob,
  options: Required<Pick<FeedWorkerOptions, 'maxAttempts' | 'perCallTimeoutMs'>> & {
    provider: FeedAnalysisProvider;
  },
): Promise<FeedJobOutcome> {
  const table = CONTENT_TABLES[job.content_type];
  const { rows } = await pool.query(
    `SELECT content, content_revision FROM ${table} WHERE id = $1`,
    [job.content_id],
  );
  const content = rows[0];
  if (!content) {
    // Content disappeared; nothing to analyze.
    await pool.query(`UPDATE jobs SET status = 'done' WHERE id = $1`, [job.id]);
    return 'discarded';
  }

  const request: FeedAnalysisRequest = {
    request_id: job.id,
    content_type: job.content_type,
    content_id: job.content_id,
    content_revision: job.content_revision,
    text: content.content,
  };

  let raw: unknown;
  try {
    raw = await withTimeout(
      options.provider.analyze(request),
      options.perCallTimeoutMs,
    );
  } catch (err) {
    // Provider threw or timed out: retryable, like outcome 'error'.
    if (job.attempts >= options.maxAttempts) {
      await pool.query(`UPDATE jobs SET status = 'failed' WHERE id = $1`, [job.id]);
      await setContentStatus(pool, job, 'failed');
      return 'failed';
    }
    const backoffSeconds = job.attempts * 2;
    await pool.query(
      `UPDATE jobs SET status = 'pending', run_after = now() + make_interval(secs => $2)
       WHERE id = $1`,
      [job.id, backoffSeconds],
    );
    console.error(
      `[feed-worker] attempt ${job.attempts} for job ${job.id} failed:`,
      err instanceof Error ? `${err.name}: ${err.message}` : err,
    );
    return 'retried';
  }

  const parsed = feedAnalysisResultSchema.safeParse(raw);
  if (!parsed.success) {
    // Contract violation: fail fast, never treat an unusable answer as safe.
    console.error(
      `[feed-worker] provider returned malformed output for job ${job.id} (contract v1)`,
    );
    await pool.query(`UPDATE jobs SET status = 'failed' WHERE id = $1`, [job.id]);
    await setContentStatus(pool, job, 'failed');
    return 'failed';
  }
  const result = parsed.data;

  if (result.outcome === 'error') {
    if (job.attempts >= options.maxAttempts) {
      await pool.query(`UPDATE jobs SET status = 'failed' WHERE id = $1`, [job.id]);
      await setContentStatus(pool, job, 'failed');
      return 'failed';
    }
    const backoffSeconds = job.attempts * 2;
    await pool.query(
      `UPDATE jobs SET status = 'pending', run_after = now() + make_interval(secs => $2)
       WHERE id = $1`,
      [job.id, backoffSeconds],
    );
    return 'retried';
  }

  if (result.outcome === 'unavailable') {
    // The provider cannot analyze this content; record it as unavailable
    // (distinct from 'pending' and from 'failed') and finish the job.
    await setContentStatus(pool, job, 'unavailable');
    await pool.query(`UPDATE jobs SET status = 'done' WHERE id = $1`, [job.id]);
    return 'unavailable';
  }

  // outcome 'ok': discard anything not matching the enqueued revision.
  if (result.content_revision !== job.content_revision) {
    await pool.query(`UPDATE jobs SET status = 'done' WHERE id = $1`, [job.id]);
    return 'discarded';
  }
  const applied = await setContentStatus(pool, job, 'complete', {
    nsfw: result.nsfw === true,
    flags: result.flags ?? {},
    providerVersion: result.provider_version ?? 'unknown',
  });
  await pool.query(`UPDATE jobs SET status = 'done' WHERE id = $1`, [job.id]);
  // applied=false means the row moved past this job's revision while the
  // provider was working: the result is stale and stays discarded.
  return applied ? 'completed' : 'discarded';
}

/** Claims due feed-analysis jobs once and processes them. Safe to re-run. */
export async function runFeedWorkerOnce(
  pool: Pool,
  options: FeedWorkerOptions = {},
): Promise<FeedWorkerRunResult> {
  const provider = options.provider ?? createFakeFeedProvider();
  const result: FeedWorkerRunResult = {
    claimed: 0,
    completed: 0,
    unavailable: 0,
    discarded: 0,
    failed: 0,
    retried: 0,
  };
  const jobs = await claimFeedJobs(pool, options.batchSize ?? 10);
  result.claimed = jobs.length;
  for (const job of jobs) {
    const outcome = await processFeedJob(pool, job, {
      provider,
      maxAttempts: options.maxAttempts ?? 3,
      perCallTimeoutMs: options.perCallTimeoutMs ?? 5000,
    });
    result[outcome] += 1;
  }
  return result;
}

/** Runs the feed worker in-process on an interval (RUN_FEED_WORKER=true). */
export function startFeedWorkerLoop(
  pool: Pool,
  provider: FeedAnalysisProvider,
  intervalMs = 1500,
): () => void {
  const timer = setInterval(() => {
    runFeedWorkerOnce(pool, { provider }).catch((err) => {
      console.error(
        '[feed-worker] run failed:',
        err instanceof Error ? `${err.name}: ${err.message}` : err,
      );
    });
  }, intervalMs);
  if (typeof timer.unref === 'function') timer.unref();
  return () => clearInterval(timer);
}
