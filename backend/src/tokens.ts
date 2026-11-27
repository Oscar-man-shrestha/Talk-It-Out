import jwt from 'jsonwebtoken';
import { Pool, PoolClient } from 'pg';
import { Config } from './config';

/**
 * Signs an access token. `tv` is the user's token_version; the auth
 * middleware rejects tokens whose `tv` no longer matches (migration 009).
 */
export function signAccessToken(
  appConfig: Pick<Config, 'jwtSecret' | 'jwtExpiresIn'>,
  userId: string,
  tokenVersion: number,
): string {
  return jwt.sign({ tv: tokenVersion }, appConfig.jwtSecret, {
    subject: userId,
    // StringValue-typed in @types/jsonwebtoken; config keeps it a string.
    expiresIn: appConfig.jwtExpiresIn as jwt.SignOptions['expiresIn'],
    algorithm: 'HS256',
  });
}

/**
 * Ends every session the user has: bumps token_version (all access
 * tokens) and revokes all refresh tokens. Returns the new version.
 */
export async function endAllSessions(
  client: Pool | PoolClient,
  userId: string,
): Promise<number> {
  const { rows } = await client.query<{ token_version: number }>(
    'UPDATE users SET token_version = token_version + 1 WHERE id = $1 RETURNING token_version',
    [userId],
  );
  await client.query(
    'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
    [userId],
  );
  return rows[0]?.token_version ?? 0;
}
