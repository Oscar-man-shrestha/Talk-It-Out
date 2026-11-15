import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/discovery_providers.dart';
import 'package:talk_it_out/features/discovery/person_profile_screen.dart';
import 'package:talk_it_out/features/feed/feed_providers.dart';

/// People you blocked (`API.md` 59).
final blockedPeopleProvider = FutureProvider.autoDispose<List<PersonResult>>(
  (ref) => ref.watch(discoveryRepositoryProvider).blockedPeople(),
);

void _refreshAfterSafetyChange(WidgetRef ref, String userId) {
  ref.invalidate(personProvider(userId));
  ref.invalidate(personPostsProvider(userId));
  ref.invalidate(blockedPeopleProvider);
  ref.invalidate(feedProvider);
  ref.invalidate(forYouProvider);
}

/// Asks first, then blocks. Returns true when blocked.
Future<bool> confirmAndBlock(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String name,
) async {
  final first = name.split(' ').first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Block $first?'),
      content: Text(
        "$first won't be able to find you, see your questions or profile, comment on your "
        "questions, or add you to groups, and you won't see theirs. Groups you already share "
        "are not changed. $first is not told.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-block'),
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(discoveryRepositoryProvider).block(userId);
    _refreshAfterSafetyChange(ref, userId);
    messenger.showSnackBar(
      SnackBar(backgroundColor: Brand.ink, content: Text('$first is blocked.')),
    );
    return true;
  } on RepositoryException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

Future<void> unblockPerson(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String name,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(discoveryRepositoryProvider).unblock(userId);
    _refreshAfterSafetyChange(ref, userId);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Brand.ink,
        content: Text('${name.split(' ').first} is unblocked.'),
      ),
    );
  } on RepositoryException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// "Report question": pick a reason; the question disappears for you at
/// once (with Undo). Returns true when reported.
Future<bool> showReportQuestionSheet(
  BuildContext context,
  WidgetRef ref,
  String postId,
) async {
  final reason = await showModalBottomSheet<ReportReason>(
    context: context,
    backgroundColor: Brand.canvas,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 2),
            child: Text(
              'Report question',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Brand.ink,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
            child: Text(
              "Why are you reporting it? The author isn't told who reported.",
              style: TextStyle(fontSize: 12.5, color: Brand.inkSoft),
            ),
          ),
          for (final r in ReportReason.values)
            ListTile(
              key: ValueKey('report-${r.id}'),
              title: Text(r.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(ctx).pop(r),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(discoveryRepositoryProvider);
  try {
    await repo.reportPost(postId, reason);
    ref.invalidate(feedProvider);
    ref.invalidate(forYouProvider);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Brand.ink,
        content: Text(
          reason == ReportReason.selfHarm
              ? "Thanks for reporting. If someone is in danger, contact local emergency services now."
              : "Thanks for reporting. You won't see this question again.",
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () async {
            await repo.withdrawReport(postId);
            ref.invalidate(feedProvider);
            ref.invalidate(forYouProvider);
          },
        ),
      ),
    );
    return true;
  } on RepositoryException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Profile → Blocked people.
class BlockedPeopleScreen extends ConsumerWidget {
  const BlockedPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedPeopleProvider);
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(
        backgroundColor: Brand.canvas,
        surfaceTintColor: Colors.transparent,
        // Opened from a link there is nothing to pop: go somewhere useful.
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: const Text(
          'Blocked people',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: blocked.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(blockedPeopleProvider),
            child: const Text('Could not load. Try again'),
          ),
        ),
        data: (people) => people.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    "You haven't blocked anyone. Block someone from the ⋯ menu on their profile.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Brand.inkSoft),
                  ),
                ),
              )
            : ListView(
                children: [
                  for (final p in people)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Brand.accentSoft,
                        child: Text(
                          p.initials,
                          style: const TextStyle(
                            color: Brand.accentInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(p.name),
                      subtitle: p.handle == null ? null : Text('@${p.handle}'),
                      trailing: OutlinedButton(
                        key: ValueKey('unblock-${p.id}'),
                        onPressed: () =>
                            unblockPerson(context, ref, p.id, p.name),
                        child: const Text('Unblock'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
