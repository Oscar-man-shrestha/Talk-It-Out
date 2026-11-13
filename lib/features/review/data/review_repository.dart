import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';
import 'package:talk_it_out/features/review/data/review_result.dart';

abstract class ReviewRepository {
  Future<PageResult<RawMessage>> listQueue(
    String groupId, {
    int? limit,
    String? cursor,
  });

  Future<RawMessage> getMessage(String groupId, String messageId);

  Future<AcceptResult> accept(String messageId);

  Future<RejectResult> reject(String messageId);

  /// Asks the AI for a fresh rewrite of a pending message (controller only).
  Future<void> requestRewrite(String messageId);
}
