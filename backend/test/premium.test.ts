import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { upsertSubscription } from '../src/premium';
import { topWords } from '../src/routes/insights';
import {
  api,
  closePool,
  ensureSchema,
  registerUser,
  resetDb,
  seedGroup,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const SECRET = 'rc-test-secret';
const premiumApp = () => testApp({ revenuecatWebhookSecret: SECRET, premiumEntitlementId: 'premium' });

function rcEvent(id: string, type: string, userId: string, extra: Record<string, unknown> = {}) {
  return {
    api_version: '1.0',
    event: {
      id,
      type,
      app_user_id: userId,
      product_id: 'premium_monthly',
      entitlement_ids: ['premium'],
      store: 'PLAY_STORE',
      expiration_at_ms: Date.now() + 30 * 86_400_000,
      ...extra,
    },
  };
}

describe('premium entitlements (API.md 71)', () => {
  it('a new user is on Free', async () => {
    const app = premiumApp();
    const user = await registerUser(app, 'Free User', 'free@example.com');
    const res = await api.get(app, '/billing/entitlements', user.token);
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      premium: false,
      status: null,
      provider: null,
      expires_at: null,
      will_renew: false,
    });
    expect((await api.get(app, '/billing/entitlements')).status).toBe(401);
  });

  it('RevenueCat purchase, cancellation and expiry move Premium on and off', async () => {
    const app = premiumApp();
    const user = await registerUser(app, 'Buyer', 'buyer@example.com');
    const hook = (body: unknown, secret = SECRET) =>
      api.post(app, '/billing/webhooks/revenuecat', secret, body);

    expect((await hook(rcEvent('e1', 'INITIAL_PURCHASE', user.id), 'wrong')).status).toBe(401);

    const bought = await hook(rcEvent('e1', 'INITIAL_PURCHASE', user.id));
    expect(bought.body).toEqual({ applied: true });
    let ent = (await api.get(app, '/billing/entitlements', user.token)).body;
    expect(ent).toMatchObject({ premium: true, status: 'active', provider: 'revenuecat', will_renew: true });

    // A retried event is applied once.
    expect((await hook(rcEvent('e1', 'INITIAL_PURCHASE', user.id))).body.reason).toBe('duplicate');

    await hook(rcEvent('e2', 'CANCELLATION', user.id));
    ent = (await api.get(app, '/billing/entitlements', user.token)).body;
    expect(ent).toMatchObject({ premium: true, status: 'cancelled', will_renew: false });

    await hook(rcEvent('e3', 'EXPIRATION', user.id, { expiration_at_ms: Date.now() - 1000 }));
    ent = (await api.get(app, '/billing/entitlements', user.token)).body;
    expect(ent.premium).toBe(false);
  });

  it('ignores unknown users, other entitlements and test events', async () => {
    const app = premiumApp();
    const user = await registerUser(app, 'Other', 'other@example.com');
    const hook = (body: unknown) => api.post(app, '/billing/webhooks/revenuecat', SECRET, body);
    expect(
      (await hook(rcEvent('x1', 'INITIAL_PURCHASE', '00000000-0000-0000-0000-000000000000'))).body,
    ).toEqual({ applied: false, reason: 'ignored' });
    expect((await hook(rcEvent('x2', 'TEST', user.id))).body.reason).toBe('ignored');
    expect(
      (await hook(rcEvent('x3', 'INITIAL_PURCHASE', user.id, { entitlement_ids: ['other'] }))).body
        .reason,
    ).toBe('other_entitlement');
    expect((await api.get(app, '/billing/entitlements', user.token)).body.premium).toBe(false);
    expect((await hook({ nope: true })).status).toBe(422);
  });

  it('the webhook is off when no secret is configured', async () => {
    const app = testApp({ revenuecatWebhookSecret: '' });
    const res = await api.post(app, '/billing/webhooks/revenuecat', 'anything', rcEvent('z', 'RENEWAL', 'u'));
    expect(res.status).toBe(503);
  });

  it('a manual grant without an end date stays on; billing data has no message text', async () => {
    const app = premiumApp();
    const user = await registerUser(app, 'Pilot', 'pilot@example.com');
    await upsertSubscription(testPool(), {
      userId: user.id,
      provider: 'manual',
      status: 'active',
      expiresAt: null,
    });
    const ent = (await api.get(app, '/billing/entitlements', user.token)).body;
    expect(ent).toMatchObject({ premium: true, provider: 'manual', expires_at: null });
    const cols = await testPool().query(
      `SELECT column_name FROM information_schema.columns
        WHERE table_name IN ('subscriptions', 'billing_events')`,
    );
    const names = cols.rows.map((r: { column_name: string }) => r.column_name);
    expect(names.some((n: string) => /text|body|message/.test(n))).toBe(false);
  });
});

describe('group insights (API.md 71)', () => {
  async function addMembers(groupId: string, n: number) {
    const app = testApp();
    for (let i = 0; i < n; i += 1) {
      const u = await registerUser(app, `Member ${i}`, `member${i}-${groupId.slice(0, 6)}@example.com`);
      await testPool().query(
        `INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'contributor')`,
        [groupId, u.id],
      );
    }
  }

  async function publish(groupId: string, text: string, authorId: string | null) {
    await testPool().query(
      `INSERT INTO published_messages (group_id, author_id, text, is_anonymous)
       VALUES ($1, $2, $3, $4)`,
      [groupId, authorId, text, authorId === null],
    );
  }

  it('is for the controller, and only with Premium', async () => {
    const app = premiumApp();
    const { controller, contributor, groupId } = await seedGroup(app, { agenda: 'Launch retro' });
    const path = `/groups/${groupId}/insights`;
    expect((await api.get(app, path, contributor.token)).status).toBe(403);
    const locked = await api.get(app, path, controller.token);
    expect(locked.status).toBe(402);
    expect(locked.body.error.code).toBe('premium_required');
    await upsertSubscription(testPool(), {
      userId: controller.id,
      provider: 'manual',
      status: 'active',
      expiresAt: null,
    });
    expect((await api.get(app, path, controller.token)).status).toBe(200);
    expect((await api.get(app, '/groups/00000000-0000-0000-0000-000000000000/insights', controller.token)).status).toBe(404);
  });

  it('small groups get totals and themes but no breakdowns', async () => {
    const app = premiumApp();
    const { controller, contributor, groupId } = await seedGroup(app, { agenda: 'Launch retro' });
    await upsertSubscription(testPool(), { userId: controller.id, provider: 'manual', status: 'active', expiresAt: null });
    await publish(groupId, 'The deployment checklist was missing steps', contributor.id);
    await publish(groupId, 'Deployment checklist needs an owner', null);
    const res = await api.get(app, `/groups/${groupId}/insights`, controller.token);
    expect(res.body).toMatchObject({
      window_days: 14,
      member_count: 2,
      breakdowns_available: false,
      messages: 2,
      participants: null,
      anonymous_messages: null,
      busiest_hours: null,
    });
    expect(res.body.daily).toHaveLength(14);
    expect(res.body.top_words.map((w: { word: string }) => w.word)).toEqual(
      expect.arrayContaining(['checklist', 'deployment']),
    );
    // Nothing in the response names or identifies a person.
    expect(JSON.stringify(res.body)).not.toContain(contributor.id);
    expect(JSON.stringify(res.body)).not.toContain(contributor.name);
  });

  it('groups of 5 or more get participation as counts only', async () => {
    const app = premiumApp();
    const { controller, contributor, groupId } = await seedGroup(app, { agenda: 'Town hall' });
    await addMembers(groupId, 3);
    await upsertSubscription(testPool(), { userId: controller.id, provider: 'manual', status: 'active', expiresAt: null });
    await publish(groupId, 'When is the next town hall', contributor.id);
    await publish(groupId, 'Town hall questions should be collected earlier', null);
    await publish(groupId, 'Please share the town hall agenda', null);
    const res = await api.get(app, `/groups/${groupId}/insights`, controller.token);
    expect(res.body).toMatchObject({
      member_count: 5,
      breakdowns_available: true,
      participants: 1,
      anonymous_messages: 2,
    });
    expect(Array.isArray(res.body.busiest_hours)).toBe(true);
  });

  it('top words skip filler and count each message once', () => {
    expect(
      topWords([
        'deadline deadline deadline is close',
        'the deadline moved again',
        'please share the plan',
      ]),
    ).toEqual([{ word: 'deadline', count: 2 }]);
  });
});

describe('premium badge in the feed (API.md 74)', () => {
  it('a Premium author shows premium: true on questions and answers', async () => {
    const app = premiumApp();
    const author = await registerUser(app, 'Badge Author', 'badge@example.com');
    const reader = await registerUser(app, 'Reader', 'reader-badge@example.com');
    const post = await api.post(app, '/posts', author.token, { content: 'How do we keep retros short?' });
    expect(post.body.author.premium).toBe(false);
    await upsertSubscription(testPool(), { userId: author.id, provider: 'manual', status: 'active', expiresAt: null });
    const seen = await api.get(app, `/posts/${post.body.id}`, reader.token);
    expect(seen.body.author).toEqual({ id: author.id, name: 'Badge Author', premium: true });
    const answer = await api.post(app, `/posts/${post.body.id}/comments`, author.token, { content: 'Use a timer.' });
    expect(answer.body.author.premium).toBe(true);
  });
});
