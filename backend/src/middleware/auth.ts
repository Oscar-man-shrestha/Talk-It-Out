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
    } catch {
      throw unauthorized();
    }
    // Tokens for users that no longer exist are rejected.
    const { rows } = await pool.query(
      'SELECT id, name, email, username FROM users WHERE id = $1',
      [userId],
    );
    const user = rows[0];
    if (!user) {
      throw unauthorized();
    }
    req.user = user;
    next();
  };
}

export type RequireAuth = ReturnType<typeof createAuthMiddleware>;
