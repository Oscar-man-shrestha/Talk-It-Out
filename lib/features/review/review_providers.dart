import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/realtime/realtime_client.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';
import 'package:talk_it_out/features/review/data/review_repository.dart';

typedef ReviewKey = ({String groupId, String messageId});

class ReviewQueueNotifier extends AsyncNotifier<List<RawMessage>> {
  ReviewQueueNotifier(this.groupId);

  final String groupId;

  @override
  Future<List<RawMessage>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'review' && e.groupId == groupId,
      refresh: ref.invalidateSelf,
    );
    final page = await ref.watch(reviewRepositoryProvider).listQueue(groupId);
    return page.items;
  }
}

final reviewQueueProvider =
    AsyncNotifierProvider.family<ReviewQueueNotifier, List<RawMessage>, String>(
      ReviewQueueNotifier.new,
    );

class ReviewDetailNotifier extends AsyncNotifier<RawMessage> {
  ReviewDetailNotifier(this.key);

  final ReviewKey key;

  @override
  Future<RawMessage> build() {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'review' && e.groupId == key.groupId,
      refresh: ref.invalidateSelf,
    );
    return ref
        .watch(reviewRepositoryProvider)
        .getMessage(key.groupId, key.messageId);
  }
}

final reviewDetailProvider =
    AsyncNotifierProvider.family<ReviewDetailNotifier, RawMessage, ReviewKey>(
      ReviewDetailNotifier.new,
    );

typedef ReviewHistoryKey = ({String groupId, MessageStatus status});

/// Accepted or rejected messages in a group, most recent decision first.
class ReviewHistoryNotifier extends AsyncNotifier<List<RawMessage>> {
  ReviewHistoryNotifier(this.key);

  final ReviewHistoryKey key;

  @override
  Future<List<RawMessage>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'review' && e.groupId == key.groupId,
      refresh: ref.invalidateSelf,
    );
    final page = await ref
        .watch(reviewRepositoryProvider)
        .listQueue(key.groupId, status: key.status);
    return page.items;
  }
}

final reviewHistoryProvider =
    AsyncNotifierProvider.family<
      ReviewHistoryNotifier,
      List<RawMessage>,
      ReviewHistoryKey
    >(ReviewHistoryNotifier.new);

/// Message counts for the Pending / Approved / Rejected tabs.
class ReviewCountsNotifier extends AsyncNotifier<ReviewCounts> {
  ReviewCountsNotifier(this.groupId);

  final String groupId;

  @override
  Future<ReviewCounts> build() {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'review' && e.groupId == groupId,
      refresh: ref.invalidateSelf,
    );
    return ref.watch(reviewRepositoryProvider).counts(groupId);
  }
}

final reviewCountsProvider =
    AsyncNotifierProvider.family<ReviewCountsNotifier, ReviewCounts, String>(
      ReviewCountsNotifier.new,
    );
