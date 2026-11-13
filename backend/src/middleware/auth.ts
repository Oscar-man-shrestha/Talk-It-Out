import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { Pool } from 'pg';
import { unauthorized } from '../errors';

export function createAuthMiddleware(pool: Pool, jwtSecret: string) {
  return async function requireAuth(
    req: Request,
    _res: Response,
    next: NextFunction,
  ): Promise<void> {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      throw unauthorized();
    }
    const token = header.slice('Bearer '.length).trim();
    let userId: string;
    let tokenVersion: number;
    try {
      // Algorithm pinned to HS256: tokens signed any other way (including
      // alg:none confusion) are rejected outright.
      const payload = jwt.verify(token, jwtSecret, { algorithms: ['HS256'] });
      if (
        typeof payload === 'string' ||
        typeof payload.sub !== 'string' ||
        // Tokens must carry an expiry.
        typeof payload.exp !== 'number'
      ) {
        throw unauthorized();
      }
      userId = payload.sub;
      // Tokens issued before migration 009 carry no tv claim: version 0.
      tokenVersion = typeof payload.tv === 'number' ? payload.tv : 0;
    } catch {
      throw unauthorized();
    }
    // Tokens for users that no longer exist are rejected.
    const { rows } = await pool.query(
      'SELECT id, name, email, username, token_version FROM users WHERE id = $1',
      [userId],
    );
    const user = rows[0];
    // Rejected when the user no longer exists, or every session was ended
    // (sign out everywhere, password change or reset) after this token.
    if (!user || user.token_version !== tokenVersion) {
      throw unauthorized();
    }
    req.user = { id: user.id, name: user.name, email: user.email, username: user.username };
    next();
  };
}

export type RequireAuth = ReturnType<typeof createAuthMiddleware>;
