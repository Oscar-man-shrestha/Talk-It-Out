-- 020_personalization_switch.sql: people can turn feed personalisation off
-- (API.md 57). When off, For You ignores interests and activity, and opens
-- are not recorded. "Not interested" still hides a post: it is an explicit
-- choice, not tracking.
ALTER TABLE users ADD COLUMN personalized boolean NOT NULL DEFAULT true;
