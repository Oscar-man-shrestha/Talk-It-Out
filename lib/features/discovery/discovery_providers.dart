import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/realtime/realtime_client.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';

/// The signed-in person's feed interests (`API.md` 54).
class InterestsNotifier extends AsyncNotifier<InterestState> {
  @override
  Future<InterestState> build() =>
      ref.watch(discoveryRepositoryProvider).getInterests();

  Future<void> save(List<String> picked) async {
    await ref.read(discoveryRepositoryProvider).setInterests(picked);
    final current = state.value;
    state = AsyncData(
      InterestState(
        picked: List.unmodifiable(picked),
        chosen: true,
        available: current?.available ?? const [],
        personalized: current?.personalized ?? true,
      ),
    );
    ref.invalidate(forYouProvider);
  }

  /// Personalisation on or off. Off: For You shows what is popular and new,
  /// and nothing you do is recorded for ranking.
  Future<void> setPersonalized(bool on) async {
    await ref.read(discoveryRepositoryProvider).setPersonalized(on);
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        InterestState(
          picked: current.picked,
          chosen: current.chosen,
          available: current.available,
          personalized: on,
        ),
      );
    }
    ref.invalidate(forYouProvider);
  }
}

final interestsProvider =
    AsyncNotifierProvider<InterestsNotifier, InterestState>(
      InterestsNotifier.new,
    );

/// The ranked For You feed (`API.md` 55).
class ForYouNotifier extends AsyncNotifier<List<RankedPost>> {
  @override
  Future<List<RankedPost>> build() async {
    refreshOnLiveEvents(
      ref,
      (e) => e.type == 'feed',
      refresh: ref.invalidateSelf,
    );
    final page = await ref.watch(discoveryRepositoryProvider).forYou(limit: 50);
    return page.items;
  }

  /// Hides the post at once and tells the ranker. Returns an undo.
  Future<void Function()> notInterested(String postId) async {
    final before = state.value ?? const <RankedPost>[];
    state = AsyncData([
      for (final r in before)
        if (r.post.id != postId) r,
    ]);
    final repo = ref.read(discoveryRepositoryProvider);
    await repo.sendSignal(postId, 'not_interested');
    return () async {
      await repo.sendSignal(postId, 'not_interested', on: false);
      ref.invalidateSelf();
    };
  }
}

final forYouProvider = AsyncNotifierProvider<ForYouNotifier, List<RankedPost>>(
  ForYouNotifier.new,
);

/// The interest picker opens by itself once per app run for people who
/// have never seen it.
final interestPromptShownProvider = NotifierProvider<_Flag, bool>(_Flag.new);

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;

  void set() => state = true;
}
