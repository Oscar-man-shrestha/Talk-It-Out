import crypto from 'node:crypto';
import argon2 from 'argon2';
import { Router } from 'express';
import { Pool, PoolClient } from 'pg';
import { z } from 'zod';
import { Config } from '../config';
import { withTransaction } from '../db';
import { ApiError, parseWith } from '../errors';
import { resetCodeEmail } from '../emails/resetCodeEmail';
import { createMailer } from '../mailer';
import { endAllSessions } from '../tokens';

/**
 * Password reset in three steps (API.md 38, 48):
 *
 * 1. POST /password-reset {email}: an unknown email gets 404 no_account
 *    (product decision, Run 087: say so rather than pretend a code was
 *    sent). A known email gets a 6-digit code by email; the request waits
 *    for the mail to be accepted, so a delivery failure is reported.
 *    One request per minute per account.
 * 2. POST /password-reset/verify {email, code}: checks the code and
 *    returns a one-time reset_token. Wrong codes count toward the limit.
 * 3. POST /password-reset/confirm {email, reset_token, new_password}
 *    sets the password. ({email, code, new_password} still works too.)
 *
 * Only keyed HMACs of the code and the token are stored. Codes expire
 * after 15 minutes and allow 5 attempts; a new request voids older codes.
 * A successful reset ends every session (token_version bump plus
 * refresh-token revocation), so a thief's tokens stop working too.
 */

export const RESET_CODE_TTL_MINUTES = 15;
export const RESET_MAX_ATTEMPTS = 5;
export const RESET_RESEND_SECONDS = 60;

const email = z.string().trim().toLowerCase().email('Enter a valid email address.');

const requestSchema = z.object({ email }).strict();

const code = z.string().trim().regex(/^\d{6}$/, 'Enter the 6-digit code.');

const verifySchema = z.object({ email, code }).strict();

const confirmSchema = z
  .object({
    email,
    code: code.optional(),
    reset_token: z.string().trim().regex(/^[0-9a-f]{64}$/, 'Start the reset again.').optional(),
    new_password: z
      .string()
      .min(8, 'Password must be at least 8 characters.')
      .max(128, 'Password must be at most 128 characters.'),
  })
  .strict()
  .refine((b) => b.code !== undefined || b.reset_token !== undefined, {
    message: 'Enter the 6-digit code.',
    path: ['code'],
  });

const invalidCode = (left?: number) =>
  new ApiError(
    400,
    'invalid_code',
    left === undefined || left <= 0
      ? 'That code is not valid or has expired. Ask for a new one.'
      : `That code is not right. ${left} ${left === 1 ? 'try' : 'tries'} left.`,
  );

/** The bare address inside "Name <address>", for the email footer. */
const addressOf = (from: string) => /<([^>]+)>/.exec(from)?.[1] ?? from;

interface ResetRow {
  id: string;
  user_id: string;
  code_hash: string;
  verify_token_hash: string | null;
  attempts: number;
  expires_at: Date;
}

export function createPasswordResetRouter(pool: Pool, appConfig: Config): Router {
  const router = Router();
  const mailer = createMailer(appConfig);
  const hash = (userId: string, value: string) =>
    crypto.createHmac('sha256', appConfig.jwtSecret).update(`${userId}:${value}`).digest('hex');

  router.post('/password-reset', async (req, res) => {
    const body = parseWith(requestSchema, req.body);
    if (!mailer) {
      throw new ApiError(503, 'email_not_configured', 'Password reset is not available yet.');
    }
    const { rows } = await pool.query<{ id: string; name: string; recent: boolean }>(
      `SELECT u.id, u.name,
              EXISTS (SELECT 1 FROM password_resets r
                      WHERE r.user_id = u.id
                        AND r.created_at > now() - make_interval(secs => $2)) AS recent
       FROM users u WHERE u.email = $1`,
      [body.email, RESET_RESEND_SECONDS],
    );
    const user = rows[0];
    if (!user) {
      throw new ApiError(
        404,
        'no_account',
        'No account uses this email. Check it, or create an account.',
      );
    }
    if (user.recent) {
      throw new ApiError(
        429,
        'too_soon',
        'A code was just sent. Wait a minute before asking for another.',
      );
    }
    const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
    await withTransaction(pool, async (client) => {
      await client.query('DELETE FROM password_resets WHERE user_id = $1', [user.id]);
      await client.query(
        `INSERT INTO password_resets (user_id, code_hash, expires_at)
         VALUES ($1, $2, now() + make_interval(mins => $3))`,
        [user.id, hash(user.id, code), RESET_CODE_TTL_MINUTES],
      );
    });
    try {
      await mailer.send({
        to: body.email,
        ...resetCodeEmail({
          name: user.name,
          code,
          minutes: RESET_CODE_TTL_MINUTES,
          contact: addressOf(appConfig.mailFrom),
        }),
      });
    } catch (err: unknown) {
      // Never log the address or the code.
      console.error(
        '[password-reset] mail send failed:',
        err instanceof Error ? err.name : 'unknown error',
      );
      await pool.query('DELETE FROM password_resets WHERE user_id = $1', [user.id]);
      throw new ApiError(
        502,
        'email_failed',
        'We could not send the email right now. Try again in a minute.',
      );
    }
    res.status(202).json({ status: 'sent', expires_in_minutes: RESET_CODE_TTL_MINUTES });
  });

  /** The live reset for this email, locked for the rest of the transaction. */
  const lockReset = async (client: PoolClient, address: string): Promise<ResetRow | null> => {
    const { rows } = await client.query<ResetRow>(
      `SELECT r.id, r.user_id, r.code_hash, r.verify_token_hash, r.attempts, r.expires_at
       FROM password_resets r JOIN users u ON u.id = r.user_id
       WHERE u.email = $1 AND r.used_at IS NULL
       ORDER BY r.created_at DESC LIMIT 1
       FOR UPDATE OF r`,
      [address],
    );
    const reset = rows[0];
    if (!reset) return null;
    if (reset.attempts >= RESET_MAX_ATTEMPTS || reset.expires_at.getTime() <= Date.now()) {
      return null;
    }
    return reset;
  };

  const same = (storedHex: string | null, givenHex: string) =>
    storedHex !== null &&
    crypto.timingSafeEqual(Buffer.from(storedHex, 'hex'), Buffer.from(givenHex, 'hex'));

  /** Checks a code; on a miss counts the attempt and returns tries left. */
  const checkCode = async (client: PoolClient, reset: ResetRow, given: string) => {
    if (same(reset.code_hash, hash(reset.user_id, given))) return { ok: true as const };
    await client.query('UPDATE password_resets SET attempts = attempts + 1 WHERE id = $1', [
      reset.id,
    ]);
    return { ok: false as const, left: RESET_MAX_ATTEMPTS - reset.attempts - 1 };
  };

  router.post('/password-reset/verify', async (req, res) => {
    const body = parseWith(verifySchema, req.body);
    const outcome = await withTransaction(pool, async (client) => {
      const reset = await lockReset(client, body.email);
      if (!reset) return { token: null, left: 0 };
      const checked = await checkCode(client, reset, body.code);
      if (!checked.ok) return { token: null, left: checked.left };
      const token = crypto.randomBytes(32).toString('hex');
      await client.query('UPDATE password_resets SET verify_token_hash = $2 WHERE id = $1', [
        reset.id,
        hash(reset.user_id, `token:${token}`),
      ]);
      return { token, left: 0 };
    });
    // Throw after the transaction so a wrong-attempt count is committed.
    if (!outcome.token) throw invalidCode(outcome.left);
    res.json({ reset_token: outcome.token });
  });

  router.post('/password-reset/confirm', async (req, res) => {
    const body = parseWith(confirmSchema, req.body);
    const outcome = await withTransaction(pool, async (client) => {
      const reset = await lockReset(client, body.email);
      if (!reset) return { ok: false, left: 0 };
      if (body.reset_token !== undefined) {
        // A token comes only from a correct code; a wrong one restarts.
        if (!same(reset.verify_token_hash, hash(reset.user_id, `token:${body.reset_token}`))) {
          return { ok: false, left: 0 };
        }
      } else {
        const checked = await checkCode(client, reset, body.code!);
        if (!checked.ok) return { ok: false, left: checked.left };
      }
      const passwordHash = await argon2.hash(body.new_password);
      await client.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
        passwordHash,
        reset.user_id,
      ]);
      await client.query('DELETE FROM password_resets WHERE user_id = $1', [reset.user_id]);
      // Ends every session: existing access and refresh tokens stop working.
      await endAllSessions(client, reset.user_id);
      return { ok: true, left: 0 };
    });
    if (!outcome.ok) throw invalidCode(outcome.left);
    res.status(204).end();
  });

  return router;
}
