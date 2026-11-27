import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';
import 'package:talk_it_out/features/review/data/review_result.dart';

abstract class ReviewRepository {
  /// Pending messages by default. Pass [status] accepted or rejected for
  /// the controller's decided messages, most recent decision first.
  Future<PageResult<RawMessage>> listQueue(
    String groupId, {
    int? limit,
    String? cursor,
    MessageStatus status = MessageStatus.pending,
  });

  /// How many messages are pending, accepted and rejected in a group.
  Future<ReviewCounts> counts(String groupId);

  Future<RawMessage> getMessage(String groupId, String messageId);

  Future<AcceptResult> accept(String messageId);

  Future<RejectResult> reject(String messageId);

  /// Asks the AI for a fresh rewrite of a pending message (controller only).
  Future<void> requestRewrite(String messageId);
}

typedef ReviewCounts = ({int pending, int accepted, int rejected});
