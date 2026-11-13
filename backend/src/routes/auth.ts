import crypto from 'node:crypto';
import { Router } from 'express';
import argon2 from 'argon2';
import { Pool } from 'pg';
import { z } from 'zod';
import { ApiError, conflict, parseWith, unauthorized } from '../errors';
import { Config } from '../config';
import { uniqueConstraint } from '../db';
import { RequireAuth } from '../middleware/auth';
import { signAccessToken } from '../tokens';

const registerSchema = z.object({
  name: z
    .string()
    .trim()
    .min(1, 'Enter your name.')
    .max(200, 'Name is too long.'),
  email: z
    .string()
    .trim()
    .toLowerCase()
    .email('Enter a valid email address.'),
  password: z
    .string()
    .min(8, 'Password must be at least 8 characters.')
    .max(128, 'Password must be at most 128 characters.'),
});

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email('Enter a valid email address.'),
  password: z.string().min(1, 'Enter your password.').max(128),
});

/**
 * Username is derived at registration: the lowercased email local-part
 * restricted to [a-z0-9._-]. On collision, "-" plus the first 4 hex chars of
 * the new user id are appended (more hex chars only in the extreme case where
 * even that collides). The client never sends or receives the username.
 */
export function baseUsername(email: string): string {
  const local = email.split('@')[0].toLowerCase();
  const cleaned = local.replace(/[^a-z0-9._-]/g, '');
  return cleaned.length > 0 ? cleaned : 'user';
}

function sessionJson(token: string, user: { id: string; name: string; email: string }) {
  return {
    token,
    user: { id: user.id, name: user.name, email: user.email },
  };
}

// Comparable timing for unknown emails: verify the submitted password
// against this dummy hash so a missing account costs an argon2 pass too.
const DUMMY_HASH =
  '$argon2id$v=19$m=65536,t=3,p=4$c29tZXNhbHQ' +
  '$RdescudvJCsgt3ub+b+dWRWJTmaaJObG';

/**
 * Per-account login throttling: 5 consecutive failed logins for one email
 * within 15 minutes locks that email (429) regardless of source IP; a
 * successful login resets it. In-memory and per-process: with multiple API
 * instances the counter is not shared and resets on restart — a production
 * multi-instance deployment needs a shared store.
 */
const LOGIN_FAILURE_WINDOW_MS = 15 * 60_000;
const LOGIN_FAILURE_LIMIT = 5;

const loginFailures = new Map<string, { count: number; windowStartedAt: number }>();

export function resetLoginThrottle(): void {
  loginFailures.clear();
}

function loginThrottleRemainingMs(email: string): number {
  const entry = loginFailures.get(email);
  if (!entry) return 0;
  const elapsed = Date.now() - entry.windowStartedAt;
  if (entry.count < LOGIN_FAILURE_LIMIT || elapsed >= LOGIN_FAILURE_WINDOW_MS) return 0;
  return LOGIN_FAILURE_WINDOW_MS - elapsed;
}

function recordLoginFailure(email: string): void {
  const now = Date.now();
  const entry = loginFailures.get(email);
  if (!entry || now - entry.windowStartedAt >= LOGIN_FAILURE_WINDOW_MS) {
    loginFailures.set(email, { count: 1, windowStartedAt: now });
    return;
  }
  entry.count += 1;
}

function clearLoginFailures(email: string): void {
  loginFailures.delete(email);
}

export function createAuthRouter(
  pool: Pool,
  jwtSecret: string,
  requireAuth: RequireAuth,
  appConfig: Config,
): Router {
  const router = Router();

  router.post('/register', async (req, res) => {
    const body = parseWith(registerSchema, req.body);
    const id = crypto.randomUUID();
    const passwordHash = await argon2.hash(body.password);
    const base = baseUsername(body.email);

    let inserted: { id: string; name: string; email: string } | undefined;
    // chars = 0 -> bare local-part; 4 -> spec's "-<first 4 hex of id>";
    // longer suffixes only if even that collided.
    for (let chars = 0; chars <= 32 && !inserted; chars += 4) {
      const username = chars === 0 ? base : `${base}-${id.slice(0, chars)}`;
      try {
        const { rows } = await pool.query(
          `INSERT INTO users (id, email, username, password_hash, name)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING id, name, email`,
          [id, body.email, username, passwordHash, body.name],
        );
        inserted = rows[0];
      } catch (err) {
        const constraint = uniqueConstraint(err);
        if (constraint === 'users_email_key') {
          throw conflict('email_taken', 'That email is already registered.');
        }
        if (constraint !== 'users_username_key') throw err;
        // Username collision: retry with a longer id suffix.
      }
    }
    if (!inserted) {
      throw conflict('username_taken', 'Could not derive a username. Please contact support.');
    }
    const token = signAccessToken({ jwtSecret, jwtExpiresIn: appConfig.jwtExpiresIn }, inserted.id, 0);
    res.status(201).json(sessionJson(token, inserted));
  });

  router.post('/login', async (req, res) => {
    const body = parseWith(loginSchema, req.body);

    const remainingMs = loginThrottleRemainingMs(body.email);
    if (remainingMs > 0) {
      res.set('Retry-After', String(Math.ceil(remainingMs / 1000)));
      throw new ApiError(429, 'rate_limited', 'Too many failed logins. Please try again later.');
    }

    const { rows } = await pool.query(
      'SELECT id, name, email, password_hash, token_version FROM users WHERE email = $1',
      [body.email],
    );
    const user = rows[0];
    // Accounts created with Google have no password: same cost and the
    // same answer as a wrong password.
    const passwordOk = user?.password_hash
      ? await argon2.verify(user.password_hash, body.password)
      : // Unknown email: burn the same argon2 work so timing does not
        // reveal whether the account exists.
        (await argon2.verify(DUMMY_HASH, body.password), false);

    if (!user || !passwordOk) {
      recordLoginFailure(body.email);
      throw unauthorized('Email or password is incorrect.');
    }
    clearLoginFailures(body.email);
    const token = signAccessToken(
      { jwtSecret, jwtExpiresIn: appConfig.jwtExpiresIn },
      user.id,
      user.token_version,
    );
    res.json(sessionJson(token, user));
  });

  router.post('/logout', requireAuth, (_req, res) => {
    // Tokens are stateless; the client discards the token it holds.
    res.status(204).end();
  });

  return router;
}

export function createMeHandler() {
  return (req: { user?: { id: string; name: string; email: string } }, res: import('express').Response) => {
    const user = req.user!;
    res.json({ id: user.id, name: user.name, email: user.email });
  };
}
