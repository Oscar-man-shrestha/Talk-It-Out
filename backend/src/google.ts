import crypto, { JsonWebKey, KeyObject } from 'node:crypto';
import jwt from 'jsonwebtoken';

/**
 * Verifies Google ID tokens locally against Google's published signing
 * keys (no third-party library): RS256 signature, audience (one of our
 * client ids), issuer, expiry, and a verified email.
 */

const GOOGLE_CERTS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const GOOGLE_ISSUERS: [string, ...string[]] = ['accounts.google.com', 'https://accounts.google.com'];

export interface GoogleIdentity {
  sub: string;
  email: string;
  name: string;
}

export class GoogleTokenError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'GoogleTokenError';
  }
}

interface CachedKeys {
  keys: Map<string, KeyObject>;
  expiresAt: number;
}

let cache: CachedKeys | null = null;
let fixedKeys: Map<string, KeyObject> | null = null;

/** Tests only: use these keys instead of fetching Google's. */
export function setGoogleKeysForTests(keys: Record<string, KeyObject> | null): void {
  fixedKeys = keys ? new Map(Object.entries(keys)) : null;
}

async function signingKeys(forceRefresh: boolean): Promise<Map<string, KeyObject>> {
  if (fixedKeys) return fixedKeys;
  if (!forceRefresh && cache && cache.expiresAt > Date.now()) return cache.keys;
  const response = await fetch(GOOGLE_CERTS_URL, { signal: AbortSignal.timeout(5000) });
  if (!response.ok) throw new GoogleTokenError('could not fetch Google keys');
  const body = (await response.json()) as { keys?: (JsonWebKey & { kid?: string })[] };
  const keys = new Map<string, KeyObject>();
  for (const jwk of body.keys ?? []) {
    if (jwk.kid) keys.set(jwk.kid, crypto.createPublicKey({ key: jwk, format: 'jwk' }));
  }
  // Respect Google's cache lifetime (Cache-Control max-age), capped at 6h.
  const maxAge = /max-age=(\d+)/.exec(response.headers.get('cache-control') ?? '');
  const seconds = Math.min(maxAge ? Number(maxAge[1]) : 3600, 6 * 3600);
  cache = { keys, expiresAt: Date.now() + seconds * 1000 };
  return keys;
}

export async function verifyGoogleIdToken(
  idToken: string,
  clientIds: string[],
): Promise<GoogleIdentity> {
  const decoded = jwt.decode(idToken, { complete: true });
  const kid = decoded && typeof decoded === 'object' ? decoded.header.kid : undefined;
  if (!kid) throw new GoogleTokenError('malformed token');
  let key = (await signingKeys(false)).get(kid);
  // Google rotates keys; refetch once for an unknown kid.
  if (!key) key = (await signingKeys(true)).get(kid);
  if (!key) throw new GoogleTokenError('unknown signing key');

  let payload: jwt.JwtPayload;
  try {
    const verified = jwt.verify(idToken, key, {
      algorithms: ['RS256'],
      audience: clientIds as [string, ...string[]],
      issuer: GOOGLE_ISSUERS,
    });
    if (typeof verified === 'string') throw new GoogleTokenError('unexpected payload');
    payload = verified;
  } catch (err) {
    if (err instanceof GoogleTokenError) throw err;
    throw new GoogleTokenError('invalid token');
  }
  const email = typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : '';
  if (!payload.sub || !email) throw new GoogleTokenError('missing identity');
  if (payload.email_verified !== true && payload.email_verified !== 'true') {
    throw new GoogleTokenError('email not verified');
  }
  const name =
    typeof payload.name === 'string' && payload.name.trim()
      ? payload.name.trim().slice(0, 200)
      : email.split('@')[0];
  return { sub: payload.sub, email, name };
}
