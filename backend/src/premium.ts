import { Pool, PoolClient } from 'pg';

/** What the app needs to know about a user's Premium (API.md 71). */
export interface Entitlements {
  premium: boolean;
  /** 'active' | 'grace' | 'cancelled' | 'expired' | null (never subscribed). */
  status: string | null;
  provider: string | null;
  expires_at: string | null;
  /** False once cancelled: access continues until expires_at. */
  will_renew: boolean;
}

type Queryable = Pool | PoolClient;

/**
 * Premium is on when any subscription is active, in grace, or cancelled but
 * not yet past its end date. A manual grant without an end date never ends.
 */
export async function entitlementsFor(db: Queryable, userId: string): Promise<Entitlements> {
  const { rows } = await db.query(
    `SELECT provider, status, expires_at
       FROM subscriptions
      WHERE user_id = $1
      ORDER BY (status IN ('active', 'grace', 'cancelled')
                AND (expires_at IS NULL OR expires_at > now())) DESC,
               expires_at DESC NULLS FIRST
      LIMIT 1`,
    [userId],
  );
  const row = rows[0];
  if (!row) {
    return { premium: false, status: null, provider: null, expires_at: null, will_renew: false };
  }
  const live =
    ['active', 'grace', 'cancelled'].includes(row.status) &&
    (row.expires_at === null || new Date(row.expires_at).getTime() > Date.now());
  return {
    premium: live,
    status: live ? row.status : 'expired',
    provider: row.provider,
    expires_at: row.expires_at ? new Date(row.expires_at).toISOString() : null,
    will_renew: live && row.status !== 'cancelled',
  };
}

export async function isPremium(db: Queryable, userId: string): Promise<boolean> {
  return (await entitlementsFor(db, userId)).premium;
}

/** Creates or replaces a user's subscription from one provider. */
export async function upsertSubscription(
  db: Queryable,
  sub: {
    userId: string;
    provider: 'manual' | 'revenuecat' | 'razorpay';
    status: 'active' | 'grace' | 'cancelled' | 'expired';
    expiresAt: Date | null;
    productId?: string | null;
    store?: string | null;
    /** The provider's own subscription id (Razorpay). */
    externalId?: string | null;
  },
): Promise<void> {
  await db.query(
    `INSERT INTO subscriptions (user_id, provider, status, expires_at, product_id, store, external_id)
     VALUES ($1, $2, $3, $4, COALESCE($5, 'premium_monthly'), $6, $7)
     ON CONFLICT (user_id, provider) DO UPDATE
       SET status = EXCLUDED.status,
           expires_at = EXCLUDED.expires_at,
           product_id = EXCLUDED.product_id,
           store = COALESCE(EXCLUDED.store, subscriptions.store),
           external_id = COALESCE(EXCLUDED.external_id, subscriptions.external_id),
           updated_at = now()`,
    [
      sub.userId,
      sub.provider,
      sub.status,
      sub.expiresAt,
      sub.productId ?? null,
      sub.store ?? null,
      sub.externalId ?? null,
    ],
  );
}
