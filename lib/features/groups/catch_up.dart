import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/api/api_guard.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/groups/data/group_repository.dart';

/// "Catch up": a summary of what a group has been saying (`API.md` 63).
/// Built from approved messages only, and never names anyone.
class CatchUp {
  const CatchUp({
    required this.messageCount,
    this.highlights = const [],
    this.openQuestions = const [],
    this.keyTopics = const [],
    this.themes = const [],
  });

  factory CatchUp.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => [
      if (v is List)
        for (final x in v)
          if (x is String) x,
    ];
    return CatchUp(
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      highlights: strings(json['highlights']),
      openQuestions: strings(json['open_questions']),
      keyTopics: strings(json['key_topics']),
      themes: [
        if (json['themes'] case final List list)
          for (final t in list)
            if (t is Map) '${t['label'] ?? ''}'.trim(),
      ],
    );
  }

  final int messageCount;
  final List<String> highlights;
  final List<String> openQuestions;
  final List<String> keyTopics;

  /// Interest labels, e.g. "Engineering & tech".
  final List<String> themes;

  bool get isEmpty => highlights.isEmpty;
}

abstract interface class CatchUpRepository {
  Future<CatchUp> summarize(String groupId);
}

class ApiCatchUpRepository implements CatchUpRepository {
  ApiCatchUpRepository(this._dio);

  final Dio _dio;

  @override
  Future<CatchUp> summarize(String groupId) {
    return guardApi(() async {
      final response = await _dio.get('/groups/$groupId/summary');
      return CatchUp.fromJson(asJsonMap(response.data));
    });
  }
}

/// Demo build: the longest recent messages stand in for the server's
/// TextRank summary.
class MockCatchUpRepository implements CatchUpRepository {
  MockCatchUpRepository(this._groups);

  final GroupRepository _groups;

  @override
  Future<CatchUp> summarize(String groupId) async {
    final messages = (await _groups.listMessages(groupId, limit: 60)).items;
    final texts = [
      for (final m in messages)
        if (m.text.trim().split(RegExp(r'\s+')).length >= 4) m.text.trim(),
    ];
    final ranked = [...texts]..sort((a, b) => b.length.compareTo(a.length));
    final top = ranked.where((t) => !t.endsWith('?')).take(3).toSet();
    return CatchUp(
      messageCount: messages.length,
      highlights: [
        for (final t in texts)
          if (top.contains(t)) t,
      ],
      openQuestions: [
        for (final t in texts)
          if (t.endsWith('?')) t,
      ].take(2).toList(),
    );
  }
}

final catchUpRepositoryProvider = Provider<CatchUpRepository>((ref) {
  if (ref.watch(appConfigProvider).useMock) {
    return MockCatchUpRepository(ref.watch(groupRepositoryProvider));
  }
  return ApiCatchUpRepository(ref.watch(dioProvider));
});

final _catchUpProvider = FutureProvider.autoDispose.family<CatchUp, String>(
  (ref, groupId) => ref.watch(catchUpRepositoryProvider).summarize(groupId),
);

Future<void> showCatchUpSheet(BuildContext context, String groupId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Brand.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => CatchUpSheet(groupId: groupId),
  );
}

class CatchUpSheet extends ConsumerWidget {
  const CatchUpSheet({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_catchUpProvider(groupId));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: Brand.ink),
                SizedBox(width: 8),
                Text(
                  'Catch up',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Brand.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'The points this group keeps coming back to, picked automatically. Names are never included.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Brand.inkSoft,
              ),
            ),
            const SizedBox(height: 14),
            summary.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Text(
                e is RepositoryException
                    ? e.message
                    : 'Could not make a summary right now.',
                style: const TextStyle(color: Brand.inkSoft),
              ),
              data: (s) => s.isEmpty
                  ? const Text(
                      'Not enough has been said yet to summarise. Check back after a few more messages.',
                      key: ValueKey('catch-up-empty'),
                      style: TextStyle(fontSize: 14, color: Brand.inkSoft),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From the last ${s.messageCount} messages',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Brand.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final (i, h) in s.highlights.indexed)
                          _Bullet(h, key: ValueKey('catch-up-highlight-$i')),
                        if (s.openQuestions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Still open',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final q in s.openQuestions)
                            _Bullet(q, icon: Icons.help_outline),
                        ],
                        if (s.keyTopics.isNotEmpty || s.themes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final t in [...s.themes, ...s.keyTopics])
                                Chip(
                                  label: Text(
                                    t,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Brand.border),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {this.icon = Icons.circle, super.key});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: icon == Icons.circle ? 7 : 1,
              right: 8,
            ),
            child: Icon(
              icon,
              size: icon == Icons.circle ? 6 : 16,
              color: Brand.inkSoft,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Brand.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
