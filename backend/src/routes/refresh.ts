import crypto from 'node:crypto';
import { Router } from 'express';
import jwt from 'jsonwebtoken';
import { Pool } from 'pg';
import { z } from 'zod';
import { Config } from '../config';
import { parseWith, unauthorized } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { withTransaction } from '../db';

/**
 * Rotating refresh tokens (PLAN.md task 1.2).
 *
 * Login and register keep their exact {token, user} response, which the
 * Flutter client's model depends on. A client that wants long sessions
 * asks for a refresh token separately with its access token, then swaps
 * it at /auth/refresh. Each refresh rotates the token; presenting a token
 * that was already rotated or revoked revokes its whole family (stolen
 * token reuse detection). Only SHA-256 hashes are stored.
 */

export const REFRESH_TOKEN_TTL_DAYS = 30;

const refreshSchema = z
  .object({ refresh_token: z.string().min(20, 'Send a refresh token.').max(200) })
  .strict();

function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function newRawToken(): string {
  return crypto.randomBytes(32).toString('base64url');
}

async function issueRefreshToken(
  client: Pool | import('pg').PoolClient,
  userId: string,
  familyId: string,
): Promise<{ id: string; token: string; expiresAt: Date }> {
  const token = newRawToken();
  const { rows } = await client.query(
    `INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at)
     VALUES ($1, $2, $3, now() + make_interval(days => $4))
     RETURNING id, expires_at`,
    [userId, familyId, hashToken(token), REFRESH_TOKEN_TTL_DAYS],
  );
  return { id: rows[0].id, token, expiresAt: rows[0].expires_at };
}

export function createRefreshRouter(
  pool: Pool,
  jwtSecret: string,
  requireAuth: RequireAuth,
  appConfig: Config,
): Router {
  const router = Router();

  // Issue a refresh token for the current (access-token) session.
  router.post('/refresh-tokens', requireAuth, async (req, res) => {
    const issued = await issueRefreshToken(pool, req.user!.id, crypto.randomUUID());
    res.status(201).json({
      refresh_token: issued.token,
      expires_at: issued.expiresAt.toISOString(),
    });
  });

  // Revoke every refresh token the caller holds (sign out everywhere).
  router.delete('/refresh-tokens', requireAuth, async (req, res) => {
    await pool.query(
      'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
      [req.user!.id],
    );
    res.status(204).end();
  });

  // Exchange a refresh token for a new access token + rotated refresh token.
  router.post('/refresh', async (req, res) => {
    const body = parseWith(refreshSchema, req.body);
    const result = await withTransaction(pool, async (client) => {
      const { rows } = await client.query(
        `SELECT id, user_id, family_id, expires_at, revoked_at
         FROM refresh_tokens WHERE token_hash = $1 FOR UPDATE`,
        [hashToken(body.refresh_token)],
      );
      const row = rows[0];
      if (!row) return null;
      if (row.revoked_at) {
        // Reuse of a rotated/revoked token: burn the whole family.
        await client.query(
          'UPDATE refresh_tokens SET revoked_at = now() WHERE family_id = $1 AND revoked_at IS NULL',
          [row.family_id],
        );
        return 'reused' as const;
      }
      if (row.expires_at.getTime() <= Date.now()) return null;
      const { rows: user } = await client.query('SELECT id FROM users WHERE id = $1', [
        row.user_id,
      ]);
      if (!user[0]) return null;
      const next = await issueRefreshToken(client, row.user_id, row.family_id);
      await client.query(
        'UPDATE refresh_tokens SET revoked_at = now(), replaced_by = $2 WHERE id = $1',
        [row.id, next.id],
      );
      return { userId: row.user_id as string, next };
    });
    // The family revocation above must commit, so throw only afterwards.
    if (result === null || result === 'reused') throw unauthorized();
    const token = jwt.sign({}, jwtSecret, {
      subject: result.userId,
      expiresIn: appConfig.jwtExpiresIn as jwt.SignOptions['expiresIn'],
      algorithm: 'HS256',
    });
    res.json({
      token,
      refresh_token: result.next.token,
      expires_at: result.next.expiresAt.toISOString(),
    });
  });

  return router;
}
