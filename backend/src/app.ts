import express, { ErrorRequestHandler, Express, Request, Response } from 'express';
import cors from 'cors';
import { ZodError } from 'zod';
import { Pool } from 'pg';
import { Config } from './config';
import { ApiError } from './errors';
import { createApiRouter } from './routes';
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
  if ((err as { type?: string })?.type === 'entity.parse.failed') {
    res.status(400).json({
      error: { code: 'invalid_json', message: 'The request body is not valid JSON.' },
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

export function buildApp(pool: Pool, appConfig: Config): Express {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '1mb' }));
  app.use(
    cors({
      origin: appConfig.corsOrigins === '*' ? true : appConfig.corsOrigins,
      methods: ['GET', 'POST', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Authorization', 'Content-Type'],
    }),
  );

  const api = createApiRouter(pool, appConfig);
  app.use('/', api);
  app.use('/api/v1', api);

  // Internal pipeline API for the external Python worker. Mounted ONLY
  // here — never under the Flutter-facing paths — and disabled (503)
  // unless PIPELINE_API_KEY is set. See docs/groups-pipeline-contract.md.
  app.use('/internal/pipeline', createInternalPipelineRouter(pool, appConfig));

  app.use((req: Request, res: Response) => {
    res
      .status(404)
      .json({ error: { code: 'not_found', message: 'We could not find that.' } });
  });
  app.use(errorHandler);

  return app;
}
