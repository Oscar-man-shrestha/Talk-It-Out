import 'package:json_annotation/json_annotation.dart';

/// Unknown roles become [contributor], never [controller].
@JsonEnum()
enum GroupRole {
  @JsonValue('controller')
  controller,
  @JsonValue('contributor')
  contributor,
}

@JsonEnum()
enum MessageStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('accepted')
  accepted,
  @JsonValue('rejected')
  rejected,
}

@JsonEnum()
enum PipelineStatus {
  @JsonValue('queued')
  queued,
  @JsonValue('processing')
  processing,
  @JsonValue('done')
  done,
  @JsonValue('failed')
  failed,
}

@JsonEnum()
enum RelevanceLabel {
  @JsonValue('relevant')
  relevant,
  @JsonValue('borderline')
  borderline,
  @JsonValue('off_topic')
  offTopic,
}

@JsonEnum()
enum NotificationType {
  @JsonValue('message_rejected')
  messageRejected,
  @JsonValue('message_pending_review')
  messagePendingReview,
  @JsonValue('mentioned')
  mentioned,
  @JsonValue('question_answered')
  questionAnswered,
  @JsonValue('answer_best')
  answerBest,
  @JsonValue('group_invitation')
  groupInvitation,
  @JsonValue('message_published')
  messagePublished,
  @JsonValue('member_joined')
  memberJoined,
  @JsonValue('question_liked')
  questionLiked,
  @JsonValue('unknown')
  unknown,
}
