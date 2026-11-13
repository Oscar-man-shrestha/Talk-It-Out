import { createAccountRouter } from './account';
import { Router, RequestHandler } from 'express';
import { Pool } from 'pg';
import { Config } from '../config';
import { createAuthMiddleware } from '../middleware/auth';
import { createAuthRouter, createMeHandler } from './auth';
import { createFeedRouter } from './feed';
import { createGroupsRouter } from './groups';
import { createMessagesRouter } from './messages';
import { createNotificationsRouter } from './notifications';
import { createPasswordResetRouter } from './passwordReset';
import { createSecurityRouter } from './security';
import { createMediaRouter, createProfilesRouter } from './profiles';
import { createNotificationsReadAllRouter, createReactionsRouter } from './reactions';
import { createRefreshRouter } from './refresh';
import '../types';

/**
 * The full API router. It is mounted at both / and /api/v1 so the Flutter
 * app works with the default base URL http://localhost:3000 and with the
 * documented http://localhost:3000/api/v1.
 */
export function createApiRouter(
  pool: Pool,
  appConfig: Config,
  opts: { authLimiter?: RequestHandler } = {},
): Router {
  const router = Router();
  const requireAuth = createAuthMiddleware(pool, appConfig.jwtSecret);

  // Strict per-IP limit on credential endpoints (15-minute window).
  if (opts.authLimiter) {
    router.use(
      [
        '/auth/login',
        '/auth/register',
        '/auth/refresh',
        '/auth/password-reset',
        '/auth/password-reset/confirm',
        '/auth/change-password',
      ],
      opts.authLimiter,
    );
  }

  // Cheap and public; never touches the database.
  router.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  // Readiness: one trivial query; 503 envelope when the database is down.
  // Reports no internals beyond up/down.
  router.get('/ready', async (_req, res) => {
    try {
      await pool.query('SELECT 1');
      res.json({ status: 'ready' });
    } catch {
      res.status(503).json({
        error: { code: 'not_ready', message: 'The service is not ready.' },
      });
    }
  });

  router.use('/auth', createAuthRouter(pool, appConfig.jwtSecret, requireAuth, appConfig));
  router.get('/me', requireAuth, createMeHandler());
  router.use(
    '/groups',
    createGroupsRouter(pool, requireAuth, appConfig.pipelineMaxInputChars),
  );
  router.use('/messages', createMessagesRouter(pool, requireAuth));
  router.use('/posts', createFeedRouter(pool, requireAuth));
  router.use('/notifications', createNotificationsRouter(pool, requireAuth));

  // Additions after the v1 client contract (not yet called by the Flutter
  // app). Mounted after the routers above so they never shadow them.
  router.use('/auth', createRefreshRouter(pool, appConfig.jwtSecret, requireAuth, appConfig));
  router.use('/auth', createPasswordResetRouter(pool, appConfig));
  router.use('/auth', createSecurityRouter(pool, requireAuth, appConfig));
  router.use('/groups', createReactionsRouter(pool, requireAuth));
  router.use('/notifications', createNotificationsReadAllRouter(pool, requireAuth));
  router.use('/users', createProfilesRouter(pool, requireAuth));
  router.use('/users', createAccountRouter(pool, requireAuth));
  router.use('/media', createMediaRouter(pool));

  return router;
}
