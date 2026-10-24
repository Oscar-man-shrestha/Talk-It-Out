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
  };
}

export const config = loadConfig();
