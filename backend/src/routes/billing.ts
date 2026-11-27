import { timingSafeEqual } from 'node:crypto';
import { Router } from 'express';
import { Pool } from 'pg';
import { ApiError, unauthorized } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { entitlementsFor, upsertSubscription } from '../premium';
import { addRazorpayRoutes, RazorpayConfig } from '../billing-razorpay';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface BillingConfig extends RazorpayConfig {
  /** RevenueCat dashboard -> Integrations -> Webhooks -> Authorization header value. */
  revenuecatWebhookSecret: string;
  /** RevenueCat secret API key (server only), for POST /billing/sync. */
  revenuecatSecretKey: string;
  /** The RevenueCat entitlement that means Premium. */
  premiumEntitlementId: string;
}

/** RevenueCat event types and what each means for access. */
const EVENT_STATUS: Record<string, 'active' | 'grace' | 'cancelled' | 'expired' | undefined> = {
  INITIAL_PURCHASE: 'active',
  RENEWAL: 'active',
  UNCANCELLATION: 'active',
  PRODUCT_CHANGE: 'active',
  NON_RENEWING_PURCHASE: 'active',
  SUBSCRIPTION_EXTENDED: 'active',
  TEMPORARY_ENTITLEMENT_GRANT: 'active',
  CANCELLATION: 'cancelled',
  BILLING_ISSUE: 'grace',
  EXPIRATION: 'expired',
  SUBSCRIPTION_PAUSED: 'expired',
};

function sameSecret(given: string, expected: string): boolean {
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

/**
 * Premium billing (API.md 71). The backend is the only judge of who is
 * Premium: the app reads GET /billing/entitlements and never trusts itself.
 */
export function createBillingRouter(pool: Pool, requireAuth: RequireAuth, config: BillingConfig): Router {
  const router = Router();

  router.get('/entitlements', requireAuth, async (req, res) => {
    res.json(await entitlementsFor(pool, req.user!.id));
  });

  // Right after a store purchase the webhook may not have arrived yet; the
  // app asks the backend to look the subscriber up in RevenueCat directly.
  router.post('/sync', requireAuth, async (req, res) => {
    const userId = req.user!.id;
    if (config.revenuecatSecretKey) {
      const response = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
        { headers: { Authorization: `Bearer ${config.revenuecatSecretKey}` } },
      );
      if (response.ok) {
        const body = (await response.json()) as {
          subscriber?: {
            entitlements?: Record<string, { expires_date?: string | null; product_identifier?: string }>;
          };
        };
        const ent = body.subscriber?.entitlements?.[config.premiumEntitlementId];
        if (ent) {
          const expiresAt = ent.expires_date ? new Date(ent.expires_date) : null;
          const live = expiresAt === null || expiresAt.getTime() > Date.now();
          await upsertSubscription(pool, {
            userId,
            provider: 'revenuecat',
            status: live ? 'active' : 'expired',
            expiresAt,
            productId: ent.product_identifier ?? null,
          });
        }
      }
    }
    res.json(await entitlementsFor(pool, userId));
  });

  // RevenueCat -> backend. Authenticated by the shared header value set in
  // the RevenueCat dashboard; each event id is applied once.
  router.post('/webhooks/revenuecat', async (req, res) => {
    if (!config.revenuecatWebhookSecret) {
      throw new ApiError(503, 'billing_unconfigured', 'Billing is not set up on this server.');
    }
    const header = req.headers.authorization ?? '';
    const given = header.startsWith('Bearer ') ? header.slice(7) : header;
    if (!sameSecret(given, config.revenuecatWebhookSecret)) throw unauthorized();

    const event = (req.body as { event?: Record<string, unknown> } | undefined)?.event;
    const id = typeof event?.id === 'string' ? event.id : null;
    const type = typeof event?.type === 'string' ? event.type : null;
    if (!event || !id || !type) {
      throw new ApiError(422, 'validation_error', 'Not a RevenueCat event.');
    }
    // Our RevenueCat app user id is the backend user id.
    const appUserId = typeof event.app_user_id === 'string' ? event.app_user_id : '';
    const userId = UUID_RE.test(appUserId) ? appUserId : null;

    const inserted = await pool.query(
      `INSERT INTO billing_events (id, provider, user_id, type)
       SELECT $1, 'revenuecat', u.id, $3
         FROM (SELECT $2::uuid AS id) x
         LEFT JOIN users u ON u.id = x.id
       ON CONFLICT (id) DO NOTHING
       RETURNING user_id`,
      [id, userId, type],
    );
    // Already applied (a retry), or nothing to apply.
    if (inserted.rowCount === 0) return void res.json({ applied: false, reason: 'duplicate' });
    const knownUser = inserted.rows[0].user_id as string | null;
    const status = EVENT_STATUS[type];
    if (!knownUser || !status) return void res.json({ applied: false, reason: 'ignored' });

    const entitlementIds = Array.isArray(event.entitlement_ids) ? event.entitlement_ids : null;
    if (entitlementIds && !entitlementIds.includes(config.premiumEntitlementId)) {
      return void res.json({ applied: false, reason: 'other_entitlement' });
    }
    const expiresMs = typeof event.expiration_at_ms === 'number' ? event.expiration_at_ms : null;
    await upsertSubscription(pool, {
      userId: knownUser,
      provider: 'revenuecat',
      status,
      expiresAt: expiresMs === null ? null : new Date(expiresMs),
      productId: typeof event.product_id === 'string' ? event.product_id : null,
      store: typeof event.store === 'string' ? event.store : null,
    });
    res.json({ applied: true });
  });

  addRazorpayRoutes(router, pool, requireAuth, config);
  return router;
}
