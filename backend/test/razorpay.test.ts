import { createHmac } from 'node:crypto';
import supertest from 'supertest';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { api, closePool, ensureSchema, registerUser, resetDb, testApp } from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterEach(() => vi.unstubAllGlobals());
afterAll(closePool);

// Test-only values; nothing here reaches Razorpay (fetch is stubbed).
const KEY_ID = 'rzp_test_key';
const KEY_SECRET = 'rzp-test-key-secret';
const HOOK_SECRET = 'rzp-test-webhook-secret';
const PLAN = 'plan_test99';
const rzpApp = () =>
  testApp({
    razorpayKeyId: KEY_ID,
    razorpayKeySecret: KEY_SECRET,
    razorpayWebhookSecret: HOOK_SECRET,
    razorpayPlanId: PLAN,
  });

const sign = (secret: string, data: string) => createHmac('sha256', secret).update(data).digest('hex');
const inDays = (d: number) => Math.floor(Date.now() / 1000) + d * 86_400;

/** Stubs Razorpay's REST API: subscriptions by id, created on POST. */
function stubRazorpay(subs: Record<string, Record<string, unknown>> = {}) {
  const calls: { method: string; url: string; body: unknown }[] = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init: RequestInit = {}) => {
      const body = init.body ? JSON.parse(String(init.body)) : undefined;
      calls.push({ method: init.method ?? 'GET', url, body });
      expect(String((init.headers as Record<string, string>).Authorization)).toBe(
        `Basic ${Buffer.from(`${KEY_ID}:${KEY_SECRET}`).toString('base64')}`,
      );
      const json = (data: unknown) => new Response(JSON.stringify(data), { status: 200 });
      if (url.endsWith('/subscriptions') && init.method === 'POST') {
        const sub = { id: 'sub_new1', status: 'created', notes: body.notes };
        subs[sub.id] = sub;
        return json(sub);
      }
      const cancel = url.match(/\/subscriptions\/([^/]+)\/cancel$/);
      if (cancel) return json({ ...subs[cancel[1]], status: 'active', current_end: inDays(20) });
      const one = url.match(/\/subscriptions\/([^/]+)$/);
      if (one && subs[one[1]]) return json(subs[one[1]]);
      return new Response('{}', { status: 404 });
    }),
  );
  return calls;
}

function webhook(app: ReturnType<typeof testApp>, body: unknown, opts: { secret?: string; id?: string } = {}) {
  const raw = JSON.stringify(body);
  return supertest(app)
    .post('/billing/webhooks/razorpay')
    .set('Content-Type', 'application/json')
    .set('X-Razorpay-Signature', sign(opts.secret ?? HOOK_SECRET, raw))
    .set('X-Razorpay-Event-Id', opts.id ?? `evt_${Math.random()}`)
    .send(raw);
}

const subEvent = (event: string, sub: Record<string, unknown>) => ({
  entity: 'event',
  event,
  payload: { subscription: { entity: sub } },
});

describe('Razorpay web payments (API.md 75)', () => {
  it('is off without keys: config says so and every action is 503', async () => {
    const app = testApp();
    const user = await registerUser(app, 'Off', 'off@example.com');
    expect((await api.get(app, '/billing/razorpay', user.token)).body).toEqual({ enabled: false, key_id: null });
    expect((await api.post(app, '/billing/razorpay/subscription', user.token)).status).toBe(503);
    expect((await api.post(app, '/billing/webhooks/razorpay', undefined, {})).status).toBe(503);
  });

  it('checkout: create, verify the signed payment, then Premium is on', async () => {
    const app = rzpApp();
    const user = await registerUser(app, 'Web Buyer', 'web@example.com');
    const subs: Record<string, Record<string, unknown>> = {};
    const calls = stubRazorpay(subs);

    expect((await api.get(app, '/billing/razorpay', user.token)).body).toEqual({ enabled: true, key_id: KEY_ID });
    const created = await api.post(app, '/billing/razorpay/subscription', user.token);
    expect(created.status).toBe(201);
    expect(created.body).toMatchObject({ key_id: KEY_ID, subscription_id: 'sub_new1', email: 'web@example.com' });
    expect(calls[0].body).toMatchObject({ plan_id: PLAN, notes: { user_id: user.id } });

    // A forged signature is refused and changes nothing.
    const forged = await api.post(app, '/billing/razorpay/verify', user.token, {
      razorpay_payment_id: 'pay_1',
      razorpay_subscription_id: 'sub_new1',
      razorpay_signature: 'f'.repeat(64),
    });
    expect(forged.status).toBe(400);
    expect((await api.get(app, '/billing/entitlements', user.token)).body.premium).toBe(false);

    subs.sub_new1 = { ...subs.sub_new1, status: 'active', current_end: inDays(30) };
    const ok = await api.post(app, '/billing/razorpay/verify', user.token, {
      razorpay_payment_id: 'pay_1',
      razorpay_subscription_id: 'sub_new1',
      razorpay_signature: sign(KEY_SECRET, 'pay_1|sub_new1'),
    });
    expect(ok.status).toBe(200);
    expect(ok.body).toMatchObject({ premium: true, status: 'active', provider: 'razorpay', will_renew: true });

    // Already Premium: no second subscription.
    expect((await api.post(app, '/billing/razorpay/subscription', user.token)).status).toBe(409);
  });

  it("a valid payment for someone else's subscription does not unlock Premium", async () => {
    const app = rzpApp();
    const owner = await registerUser(app, 'Owner', 'owner@example.com');
    const other = await registerUser(app, 'Other', 'other@example.com');
    stubRazorpay({ sub_x: { id: 'sub_x', status: 'active', current_end: inDays(30), notes: { user_id: owner.id } } });
    const res = await api.post(app, '/billing/razorpay/verify', other.token, {
      razorpay_payment_id: 'pay_x',
      razorpay_subscription_id: 'sub_x',
      razorpay_signature: sign(KEY_SECRET, 'pay_x|sub_x'),
    });
    expect(res.status).toBe(400);
    expect((await api.get(app, '/billing/entitlements', other.token)).body.premium).toBe(false);
  });

  it('webhooks: signed events renew, retry, cancel and end Premium; each applied once', async () => {
    const app = rzpApp();
    const user = await registerUser(app, 'Renewer', 'renew@example.com');
    const sub = (status: string, days: number) => ({
      id: 'sub_w',
      status,
      current_end: inDays(days),
      notes: { user_id: user.id },
    });
    const ent = async () => (await api.get(app, '/billing/entitlements', user.token)).body;

    expect((await webhook(app, subEvent('subscription.charged', sub('active', 30)), { secret: 'wrong' })).status).toBe(401);
    expect((await ent()).premium).toBe(false);

    const first = await webhook(app, subEvent('subscription.charged', sub('active', 30)), { id: 'evt_1' });
    expect(first.body).toEqual({ applied: true });
    expect(await ent()).toMatchObject({ premium: true, provider: 'razorpay', status: 'active' });
    // Razorpay retries the same event: applied once.
    expect((await webhook(app, subEvent('subscription.charged', sub('active', 30)), { id: 'evt_1' })).body).toEqual({
      applied: false,
      reason: 'duplicate',
    });

    await webhook(app, subEvent('subscription.pending', sub('pending', 30)));
    expect(await ent()).toMatchObject({ premium: true, status: 'grace' });

    await webhook(app, subEvent('subscription.cancelled', sub('cancelled', 10)));
    expect(await ent()).toMatchObject({ premium: true, status: 'cancelled', will_renew: false });

    await webhook(app, subEvent('subscription.halted', sub('halted', 10)));
    expect((await ent()).premium).toBe(false);
  });

  it('cancel stops renewal at the end of the paid month', async () => {
    const app = rzpApp();
    const user = await registerUser(app, 'Leaver', 'leave@example.com');
    const subs = { sub_c: { id: 'sub_c', status: 'active', current_end: inDays(20), notes: { user_id: user.id } } };
    const calls = stubRazorpay(subs);
    await webhook(app, subEvent('subscription.activated', subs.sub_c));
    const res = await api.post(app, '/billing/razorpay/cancel', user.token);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ premium: true, status: 'cancelled', will_renew: false });
    expect(calls.at(-1)).toMatchObject({ method: 'POST', body: { cancel_at_cycle_end: 1 } });
    expect(calls.at(-1)!.url).toContain('/subscriptions/sub_c/cancel');
  });
});
