-- Razorpay web subscriptions (API.md 75): the provider's subscription id,
-- so webhooks and cancellation find the right row. No payment details are
-- stored here; Razorpay keeps them.
ALTER TABLE subscriptions ADD COLUMN external_id text;
CREATE UNIQUE INDEX subscriptions_provider_external_id
  ON subscriptions (provider, external_id)
  WHERE external_id IS NOT NULL;
