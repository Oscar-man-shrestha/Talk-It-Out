import { Router } from 'express';
import { Pool } from 'pg';
import { Config } from '../config';
import { createAuthMiddleware } from '../middleware/auth';
import { createAuthRouter, createMeHandler } from './auth';
import { createFeedRouter } from './feed';
import { createGroupsRouter } from './groups';
import { createMessagesRouter } from './messages';
import { createNotificationsRouter } from './notifications';
import '../types';

/**
 * The full API router. It is mounted at both / and /api/v1 so the Flutter
 * app works with the default base URL http://localhost:3000 and with the
 * documented http://localhost:3000/api/v1.
 */
export function createApiRouter(pool: Pool, appConfig: Config): Router {
  const router = Router();
  const requireAuth = createAuthMiddleware(pool, appConfig.jwtSecret);

  router.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  router.use('/auth', createAuthRouter(pool, appConfig.jwtSecret, requireAuth));
  router.get('/me', requireAuth, createMeHandler());
  router.use('/groups', createGroupsRouter(pool, requireAuth));
  router.use('/messages', createMessagesRouter(pool, requireAuth));
  router.use('/posts', createFeedRouter(pool, requireAuth));
  router.use('/notifications', createNotificationsRouter(pool, requireAuth));

  return router;
}
