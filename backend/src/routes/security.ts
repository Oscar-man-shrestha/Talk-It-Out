import argon2 from 'argon2';
import { Router } from 'express';
import { Pool } from 'pg';
import { z } from 'zod';
import { Config } from '../config';
import { withTransaction } from '../db';
import { ApiError, parseWith } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { endAllSessions, signAccessToken } from '../tokens';

/**
 * Account security (API.md 39):
 * - POST /auth/change-password: verifies the current password, sets a new
 *   one, ends every other session, and returns a fresh access token so
 *   this device stays signed in.
 * - POST /auth/logout-all: ends every session, including this one.
 */

const changePasswordSchema = z
  .object({
    current_password: z.string().min(1, 'Enter your current password.').max(128),
    new_password: z
      .string()
      .min(8, 'Password must be at least 8 characters.')
      .max(128, 'Password must be at most 128 characters.'),
  })
  .strict();

export function createSecurityRouter(
  pool: Pool,
  requireAuth: RequireAuth,
  appConfig: Config,
): Router {
  const router = Router();

  router.post('/change-password', requireAuth, async (req, res) => {
    const body = parseWith(changePasswordSchema, req.body);
    const userId = req.user!.id;
    const { rows } = await pool.query<{ password_hash: string | null }>(
      'SELECT password_hash FROM users WHERE id = $1',
      [userId],
    );
    const hash = rows[0]?.password_hash;
    if (!hash) {
      // Accounts created with Google sign-in have no password yet.
      throw new ApiError(
        409,
        'no_password',
        'This account has no password yet. Use "Forgot?" on the login screen to set one.',
      );
    }
    if (!(await argon2.verify(hash, body.current_password))) {
      // 403, not 401, so the client does not treat a typo as a sign-out.
      throw new ApiError(403, 'wrong_password', 'That password is not correct.');
    }
    if (body.new_password === body.current_password) {
      throw new ApiError(422, 'validation', 'Choose a password you have not used here.');
    }
    const passwordHash = await argon2.hash(body.new_password);
    const tokenVersion = await withTransaction(pool, async (client) => {
      await client.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
        passwordHash,
        userId,
      ]);
      await client.query('DELETE FROM password_resets WHERE user_id = $1', [userId]);
      return endAllSessions(client, userId);
    });
    res.json({ token: signAccessToken(appConfig, userId, tokenVersion) });
  });

  router.post('/logout-all', requireAuth, async (req, res) => {
    await endAllSessions(pool, req.user!.id);
    res.status(204).end();
  });

  return router;
}
