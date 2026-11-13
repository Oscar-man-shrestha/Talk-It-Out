import crypto from 'node:crypto';
import argon2 from 'argon2';
import { Router } from 'express';
import { Pool } from 'pg';
import { z } from 'zod';
import { Config } from '../config';
import { withTransaction } from '../db';
import { ApiError, parseWith } from '../errors';
import { createMailer } from '../mailer';

/**
 * Password reset by emailed 6-digit code (API.md 38).
 *
 * - The request endpoint answers 202 the same way whether or not the email
 *   has an account, and sends the mail without awaiting it, so neither the
 *   response nor its timing reveals which addresses are registered.
 * - Only an HMAC of the code (keyed with JWT_SECRET, bound to the user id)
 *   is stored. Codes expire after 15 minutes, allow 5 attempts, and a new
 *   request voids older codes.
 * - A successful reset revokes every refresh token. Access tokens are
 *   stateless and expire on their own schedule.
 */

export const RESET_CODE_TTL_MINUTES = 15;
export const RESET_MAX_ATTEMPTS = 5;

const email = z.string().trim().toLowerCase().email('Enter a valid email address.');

const requestSchema = z.object({ email }).strict();

const confirmSchema = z
  .object({
    email,
    code: z.string().trim().regex(/^\d{6}$/, 'Enter the 6-digit code.'),
    new_password: z
      .string()
      .min(8, 'Password must be at least 8 characters.')
      .max(128, 'Password must be at most 128 characters.'),
  })
  .strict();

const invalidCode = () =>
  new ApiError(400, 'invalid_code', 'That code is not valid or has expired.');

export function createPasswordResetRouter(pool: Pool, appConfig: Config): Router {
  const router = Router();
  const mailer = createMailer(appConfig);
  const hashCode = (userId: string, code: string) =>
    crypto.createHmac('sha256', appConfig.jwtSecret).update(`${userId}:${code}`).digest('hex');

  router.post('/password-reset', async (req, res) => {
    const body = parseWith(requestSchema, req.body);
    if (!mailer) {
      throw new ApiError(503, 'email_not_configured', 'Password reset is not available yet.');
    }
    const { rows } = await pool.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [
      body.email,
    ]);
    const user = rows[0];
    if (user) {
      const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
      await withTransaction(pool, async (client) => {
        await client.query('DELETE FROM password_resets WHERE user_id = $1', [user.id]);
        await client.query(
          `INSERT INTO password_resets (user_id, code_hash, expires_at)
           VALUES ($1, $2, now() + make_interval(mins => $3))`,
          [user.id, hashCode(user.id, code), RESET_CODE_TTL_MINUTES],
        );
      });
      mailer
        .send({
          to: body.email,
          subject: 'Your Talk It Out password reset code',
          text:
            `Your password reset code is ${code}.\n\n` +
            `It expires in ${RESET_CODE_TTL_MINUTES} minutes. If you did not ask to ` +
            'reset your password, you can ignore this email.',
        })
        .catch((err: unknown) => {
          // Never log the address or the code.
          console.error(
            '[password-reset] mail send failed:',
            err instanceof Error ? err.name : 'unknown error',
          );
        });
    }
    res.status(202).json({ status: 'sent_if_registered' });
  });

  router.post('/password-reset/confirm', async (req, res) => {
    const body = parseWith(confirmSchema, req.body);
    const ok = await withTransaction(pool, async (client) => {
      const { rows } = await client.query(
        `SELECT r.id, r.user_id, r.code_hash, r.attempts, r.expires_at
         FROM password_resets r JOIN users u ON u.id = r.user_id
         WHERE u.email = $1 AND r.used_at IS NULL
         ORDER BY r.created_at DESC LIMIT 1
         FOR UPDATE OF r`,
        [body.email],
      );
      const reset = rows[0];
      if (!reset) return false;
      if (reset.attempts >= RESET_MAX_ATTEMPTS || reset.expires_at.getTime() <= Date.now()) {
        return false;
      }
      const expected = Buffer.from(reset.code_hash, 'hex');
      const given = Buffer.from(hashCode(reset.user_id, body.code), 'hex');
      if (!crypto.timingSafeEqual(expected, given)) {
        await client.query('UPDATE password_resets SET attempts = attempts + 1 WHERE id = $1', [
          reset.id,
        ]);
        return false;
      }
      const passwordHash = await argon2.hash(body.new_password);
      await client.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
        passwordHash,
        reset.user_id,
      ]);
      await client.query('DELETE FROM password_resets WHERE user_id = $1', [reset.user_id]);
      await client.query(
        'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
        [reset.user_id],
      );
      return true;
    });
    // Throw after the transaction so a wrong-attempt count is committed.
    if (!ok) throw invalidCode();
    res.status(204).end();
  });

  return router;
}
