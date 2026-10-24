/**
 * Internal groups-pipeline API — the backend side of
 * docs/groups-pipeline-contract.md (contract_version: 1).
 *
 * An external Python worker claims rewrite jobs here and posts results.
 * It never touches the database. This router is mounted ONLY at
 * /internal/pipeline (never at the Flutter-facing / or /api/v1 paths) and
 * is disabled (503) unless PIPELINE_API_KEY is set.
 *
 * The backend contains no NLP logic: results are stored as received after
 * strict validation. The claim payload carries exactly job_id,
 * raw_message_id, text, group_agenda, and contract_version — never sender
 * identity, is_anonymous, other members' data, or credentials.
 */
import crypto from 'node:crypto';
import { NextFunction, Request, Response, Router } from 'express';
import { Pool, PoolClient } from 'pg';
import { z, ZodError } from 'zod';
import { ApiError } from '../errors';
import { Config } from '../config';
import { withTransaction } from '../db';

export const GROUPS_PIPELINE_CONTRACT_VERSION = 1;

/** Failed-attempt backoff: 2s per attempt so far (contract §6). */
const backoffSeconds = (attempts: number) => attempts * 2;

function keysEqualConstantTime(a: string, b: string): boolean {
  // Hash both sides first so timing never leaks the key length.
  const ha = crypto.createHash('sha256').update(a, 'utf8').digest();
  const hb = crypto.createHash('sha256').update(b, 'utf8').digest();
  return crypto.timingSafeEqual(ha, hb);
}

export function createPipelineAuth(appConfig: Config) {
  return async function requirePipelineKey(
    req: Request,
    _res: Response,
    next: NextFunction,
  ): Promise<void> {
    if (!appConfig.pipelineApiKey) {
      throw new ApiError(503, 'internal_api_disabled', 'The internal pipeline API is disabled.');
    }
    const header = req.headers['x-pipeline-key'];
    const provided = Array.isArray(header) ? header[0] : header;
    if (typeof provided !== 'string' || !keysEqualConstantTime(provided, appConfig.pipelineApiKey)) {
      throw new ApiError(401, 'invalid_pipeline_key', 'Invalid pipeline key.');
    }
    next();
  };
}

interface JobRow {
  id: string;
  raw_message_id: string;
  status: string;
  attempts: number;
}

/**
 * Shared terminal/retry logic for failures (contract §4, §6, §7): retries
 * with backoff until PIPELINE_MAX_ATTEMPTS, then the job fails and the
 * message's pipeline_status becomes 'failed' (it stays pending and
 * controller-reviewable).
 */
async function recordFailedAttempt(
  client: PoolClient,
  job: JobRow,
  appConfig: Config,
): Promise<{ applied: boolean; reason: string }> {
  if (job.attempts >= appConfig.pipelineMaxAttempts) {
    await client.query(`UPDATE jobs SET status = 'failed' WHERE id = $1`, [job.id]);
    await client.query(
      `UPDATE raw_messages SET pipeline_status = 'failed'
       WHERE id = $1 AND status = 'pending'`,
      [job.raw_message_id],
    );
    // Log job id + nothing else; never text or identity.
    console.error(`[pipeline] job ${job.id} failed permanently after ${job.attempts} attempts`);
    return { applied: false, reason: 'failed_permanently' };
  }
  await client.query(
    `UPDATE jobs SET status = 'pending', run_after = now() + make_interval(secs => $2)
     WHERE id = $1`,
    [job.id, backoffSeconds(job.attempts)],
  );
  return { applied: false, reason: 'error_recorded' };
}

export function createInternalPipelineRouter(pool: Pool, appConfig: Config): Router {
  const router = Router();
  router.use(createPipelineAuth(appConfig));

  const resultSchema = z
    .object({
      job_id: z.string().min(1),
      raw_message_id: z.string().min(1),
      outcome: z.enum(['ok', 'error']),
      rewritten_text: z.string().min(1).max(appConfig.pipelineMaxOutputChars).optional(),
      intent_preservation_score: z.number().min(0).max(1).optional(),
      relevance_score: z.number().min(0).max(1).optional(),
      relevance_label: z.enum(['relevant', 'borderline', 'off_topic']).optional(),
      pipeline_version: z.string().min(1).max(200).optional(),
      error_code: z.string().min(1).max(100).optional(),
    })
    .superRefine((value, ctx) => {
      if (value.outcome === 'ok') {
        if (value.rewritten_text === undefined) {
          ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['rewritten_text'], message: 'rewritten_text is required when outcome is ok.' });
        }
        if (value.intent_preservation_score === undefined) {
          ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['intent_preservation_score'], message: 'intent_preservation_score is required when outcome is ok.' });
        }
        if (value.relevance_score === undefined) {
          ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['relevance_score'], message: 'relevance_score is required when outcome is ok.' });
        }
        if (value.relevance_label === undefined) {
          ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['relevance_label'], message: 'relevance_label is required when outcome is ok.' });
        }
        if (value.pipeline_version === undefined) {
          ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['pipeline_version'], message: 'pipeline_version is required when outcome is ok.' });
        }
      } else if (value.error_code === undefined) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['error_code'], message: 'error_code is required when outcome is error.' });
      }
    });

  const failSchema = z.object({
    job_id: z.string().min(1),
    error_code: z.string().min(1).max(100).default('worker_error'),
  });

  // POST /internal/pipeline/claim
  router.post('/claim', async (req, res) => {
    const rawMax = (req.body as { max_jobs?: unknown } | undefined)?.max_jobs;
    const parsedMax = Number.parseInt(String(rawMax ?? '5'), 10);
    const maxJobs = Math.min(Math.max(Number.isFinite(parsedMax) ? parsedMax : 5, 1), 10);

    const claimed = await withTransaction(pool, async (client) => {
      // Release jobs whose message was decided while queued: the worker
      // never sees them and they cannot linger as claimable work.
      await client.query(
        `UPDATE jobs SET status = 'done'
         WHERE kind = 'process_raw_message' AND status IN ('pending', 'running')
           AND NOT EXISTS (
             SELECT 1 FROM raw_messages r
             WHERE r.id = jobs.raw_message_id AND r.status = 'pending'
           )`,
      );
      // run_after doubles as the lease: a running job past its lease is
      // claimable again (contract §6). No schema change needed.
      const { rows } = await client.query(
        `SELECT id, raw_message_id
         FROM jobs
         WHERE kind = 'process_raw_message'
           AND ((status = 'pending' AND run_after <= now())
                OR (status = 'running' AND run_after <= now()))
         ORDER BY created_at
         FOR UPDATE SKIP LOCKED
         LIMIT $1`,
        [maxJobs],
      );
      if (rows.length === 0) return [] as JobRow[];
      const ids = rows.map((row) => row.id);
      await client.query(
        `UPDATE jobs SET status = 'running', attempts = attempts + 1,
             run_after = now() + make_interval(secs => $2)
         WHERE id = ANY($1)`,
        [ids, appConfig.pipelineLeaseSeconds],
      );
      return rows as JobRow[];
    });

    if (claimed.length === 0) {
      res.json({ jobs: [] });
      return;
    }
    // Build the worker payload: text + agenda only (contract §2).
    const { rows } = await pool.query(
      `SELECT j.id AS job_id, r.id AS raw_message_id,
              r.original_text AS text, g.agenda AS group_agenda
       FROM jobs j
       JOIN raw_messages r ON r.id = j.raw_message_id
       JOIN groups g ON g.id = r.group_id
       WHERE j.id = ANY($1)`,
      [claimed.map((job) => job.id)],
    );
    const jobs = rows.map((row) => ({
      job_id: row.job_id,
      raw_message_id: row.raw_message_id,
      text: row.text,
      group_agenda: row.group_agenda,
      contract_version: GROUPS_PIPELINE_CONTRACT_VERSION,
    }));
    res.json({ jobs });
  });

  // POST /internal/pipeline/result
  router.post('/result', async (req, res) => {
    let parsed: z.infer<typeof resultSchema>;
    try {
      parsed = resultSchema.parse(req.body);
    } catch (err) {
      // An invalid result counts as a failed attempt when the job is
      // identifiable (contract §3).
      if (err instanceof ZodError) {
        const jobId = (req.body as { job_id?: unknown })?.job_id;
        if (typeof jobId === 'string' && jobId.length > 0) {
          await withTransaction(pool, async (client) => {
            const { rows } = await client.query(
              `SELECT id, raw_message_id, status, attempts FROM jobs
               WHERE id = $1 AND kind = 'process_raw_message' FOR UPDATE`,
              [jobId],
            );
            const job = rows[0] as JobRow | undefined;
            if (job && job.status !== 'done' && job.status !== 'failed') {
              await recordFailedAttempt(client, job, appConfig);
            }
          });
          console.error(`[pipeline] invalid result rejected for job ${jobId}`);
        }
        const issue = err.issues[0];
        throw new ApiError(
          422,
          'validation',
          `${issue?.message ?? 'Invalid result.'}${issue?.path?.length ? ` (${issue.path.join('.')})` : ''}`,
        );
      }
      throw err;
    }

    const outcome = await withTransaction(pool, async (client) => {
      const { rows } = await client.query(
        `SELECT id, raw_message_id, status, attempts FROM jobs
         WHERE id = $1 AND kind = 'process_raw_message' FOR UPDATE`,
        [parsed.job_id],
      );
      const job = rows[0] as JobRow | undefined;
      if (!job) return { applied: false, reason: 'unknown_job' };
      if (job.status === 'done') return { applied: false, reason: 'already_done' };
      if (job.status === 'failed') return { applied: false, reason: 'failed_permanently' };

      if (parsed.raw_message_id !== job.raw_message_id) {
        throw new ApiError(422, 'validation', 'raw_message_id does not match the job.');
      }

      const { rows: rawRows } = await client.query(
        'SELECT id, status FROM raw_messages WHERE id = $1 FOR UPDATE',
        [job.raw_message_id],
      );
      const raw = rawRows[0];
      if (!raw || raw.status !== 'pending') {
        // Decided while the pipeline ran: the decision wins (contract §5).
        await client.query(`UPDATE jobs SET status = 'done' WHERE id = $1`, [job.id]);
        return { applied: false, reason: 'message_decided' };
      }

      if (parsed.outcome === 'error') {
        return recordFailedAttempt(client, job, appConfig);
      }

      await client.query(
        `UPDATE raw_messages
         SET pipeline_status = 'done', rewritten_text = $2,
             intent_preservation_score = $3, relevance_score = $4,
             relevance_label = $5
         WHERE id = $1 AND status = 'pending'`,
        [
          job.raw_message_id,
          parsed.rewritten_text,
          parsed.intent_preservation_score,
          parsed.relevance_score,
          parsed.relevance_label,
        ],
      );
      await client.query(`UPDATE jobs SET status = 'done' WHERE id = $1`, [job.id]);
      return { applied: true as const };
    });
    res.json(outcome);
  });

  // POST /internal/pipeline/fail
  router.post('/fail', async (req, res) => {
    const parsed = failSchema.parse(req.body);
    const outcome = await withTransaction(pool, async (client) => {
      const { rows } = await client.query(
        `SELECT id, raw_message_id, status, attempts FROM jobs
         WHERE id = $1 AND kind = 'process_raw_message' FOR UPDATE`,
        [parsed.job_id],
      );
      const job = rows[0] as JobRow | undefined;
      if (!job) return { applied: false, reason: 'unknown_job' };
      if (job.status !== 'running') return { applied: false, reason: 'not_running' };
      return recordFailedAttempt(client, job, appConfig);
    });
    res.json(outcome);
  });

  return router;
}
