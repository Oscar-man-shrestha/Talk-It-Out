-- More notification events (API.md 73): your message was published, a new
-- member joined your group, new likes on your question.

ALTER TABLE notifications DROP CONSTRAINT notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
  type IN ('message_pending_review', 'message_rejected', 'mentioned', 'question_answered',
           'answer_best', 'group_invitation', 'message_published', 'member_joined',
           'question_liked')
);
ALTER TABLE notifications DROP CONSTRAINT notifications_target_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_target_check CHECK (
  (type IN ('question_answered', 'answer_best', 'question_liked') AND post_id IS NOT NULL)
  OR (type NOT IN ('question_answered', 'answer_best', 'question_liked') AND group_id IS NOT NULL)
);
