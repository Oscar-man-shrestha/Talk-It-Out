-- 004_performance_indexes.sql — indexes found missing by auditing the
-- hot queries. Existing indexes already cover: the review queue and
-- author lookups (raw_messages_group_status_created_idx,
-- raw_messages_author_idx), published chat by group+time
-- (published_messages_group_time_idx), posts newest-first
-- (posts_order_idx), comments by post (comments_post_order_idx), and
-- post_likes via the primary-key prefix.

-- Stub + internal pipeline claim: WHERE kind + status + run_after.
CREATE INDEX jobs_kind_status_run_after_idx ON jobs (kind, status, run_after);

-- Unread notifications: WHERE recipient_id AND read_at IS NULL.
CREATE INDEX notifications_unread_idx ON notifications (recipient_id)
  WHERE read_at IS NULL;

-- Groups list per member: group_members is keyed (group_id, user_id);
-- the reverse lookup by user_id had no index.
CREATE INDEX group_members_user_idx ON group_members (user_id);
