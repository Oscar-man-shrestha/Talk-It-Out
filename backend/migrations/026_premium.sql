-- Premium (docs/PREMIUM_PLAN.md, API.md 71). Who is Premium is decided here,
-- never by the app. Billing data never holds message text.

CREATE TABLE subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- manual: granted by the founder (pilots, testing); revenuecat: App Store
  -- or Google Play through RevenueCat; razorpay: web (later).
  provider text NOT NULL CHECK (provider IN ('manual', 'revenuecat', 'razorpay')),
  product_id text NOT NULL DEFAULT 'premium_monthly',
  -- active: paid and renewing; grace: a renewal payment failed, access kept
  -- while the store retries; cancelled: will not renew, access until
  -- expires_at; expired: no access.
  status text NOT NULL CHECK (status IN ('active', 'grace', 'cancelled', 'expired')),
  -- NULL: no end date (manual grants only).
  expires_at timestamptz,
  store text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider)
);

-- Each provider event is applied once (webhooks are retried).
CREATE TABLE billing_events (
  id text PRIMARY KEY,
  provider text NOT NULL,
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  type text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
