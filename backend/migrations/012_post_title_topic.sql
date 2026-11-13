-- 012_post_title_topic.sql — questions in the public feed get a title and
-- a topic (API.md 42). Both optional so existing posts stay valid.
ALTER TABLE posts
  ADD COLUMN title text CHECK (title IS NULL OR char_length(title) BETWEEN 1 AND 150),
  ADD COLUMN topic text CHECK (
    topic IS NULL OR topic IN (
      'workplace_policy', 'engineering', 'leadership', 'compensation', 'safety', 'culture'
    )
  );

CREATE INDEX posts_topic_idx ON posts (topic) WHERE topic IS NOT NULL;
