import path from 'node:path';
import dotenv from 'dotenv';

// backend/.env lives one level above src/ (and above dist/ after a build).
// The package compiles to CommonJS, so __dirname is available under node,
// tsx, and vitest alike.
dotenv.config({ path: path.resolve(__dirname, '..', '.env') });

export interface Config {
  databaseUrl: string;
  testDatabaseUrl: string;
  jwtSecret: string;
  port: number;
  corsOrigins: string[] | '*';
  runStubWorker: boolean;
  feedProvider: string;
  runFeedWorker: boolean;
  /** 'stub' runs the in-process stub; 'external' waits for the Python worker. */
  pipelineMode: 'stub' | 'external';
  /** Shared secret for /internal/pipeline/*; empty string disables the API. */
  pipelineApiKey: string;
  pipelineMaxInputChars: number;
  pipelineMaxOutputChars: number;
  pipelineLeaseSeconds: number;
  pipelineMaxAttempts: number;
}

/**
 * The in-process stub worker must never run in external mode, or it would
 * compete with the external Python worker for the same jobs.
 */
export function stubWorkerShouldRun(config: Config): boolean {
  return config.runStubWorker && config.pipelineMode === 'stub';
}

function positiveInt(env: NodeJS.ProcessEnv, name: string, fallback: number): number {
  const parsed = Number.parseInt(env[name] ?? '', 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export function parseCorsOrigins(raw: string | undefined): string[] | '*' {
  const value = (raw ?? '').trim();
  if (!value || value === '*') return '*';
  const list = value
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  return list.length === 0 ? '*' : list;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const jwtSecret = env.JWT_SECRET ?? '';
  if (!jwtSecret) {
    if (env.NODE_ENV === 'production') {
      throw new Error('JWT_SECRET must be set in production.');
    }
    return makeConfig(env, 'dev-only-insecure-jwt-secret');
  }
  return makeConfig(env, jwtSecret);
}

function makeConfig(env: NodeJS.ProcessEnv, jwtSecret: string): Config {
  return {
    databaseUrl:
      env.DATABASE_URL ??
      'postgres://talkitout:talkitout@localhost:5433/talkitout',
    testDatabaseUrl:
      env.TEST_DATABASE_URL ??
      'postgres://talkitout:talkitout@localhost:5433/talkitout_test',
    jwtSecret,
    port: Number.parseInt(env.PORT ?? '3000', 10) || 3000,
    corsOrigins: parseCorsOrigins(env.CORS_ORIGINS),
    runStubWorker: (env.RUN_STUB_WORKER ?? 'false').toLowerCase() === 'true',
    feedProvider: env.FEED_PROVIDER ?? 'fake',
    runFeedWorker: (env.RUN_FEED_WORKER ?? 'false').toLowerCase() === 'true',
    pipelineMode: env.PIPELINE_MODE === 'external' ? 'external' : 'stub',
    pipelineApiKey: env.PIPELINE_API_KEY ?? '',
    pipelineMaxInputChars: positiveInt(env, 'PIPELINE_MAX_INPUT_CHARS', 5000),
    pipelineMaxOutputChars: positiveInt(env, 'PIPELINE_MAX_OUTPUT_CHARS', 8000),
    pipelineLeaseSeconds: positiveInt(env, 'PIPELINE_LEASE_SECONDS', 300),
    pipelineMaxAttempts: positiveInt(env, 'PIPELINE_MAX_ATTEMPTS', 3),
  };
}

export const config = loadConfig();
