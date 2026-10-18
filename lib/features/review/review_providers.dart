import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';

typedef ReviewKey = ({String groupId, String messageId});

class ReviewQueueNotifier extends AsyncNotifier<List<RawMessage>> {
  ReviewQueueNotifier(this.groupId);

  final String groupId;

  @override
  Future<List<RawMessage>> build() async {
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
    return ref
        .watch(reviewRepositoryProvider)
        .getMessage(key.groupId, key.messageId);
  }
}

final reviewDetailProvider =
    AsyncNotifierProvider.family<ReviewDetailNotifier, RawMessage, ReviewKey>(
      ReviewDetailNotifier.new,
    );
