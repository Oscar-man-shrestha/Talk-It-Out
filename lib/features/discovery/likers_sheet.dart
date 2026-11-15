import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/person_profile_screen.dart';

final _likersProvider = FutureProvider.autoDispose.family<LikersPage, String>(
  (ref, postId) => ref.watch(discoveryRepositoryProvider).likers(postId),
);

/// "Liked by", like Facebook and Instagram. Only for public feed
/// questions: group chat reactions stay counts only, to protect anonymity.
Future<void> showLikersSheet(BuildContext context, String postId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Brand.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => LikersSheet(postId: postId),
  );
}

class LikersSheet extends ConsumerWidget {
  const LikersSheet({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likers = ref.watch(_likersProvider(postId));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Brand.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.favorite, size: 18, color: Color(0xFFBA1A1A)),
                  SizedBox(width: 8),
                  Text(
                    'Liked by',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Brand.ink,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: likers.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    e is RepositoryException
                        ? e.message
                        : 'Could not load likes.',
                  ),
                ),
                data: (page) => page.items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No likes yet. Be the first.',
                          style: TextStyle(color: Brand.inkSoft),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          for (final p in page.items)
                            ListTile(
                              key: ValueKey('liker-${p.id}'),
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
                              title: Text(
                                p.reason == 'You' ? '${p.name} (you)' : p.name,
                              ),
                              subtitle: p.handle == null && p.headline.isEmpty
                                  ? null
                                  : Text(
                                      [
                                        if (p.handle != null) '@${p.handle}',
                                        if (p.headline.isNotEmpty) p.headline,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).pop();
                                openPerson(context, ref, p.id);
                              },
                            ),
                          if (page.total > page.items.length)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                              child: Text(
                                '${page.total - page.items.length} more not shown',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Brand.inkSoft,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
