import { createHmac, timingSafeEqual } from 'node:crypto';
import { Router } from 'express';
import { Pool } from 'pg';
import { z } from 'zod';
import { ApiError, unauthorized } from './errors';
import { RequireAuth } from './middleware/auth';
import { entitlementsFor, isPremium, upsertSubscription } from './premium';

const API = 'https://api.razorpay.com/v1';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface RazorpayConfig {
  razorpayKeyId: string;
  razorpayKeySecret: string;
  razorpayWebhookSecret: string;
  razorpayPlanId: string;
}

/** A Razorpay subscription as far as we use it. */
interface RzpSubscription {
  id: string;
  status: string;
  current_end?: number | null;
  notes?: Record<string, unknown> | unknown[];
}

type Status = 'active' | 'grace' | 'cancelled' | 'expired';

/** Razorpay subscription states and what each means for access. */
const STATUS: Record<string, Status | undefined> = {
  active: 'active',
  pending: 'grace', // a renewal charge failed; Razorpay retries
  halted: 'expired', // retries ran out
  cancelled: 'cancelled', // access until the paid period ends
  completed: 'expired',
  expired: 'expired',
  // created / authenticated: nothing paid yet.
};

const verifySchema = z.object({
  razorpay_payment_id: z.string().trim().min(1).max(100),
  razorpay_subscription_id: z.string().trim().min(1).max(100),
  razorpay_signature: z.string().trim().min(1).max(200),
});

function hmacHex(secret: string, data: string | Buffer): string {
  return createHmac('sha256', secret).update(data).digest('hex');
}

function sameHex(given: string, expected: string): boolean {
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

function noteUserId(sub: RzpSubscription): string | null {
  const notes = sub.notes && !Array.isArray(sub.notes) ? sub.notes : {};
  const id = typeof notes.user_id === 'string' ? notes.user_id : '';
  return UUID_RE.test(id) ? id : null;
}

/** End of the paid period; a month from now if Razorpay did not say. */
function periodEnd(sub: RzpSubscription): Date {
  return typeof sub.current_end === 'number' && sub.current_end > 0
    ? new Date(sub.current_end * 1000)
    : new Date(Date.now() + 32 * 24 * 3600 * 1000);
}

async function applySubscription(pool: Pool, userId: string, sub: RzpSubscription): Promise<boolean> {
  const status = STATUS[sub.status];
  if (!status) return false;
  await upsertSubscription(pool, {
    userId,
    provider: 'razorpay',
    status,
    expiresAt: periodEnd(sub),
    store: 'razorpay_web',
    externalId: sub.id,
  });
  return true;
}

/**
 * Razorpay for web payments (API.md 75): UPI, cards, net banking and
 * wallets on the website. Phones keep App Store / Google Play billing.
 * Talk It Out never sees card or UPI details; the backend decides Premium
 * only from Razorpay-signed data.
 */
export function addRazorpayRoutes(router: Router, pool: Pool, requireAuth: RequireAuth, config: RazorpayConfig): void {
  const enabled = () => config.razorpayKeyId !== '' && config.razorpayKeySecret !== '' && config.razorpayPlanId !== '';
  const auth = () => `Basic ${Buffer.from(`${config.razorpayKeyId}:${config.razorpayKeySecret}`).toString('base64')}`;
  const unavailable = () => new ApiError(503, 'billing_unconfigured', 'Web payments are not set up on this server.');

  async function call<T>(method: 'GET' | 'POST', path: string, body?: unknown): Promise<T> {
    let response: Response;
    try {
      response = await fetch(`${API}${path}`, {
        method,
        headers: { Authorization: auth(), ...(body ? { 'Content-Type': 'application/json' } : {}) },
        body: body ? JSON.stringify(body) : undefined,
      });
    } catch {
      throw new ApiError(502, 'payment_provider_unavailable', 'Could not reach the payment provider. Try again.');
    }
    if (!response.ok) {
      throw new ApiError(502, 'payment_provider_error', 'The payment provider did not accept the request. Try again.');
    }
    return (await response.json()) as T;
  }

  // Whether the web can offer Razorpay, and the public key for Checkout.
  router.get('/razorpay', requireAuth, (_req, res) => {
    res.json({ enabled: enabled(), key_id: enabled() ? config.razorpayKeyId : null });
  });

  // Starts a ₹99 monthly subscription; the app opens Razorpay Checkout with it.
  router.post('/razorpay/subscription', requireAuth, async (req, res) => {
    if (!enabled()) throw unavailable();
    const userId = req.user!.id;
    if (await isPremium(pool, userId)) {
      throw new ApiError(409, 'already_premium', 'You already have Premium.');
    }
    const sub = await call<RzpSubscription>('POST', '/subscriptions', {
      plan_id: config.razorpayPlanId,
      total_count: 120, // up to ten years of monthly renewals
      quantity: 1,
      customer_notify: 1,
      notes: { user_id: userId },
    });
    const user = await pool.query('SELECT name, email FROM users WHERE id = $1', [userId]);
    res.status(201).json({
      key_id: config.razorpayKeyId,
      subscription_id: sub.id,
      name: user.rows[0]?.name ?? '',
      email: user.rows[0]?.email ?? '',
    });
  });

  // Checkout's success callback: check Razorpay's signature, then confirm the
  // subscription with Razorpay before turning Premium on.
  router.post('/razorpay/verify', requireAuth, async (req, res) => {
    if (!enabled()) throw unavailable();
    const body = verifySchema.parse(req.body);
    const expected = hmacHex(
      config.razorpayKeySecret,
      `${body.razorpay_payment_id}|${body.razorpay_subscription_id}`,
    );
    if (!sameHex(body.razorpay_signature, expected)) {
      throw new ApiError(400, 'payment_not_verified', 'This payment could not be verified.');
    }
    const sub = await call<RzpSubscription>(
      'GET',
      `/subscriptions/${encodeURIComponent(body.razorpay_subscription_id)}`,
    );
    if (noteUserId(sub) !== req.user!.id) {
      throw new ApiError(400, 'payment_not_verified', 'This payment could not be verified.');
    }
    // Paid but Razorpay still says "authenticated" for a moment: count the
    // signed payment as the first month; the webhook corrects it later.
    await applySubscription(pool, req.user!.id, sub.status === 'authenticated' ? { ...sub, status: 'active' } : sub);
    res.json(await entitlementsFor(pool, req.user!.id));
  });

  // Cancels at the end of the paid month (access stays until then).
  router.post('/razorpay/cancel', requireAuth, async (req, res) => {
    if (!enabled()) throw unavailable();
    const row = await pool.query(
      `SELECT external_id FROM subscriptions
        WHERE user_id = $1 AND provider = 'razorpay' AND external_id IS NOT NULL`,
      [req.user!.id],
    );
    const subId = row.rows[0]?.external_id as string | undefined;
    if (!subId) throw new ApiError(404, 'not_found', 'There is no web subscription to cancel.');
    const sub = await call<RzpSubscription>('POST', `/subscriptions/${encodeURIComponent(subId)}/cancel`, {
      cancel_at_cycle_end: 1,
    });
    await upsertSubscription(pool, {
      userId: req.user!.id,
      provider: 'razorpay',
      status: 'cancelled',
      expiresAt: periodEnd(sub),
      externalId: subId,
    });
    res.json(await entitlementsFor(pool, req.user!.id));
  });

  // Razorpay -> backend. Signed over the raw body with the webhook secret;
  // each event id is applied once (Razorpay retries).
  router.post('/webhooks/razorpay', async (req, res) => {
    if (!config.razorpayWebhookSecret) {
      throw new ApiError(503, 'billing_unconfigured', 'Billing is not set up on this server.');
    }
    const raw = (req as unknown as { rawBody?: Buffer }).rawBody;
    const signature = String(req.headers['x-razorpay-signature'] ?? '');
    if (!raw || !signature || !sameHex(signature, hmacHex(config.razorpayWebhookSecret, raw))) {
      throw unauthorized();
    }
    const event = req.body as {
      event?: string;
      payload?: { subscription?: { entity?: RzpSubscription } };
    };
    const type = typeof event.event === 'string' ? event.event : '';
    const sub = event.payload?.subscription?.entity;
    if (!type) throw new ApiError(422, 'validation_error', 'Not a Razorpay event.');
    const eventId = String(req.headers['x-razorpay-event-id'] ?? '') || `${type}:${sub?.id ?? ''}:${sub?.status ?? ''}:${sub?.current_end ?? ''}`;
    const userId = sub ? noteUserId(sub) : null;

    const inserted = await pool.query(
      `INSERT INTO billing_events (id, provider, user_id, type)
       SELECT $1, 'razorpay', u.id, $3
         FROM (SELECT $2::uuid AS id) x
         LEFT JOIN users u ON u.id = x.id
       ON CONFLICT (id) DO NOTHING
       RETURNING user_id`,
      [`rzp:${eventId}`, userId, type],
    );
    if (inserted.rowCount === 0) return void res.json({ applied: false, reason: 'duplicate' });
    const knownUser = inserted.rows[0].user_id as string | null;
    if (!knownUser || !sub || !type.startsWith('subscription.')) {
      return void res.json({ applied: false, reason: 'ignored' });
    }
    const applied = await applySubscription(pool, knownUser, sub);
    res.json({ applied, ...(applied ? {} : { reason: 'ignored' }) });
  });
}
