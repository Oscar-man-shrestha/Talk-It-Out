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
  jwtExpiresIn: string;
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
  /** express.json() limit, e.g. '100kb'. */
  jsonBodyLimit: string;
  /** Requests per minute per IP for the public API. */
  rateLimitGlobalMax: number;
  /** Login/register attempts per 15 minutes per IP. */
  rateLimitAuthMax: number;
  /** Internal pipeline requests per minute per IP. */
  rateLimitInternalMax: number;
  /** '' disables trust proxy; 'true' trusts one hop; a number trusts N hops. */
  trustProxy: '' | 'true' | number;
  pgPoolMax: number;
  pgIdleTimeoutMillis: number;
  pgStatementTimeoutMillis: number;
  pgConnectionTimeoutMillis: number;
  /**
   * How password-reset emails are sent: 'disabled' (reset returns 503),
   * 'smtp' (SMTP_URL, any provider), 'log' (prints to the console; refused
   * in production), or 'memory' (tests only).
   */
  mailTransport: 'disabled' | 'smtp' | 'log' | 'memory';
  /** e.g. smtps://user:pass@smtp.example.com:465 (takes precedence). */
  smtpUrl: string;
  /** Alternative to SMTP_URL, e.g. smtp.gmail.com / 465 / you@gmail.com. */
  smtpHost: string;
  smtpPort: number;
  smtpUser: string;
  /** Spaces are removed (Gmail shows app passwords in groups of four). */
  smtpPass: string;
  mailFrom: string;
  /** OAuth client ids whose Google ID tokens are accepted (GOOGLE_CLIENT_ID, comma-separated). */
  googleClientIds: string[];
}

function parseMailTransport(env: NodeJS.ProcessEnv): Config['mailTransport'] {
  const raw = (env.MAIL_TRANSPORT ?? '').trim().toLowerCase();
  if (raw === '' || raw === 'disabled') return 'disabled';
  if (raw !== 'smtp' && raw !== 'log' && raw !== 'memory') {
    throw new Error('MAIL_TRANSPORT must be disabled, smtp, or log.');
  }
  if (raw === 'log' && env.NODE_ENV === 'production') {
    throw new Error('MAIL_TRANSPORT=log prints reset codes; it is not allowed in production.');
  }
  if (raw === 'memory' && env.NODE_ENV === 'production') {
    throw new Error('MAIL_TRANSPORT=memory is for tests only.');
  }
  const hasUrl = (env.SMTP_URL ?? '').trim() !== '';
  const hasParts = ['SMTP_HOST', 'SMTP_USER', 'SMTP_PASS'].every(
    (name) => (env[name] ?? '').trim() !== '',
  );
  if (raw === 'smtp' && !hasUrl && !hasParts) {
    throw new Error('MAIL_TRANSPORT=smtp needs SMTP_URL, or SMTP_HOST, SMTP_USER and SMTP_PASS.');
  }
  return raw;
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

function parseTrustProxy(raw: string | undefined): '' | 'true' | number {
  const value = (raw ?? '').trim();
  if (value === '' || value === 'false' || value === '0') return '';
  if (value === 'true') return 'true';
  const hops = Number.parseInt(value, 10);
  return Number.isFinite(hops) && hops > 0 ? hops : '';
}

/**
 * Startup-time secret hygiene (skipped under NODE_ENV=test):
 * - JWT_SECRET must be set, at least 32 characters, and not the
 *   .env.example placeholder (values starting with '<').
 * - PIPELINE_API_KEY, when set, must pass the same two checks.
 */
export function validateSecrets(env: NodeJS.ProcessEnv): void {
  if (env.NODE_ENV === 'test') return;
  const check = (name: string, value: string | undefined, required: boolean) => {
    const v = (value ?? '').trim();
    if (v === '') {
      if (required) {
        throw new Error(`${name} must be set (see backend/.env.example).`);
      }
      return;
    }
    if (v.startsWith('<')) {
      throw new Error(
        `${name} still looks like the .env.example placeholder. Generate a real secret.`,
      );
    }
    if (v.length < 32) {
      throw new Error(`${name} must be at least 32 characters.`);
    }
  };
  check('JWT_SECRET', env.JWT_SECRET, true);
  check('PIPELINE_API_KEY', env.PIPELINE_API_KEY, false);
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  validateSecrets(env);
  return {
    databaseUrl:
      env.DATABASE_URL ??
      'postgres://talkitout:talkitout@localhost:5433/talkitout',
    testDatabaseUrl:
      env.TEST_DATABASE_URL ??
      'postgres://talkitout:talkitout@localhost:5433/talkitout_test',
    jwtSecret: env.JWT_SECRET ?? '',
    jwtExpiresIn: env.JWT_EXPIRES_IN ?? '7d',
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
    jsonBodyLimit: env.JSON_BODY_LIMIT ?? '100kb',
    rateLimitGlobalMax: positiveInt(env, 'RATE_LIMIT_GLOBAL', 300),
    rateLimitAuthMax: positiveInt(env, 'RATE_LIMIT_AUTH', 10),
    rateLimitInternalMax: positiveInt(env, 'RATE_LIMIT_INTERNAL', 600),
    trustProxy: parseTrustProxy(env.TRUST_PROXY),
    pgPoolMax: positiveInt(env, 'PG_POOL_MAX', 10),
    pgIdleTimeoutMillis: positiveInt(env, 'PG_IDLE_TIMEOUT_MS', 30000),
    pgStatementTimeoutMillis: positiveInt(env, 'PG_STATEMENT_TIMEOUT_MS', 15000),
    pgConnectionTimeoutMillis: positiveInt(env, 'PG_CONNECT_TIMEOUT_MS', 5000),
    mailTransport: parseMailTransport(env),
    googleClientIds: (env.GOOGLE_CLIENT_ID ?? '')
      .split(',')
      .map((id) => id.trim())
      .filter((id) => id && !id.startsWith('<')),
    smtpUrl: (env.SMTP_URL ?? '').trim(),
    smtpHost: (env.SMTP_HOST ?? '').trim(),
    smtpPort: positiveInt(env, 'SMTP_PORT', 465),
    smtpUser: (env.SMTP_USER ?? '').trim(),
    smtpPass: (env.SMTP_PASS ?? '').replace(/\s+/g, ''),
    mailFrom:
      (env.MAIL_FROM ?? '').trim() ||
      ((env.SMTP_USER ?? '').trim()
        ? `Talk It Out <${(env.SMTP_USER ?? '').trim()}>`
        : 'Talk It Out <no-reply@localhost>'),
  };
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

export const config = loadConfig();
