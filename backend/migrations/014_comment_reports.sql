-- Reports on feed comments. One report per person per comment. A report
-- never hides anything by itself: the question's author sees how many
-- people reported a comment on their question and may remove it.
CREATE TABLE comment_reports (
  comment_id uuid NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (comment_id, reporter_id)
);
CREATE INDEX comment_reports_reporter_idx ON comment_reports (reporter_id);

-- Live update for the question's page when a comment is reported or a
-- report is withdrawn (the feed event carries only the post id).
CREATE OR REPLACE FUNCTION tio_comment_report_changed() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  pid uuid;
BEGIN
  SELECT post_id INTO pid FROM comments
  WHERE id = CASE WHEN TG_OP = 'DELETE' THEN OLD.comment_id ELSE NEW.comment_id END;
  IF pid IS NOT NULL THEN
    PERFORM tio_notify(jsonb_build_object('t', 'feed', 'p', pid));
  END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER comment_reports_notify AFTER INSERT OR DELETE ON comment_reports
  FOR EACH ROW EXECUTE FUNCTION tio_comment_report_changed();
