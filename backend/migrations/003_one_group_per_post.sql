-- 003_one_group_per_post.sql — a post can be converted into at most one group.
-- 002 guarded one group -> many posts (posts.created_group_id UNIQUE); this
-- guards the other direction, one post -> many groups.
CREATE UNIQUE INDEX one_group_per_source_post
  ON groups (source_post_id) WHERE source_post_id IS NOT NULL;
