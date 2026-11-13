import crypto from 'node:crypto';
import { Router } from 'express';
import { Pool, PoolClient } from 'pg';
import { z } from 'zod';
import { Config } from '../config';
import { uniqueConstraint, withTransaction } from '../db';
import { ApiError, parseWith, unauthorized } from '../errors';
import { GoogleTokenError, verifyGoogleIdToken } from '../google';
import { endAllSessions, signAccessToken } from '../tokens';
import { baseUsername } from './auth';

/**
 * POST /auth/google (API.md 40) — sign in or sign up with a Google ID
 * token. Returns exactly the login response ({ token, user }).
 *
 * - Known Google account (google_sub): signs in.
 * - Same email as an existing account: links it. Registration never
 *   verified emails, so the first link clears any existing password and
 *   ends every session; otherwise someone who pre-registered this email
 *   with their own password would keep access. The owner can set a new
 *   password with "Forgot?".
 * - New email: creates an account with no password.
 */

const schema = z.object({ id_token: z.string().min(20).max(4096) }).strict();

interface UserRow {
  id: string;
  name: string;
  email: string;
  token_version: number;
}

async function createGoogleUser(client: PoolClient, sub: string, email: string, name: string) {
  const id = crypto.randomUUID();
  const base = baseUsername(email);
  for (let chars = 0; chars <= 32; chars += 4) {
    const username = chars === 0 ? base : `${base}-${id.slice(0, chars)}`;
    await client.query('SAVEPOINT google_user');
    try {
      const { rows } = await client.query<UserRow>(
        `INSERT INTO users (id, email, username, password_hash, name, google_sub)
         VALUES ($1, $2, $3, NULL, $4, $5)
         RETURNING id, name, email, token_version`,
        [id, email, username, name, sub],
      );
      await client.query('RELEASE SAVEPOINT google_user');
      return rows[0];
    } catch (err) {
      await client.query('ROLLBACK TO SAVEPOINT google_user');
      if (uniqueConstraint(err) !== 'users_username_key') throw err;
    }
  }
  throw new ApiError(409, 'username_taken', 'Could not derive a username. Please contact support.');
}

export function createGoogleAuthRouter(pool: Pool, appConfig: Config): Router {
  const router = Router();

  router.post('/google', async (req, res) => {
    const body = parseWith(schema, req.body);
    if (appConfig.googleClientIds.length === 0) {
      throw new ApiError(503, 'google_not_configured', 'Google sign-in is not available yet.');
    }
    let identity;
    try {
      identity = await verifyGoogleIdToken(body.id_token, appConfig.googleClientIds);
    } catch (err) {
      if (err instanceof GoogleTokenError) {
        throw unauthorized('Google sign-in failed. Please try again.');
      }
      throw err;
    }

    const user = await withTransaction(pool, async (client) => {
      const bySub = await client.query<UserRow>(
        'SELECT id, name, email, token_version FROM users WHERE google_sub = $1',
        [identity.sub],
      );
      if (bySub.rows[0]) return bySub.rows[0];

      const byEmail = await client.query<UserRow & { google_sub: string | null }>(
        'SELECT id, name, email, token_version, google_sub FROM users WHERE email = $1 FOR UPDATE',
        [identity.email],
      );
      const existing = byEmail.rows[0];
      if (existing) {
        if (existing.google_sub) {
          // The email belongs to a different Google account already linked.
          throw new ApiError(
            409,
            'google_account_mismatch',
            'This email is linked to a different Google account.',
          );
        }
        await client.query(
          'UPDATE users SET google_sub = $1, password_hash = NULL WHERE id = $2',
          [identity.sub, existing.id],
        );
        await client.query('DELETE FROM password_resets WHERE user_id = $1', [existing.id]);
        const tokenVersion = await endAllSessions(client, existing.id);
        return { ...existing, token_version: tokenVersion };
      }
      return createGoogleUser(client, identity.sub, identity.email, identity.name);
    });

    res.json({
      token: signAccessToken(appConfig, user.id, user.token_version),
      user: { id: user.id, name: user.name, email: user.email },
    });
  });

  return router;
}
