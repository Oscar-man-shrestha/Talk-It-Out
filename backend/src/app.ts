import express, { ErrorRequestHandler, Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { ZodError } from 'zod';
import { Pool } from 'pg';
import { Config } from './config';
import { ApiError } from './errors';
import { createApiRouter } from './routes';
import { RealtimeHub } from './realtime';
import { createInternalPipelineRouter } from './internal/pipeline';

/**
 * Every error leaves the API as {"error":{"code","message"}} — including
 * validation errors, unknown routes, and unexpected 500s — because the
 * Flutter client's parser expects that envelope.
 */
const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  if (res.headersSent) return;
  if (err instanceof ApiError) {
    res.status(err.status).json({ error: { code: err.code, message: err.message } });
    return;
  }
  if (err instanceof ZodError) {
    const issue = err.issues[0];
    res.status(422).json({
      error: { code: 'validation', message: issue?.message ?? 'Invalid input.' },
    });
    return;
  }
  const type = (err as { type?: string })?.type;
  if (type === 'entity.parse.failed') {
    res.status(400).json({
      error: { code: 'invalid_json', message: 'The request body is not valid JSON.' },
    });
    return;
  }
  if (type === 'entity.too.large') {
    res.status(413).json({
      error: {
        code: 'body_too_large',
        message: 'The request body is too large.',
      },
    });
    return;
  }
  // Never log request bodies; log only the failing method, path, and error.
  console.error(
    `[error] ${req.method} ${req.path} ->`,
    err instanceof Error ? `${err.name}: ${err.message}` : err,
    (err instanceof Error && process.env.LOG_ERROR_STACKS === '1') ? err.stack : undefined,
  );
  res.status(500).json({
    error: { code: 'internal_error', message: 'Something went wrong. Please try again.' },
  });
};

const rateLimited = (retryAfterSeconds: number) => (
  req: Request,
  res: Response,
): void => {
  res.set('Retry-After', String(retryAfterSeconds));
  res.status(429).json({
    error: {
      code: 'rate_limited',
      message: 'Too many requests. Please try again later.',
    },
  });
};

export function buildApp(pool: Pool, appConfig: Config): Express {
  const app = express();
  app.disable('x-powered-by');
  if (appConfig.trustProxy !== '') {
    app.set('trust proxy', appConfig.trustProxy === 'true' ? 1 : appConfig.trustProxy);
  }
  app.use(helmet());
  app.use(express.json({ limit: appConfig.jsonBodyLimit }));

  app.use(
    cors({
      origin: appConfig.corsOrigins === '*' ? true : appConfig.corsOrigins,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Authorization', 'Content-Type'],
    }),
  );

  // Rate limiters use the default in-memory store: they are per-process.
  // If the API ever runs on more than one instance, switch to a shared
  // store such as Redis, or limits are enforced per instance only.
  const globalLimiter = rateLimit({
    windowMs: 60_000,
    limit: appConfig.rateLimitGlobalMax,
    standardHeaders: false,
    handler: rateLimited(60),
  });
  const authLimiter = rateLimit({
    windowMs: 15 * 60_000,
    limit: appConfig.rateLimitAuthMax,
    standardHeaders: false,
    handler: rateLimited(15 * 60),
  });
  const internalLimiter = rateLimit({
    // Generous: a legitimate worker polls claim every ~1.5s and posts one
    // result per job, well under this ceiling.
    windowMs: 60_000,
    limit: appConfig.rateLimitInternalMax,
    standardHeaders: false,
    handler: rateLimited(60),
  });

  // One live-update hub per app; server.ts closes it on shutdown.
  const realtime = new RealtimeHub(pool);
  app.locals.realtime = realtime;
  const api = createApiRouter(pool, appConfig, { authLimiter, realtime });
  // The global limiter covers the public mounts only, never /internal.
  const publicOnly = (req: Request, res: Response, next: express.NextFunction) => {
    if (req.path === '/internal' || req.path.startsWith('/internal/')) {
      next();
      return;
    }
    globalLimiter(req, res, next);
  };
  app.use(publicOnly);
  app.use('/', api);
  app.use('/api/v1', api);

  // Internal pipeline API for the external Python worker. Mounted ONLY
  // here — never under the Flutter-facing paths — and disabled (503)
  // unless PIPELINE_API_KEY is set. See docs/groups-pipeline-contract.md.
  app.use('/internal/pipeline', internalLimiter, createInternalPipelineRouter(pool, appConfig));

  app.use((req: Request, res: Response) => {
    res
      .status(404)
      .json({ error: { code: 'not_found', message: 'We could not find that.' } });
  });
  app.use(errorHandler);

  return app;
}
