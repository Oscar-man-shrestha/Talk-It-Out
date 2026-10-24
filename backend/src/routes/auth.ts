import crypto from 'node:crypto';
import { Router } from 'express';
import argon2 from 'argon2';
import jwt from 'jsonwebtoken';
import { Pool } from 'pg';
import { z } from 'zod';
import { conflict, parseWith, unauthorized } from '../errors';
import { uniqueConstraint } from '../db';
import { RequireAuth } from '../middleware/auth';

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
    .max(128, 'Password is too long.'),
});

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email('Enter a valid email address.'),
  password: z.string().min(1, 'Enter your password.'),
});

/**
 * Username is derived at registration: the lowercased email local-part
 * restricted to [a-z0-9._-]. On collision, "-" plus the first 4 hex chars of
 * the new user id are appended (more hex chars only in the extreme case where
 * even that collides). The client never sends or receives the username.
 */
function baseUsername(email: string): string {
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

export function createAuthRouter(pool: Pool, jwtSecret: string, requireAuth: RequireAuth): Router {
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
    const token = jwt.sign({}, jwtSecret, { subject: inserted.id, expiresIn: '7d' });
    res.status(201).json(sessionJson(token, inserted));
  });

  router.post('/login', async (req, res) => {
    const body = parseWith(loginSchema, req.body);
    const { rows } = await pool.query(
      'SELECT id, name, email, password_hash FROM users WHERE email = $1',
      [body.email],
    );
    const user = rows[0];
    if (!user || !(await argon2.verify(user.password_hash, body.password))) {
      throw unauthorized('Email or password is incorrect.');
    }
    const token = jwt.sign({}, jwtSecret, { subject: user.id, expiresIn: '7d' });
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
