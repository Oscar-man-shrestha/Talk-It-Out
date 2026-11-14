import 'dart:math' as math;

import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/mock/run_mock.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/discovery/data/discovery_repository.dart';
import 'package:talk_it_out/features/discovery/data/interest_catalog.dart';
import 'package:talk_it_out/features/discovery/data/name_match.dart';
import 'package:talk_it_out/features/feed/data/feed_repository.dart';
import 'package:talk_it_out/features/feed/data/post.dart';

class _MockPerson {
  const _MockPerson(this.id, this.name, {this.handle, this.headline = ''});

  final String id;
  final String name;
  final String? handle;
  final String headline;
}

/// Demo people, interests and For You. The signed-in demo user is Priya.
class MockDiscoveryRepository implements DiscoveryRepository {
  MockDiscoveryRepository(this._controls, this._board, this._feed);

  final MockControls _controls;
  final MockBoard _board;
  final FeedRepository _feed;

  static const _people = <_MockPerson>[
    _MockPerson(
      MockIds.arhat,
      'Arhat Bajracharya',
      handle: 'arhat.b',
      headline: 'NLP researcher',
    ),
    _MockPerson(
      MockIds.rohan,
      'Rohan Shrestha',
      handle: 'rohan.s',
      headline: 'Backend engineer',
    ),
    _MockPerson('u3', 'Rohan Basnet', headline: 'Product designer'),
    _MockPerson(
      'u4',
      'Anita Gurung',
      handle: 'anita.g',
      headline: 'Engineering manager',
    ),
    _MockPerson('u5', 'Bikash Thapa', headline: 'Data analyst'),
    _MockPerson(
      'u6',
      'Katherine Rai',
      handle: 'kat.rai',
      headline: 'People & culture',
    ),
    _MockPerson('u7', 'Sujan Karki', handle: 'sujan', headline: 'Founder'),
    _MockPerson('u8', 'Maya Tamang', headline: 'UX researcher'),
    _MockPerson(
      'u10',
      'Alex Dev',
      handle: 'alex_dev',
      headline: 'Frontend engineer',
    ),
    _MockPerson(
      'u11',
      'Sophia Lee',
      handle: 'sophia_ai',
      headline: 'ML engineer',
    ),
  ];

  String? _handle;
  List<String> _interests = [];
  var _interestsChosen = false;
  var _personalized = true;
  final Set<String> _hidden = {};
  final Set<String> _opened = {};

  Set<String> _groupsOf(String userId) => {
    for (final entry in _board.membersByGroup.entries)
      if (entry.value.any((m) => m.userId == userId)) entry.key,
  };

  PersonResult _result(
    _MockPerson p,
    String? groupId, {
    String? match,
    String? reason,
  }) {
    final mine = _groupsOf(MockIds.priya);
    final shared = _groupsOf(p.id).intersection(mine).length;
    final inGroup =
        groupId != null &&
        (_board.membersByGroup[groupId] ?? const []).any(
          (m) => m.userId == p.id,
        );
    return PersonResult(
      id: p.id,
      name: p.name,
      handle: p.handle,
      headline: p.headline,
      sharedGroups: shared,
      inGroup: inGroup,
      match: match,
      reason: reason,
    );
  }

  @override
  Future<PeopleSearchResult> searchPeople(String query, {String? groupId}) {
    return runMock(_controls, () {
      final scored = <({PersonResult person, double score})>[];
      for (final p in _people) {
        final m = matchName(query, p.name, handle: p.handle);
        if (m == null) continue;
        final r = _result(p, groupId, match: m.kind);
        scored.add((
          person: r,
          score: m.score + 0.05 * math.min(r.sharedGroups, 3),
        ));
      }
      scored.sort((a, b) => b.score.compareTo(a.score));
      final items = [for (final s in scored.take(12)) s.person];
      return PeopleSearchResult(
        items: items,
        similarOnly:
            items.isNotEmpty &&
            items.every((p) => p.match != 'exact' && p.match != 'prefix'),
      );
    });
  }

  @override
  Future<List<PersonResult>> suggestedPeople({String? groupId}) {
    return runMock(_controls, () {
      final out = <PersonResult>[];
      for (final p in _people) {
        final r = _result(p, groupId);
        if (r.inGroup) continue;
        final reason = r.sharedGroups > 1
            ? 'In ${r.sharedGroups} of your groups'
            : r.sharedGroups == 1
            ? 'In one of your groups'
            : 'Suggested for you';
        out.add(_result(p, groupId, reason: reason));
      }
      out.sort((a, b) => b.sharedGroups.compareTo(a.sharedGroups));
      return out.take(8).toList();
    });
  }

  static final _handleRe = RegExp(
    r'^(?!\.)(?!.*\.\.)(?!.*\.$)[a-z0-9._]{3,30}$',
  );

  String? _problem(String h) {
    if (h.length < 3) return 'Handles need at least 3 characters.';
    if (h.length > 30) return 'Handles can have at most 30 characters.';
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(h)) {
      return 'Use only letters, numbers, dots and underscores.';
    }
    if (!_handleRe.hasMatch(h)) {
      return 'A dot cannot start or end a handle, or appear twice in a row.';
    }
    if (h == 'admin' || h == 'support') return 'That handle is reserved.';
    return null;
  }

  bool _taken(String h) => _people.any((p) => p.handle == h);

  List<String> _ideas() => [
    'priya',
    'priya.writes',
    'priya_42',
    'the.priya',
    'priya.team',
  ].where((h) => !_taken(h)).toList();

  @override
  Future<HandleState> getHandle() => runMock(
    _controls,
    () => HandleState(handle: _handle, suggestions: _ideas()),
  );

  @override
  Future<HandleCheck> checkHandle(String handle) {
    return runMock(_controls, () {
      final h = handle.trim().toLowerCase().replaceFirst(RegExp('^@+'), '');
      final problem =
          _problem(h) ?? (_taken(h) ? 'That handle is taken.' : null);
      return HandleCheck(
        handle: h,
        available: problem == null,
        problem: problem,
        suggestions: problem == null ? const [] : _ideas().take(4).toList(),
      );
    });
  }

  @override
  Future<String> setHandle(String handle) {
    return runMock(_controls, () {
      final h = handle.trim().toLowerCase().replaceFirst(RegExp('^@+'), '');
      final problem = _problem(h);
      if (problem != null) {
        throw RepositoryException(code: 'validation_error', message: problem);
      }
      if (_taken(h)) {
        throw const RepositoryException(
          code: 'handle_taken',
          message: 'That handle is taken.',
        );
      }
      _handle = h;
      return h;
    });
  }

  @override
  Future<InterestState> getInterests() => runMock(
    _controls,
    () => InterestState(
      picked: List.unmodifiable(_interests),
      chosen: _interestsChosen,
      available: kInterestCatalog,
      personalized: _personalized,
    ),
  );

  @override
  Future<void> setInterests(List<String> interests) {
    return runMock(_controls, () {
      _interests = interests.toSet().toList();
      _interestsChosen = true;
    });
  }

  @override
  Future<PageResult<RankedPost>> forYou({int? limit, String? cursor}) async {
    final posts = (await _feed.listPosts()).items;
    return runMock(_controls, () {
      final now = DateTime.now();
      final maxEngagement = posts.fold<int>(
        1,
        (m, p) => math.max(m, p.reactionCount + 2 * p.commentCount),
      );
      final ranked = <RankedPost>[];
      final scores = <String, double>{};
      for (final post in posts) {
        if (_hidden.contains(post.id)) continue;
        final topics = demoInterestsOf('${post.title ?? ''} ${post.content}');
        if (post.topic != null && !topics.contains(post.topic)) {
          topics.insert(0, post.topic!);
        }
        final match = _personalized
            ? topics.where(_interests.contains).toList()
            : <String>[];
        final engagement =
            (post.reactionCount + 2 * post.commentCount) / maxEngagement;
        final ageDays = now.difference(post.createdAt).inHours / 24;
        final fresh = math.exp(-math.max(0, ageDays) / 30);
        final mineBonus = post.author.id == MockIds.priya ? -0.3 : 0.0;
        scores[post.id] =
            (match.isEmpty ? 0 : 0.5) +
            0.3 * engagement +
            0.2 * fresh +
            mineBonus;
        final reason = match.isNotEmpty
            ? FeedReason(
                kind: 'interest',
                text:
                    'Because you follow ${interestOption(match.first)?.label ?? match.first}',
                interest: match.first,
              )
            : engagement >= 0.5
            ? const FeedReason(kind: 'popular', text: 'Popular right now')
            : const FeedReason(kind: 'new', text: 'New in the community');
        ranked.add(
          RankedPost(
            post: post,
            reason: reason,
            interests: topics.take(3).toList(),
          ),
        );
      }
      ranked.sort((a, b) => scores[b.post.id]!.compareTo(scores[a.post.id]!));
      return slicePage(ranked, limit: limit, cursor: cursor);
    });
  }

  @override
  Future<FeedSearchResult> searchPosts(String query) async {
    final posts = (await _feed.listPosts()).items;
    return runMock(_controls, () {
      final words = query
          .toLowerCase()
          .split(RegExp('[^a-z0-9]+'))
          .where((w) => w.length >= 2)
          .toList();
      if (words.isEmpty) return const FeedSearchResult(items: []);
      final vocab = <String>{
        for (final p in posts)
          ...'${p.title ?? ''} ${p.content}'
              .toLowerCase()
              .split(RegExp('[^a-z0-9]+'))
              .where((w) => w.length >= 3),
      };
      String? correction;
      final expanded = <String>[];
      for (final w in words) {
        if (vocab.any((v) => v.startsWith(w))) {
          expanded.add(w);
          continue;
        }
        String? best;
        var bestDist = w.length < 6 ? 2 : 3;
        for (final v in vocab) {
          final d = editDistance(w, v);
          if (d < bestDist) {
            bestDist = d;
            best = v;
          }
        }
        expanded.add(best ?? w);
        if (best != null) correction = best;
      }
      final scored = <({Post post, int hits})>[];
      for (final p in posts) {
        final text = '${p.title ?? ''} ${p.title ?? ''} ${p.content}'
            .toLowerCase();
        final hits = expanded.where(text.contains).length;
        if (hits > 0) scored.add((post: p, hits: hits));
      }
      scored.sort((a, b) => b.hits.compareTo(a.hits));
      return FeedSearchResult(
        items: [for (final s in scored) s.post],
        didYouMean: correction == null ? null : expanded.join(' '),
      );
    });
  }

  @override
  Future<TopicIdeas> classifyDraft({String? title, required String content}) {
    return runMock(_controls, () {
      final ids = demoInterestsOf('${title ?? ''} $title $content');
      const postTopics = {
        'workplace_policy',
        'engineering',
        'leadership',
        'compensation',
        'safety',
        'culture',
      };
      return TopicIdeas(
        topic: ids.where(postTopics.contains).firstOrNull,
        interests: [
          for (final (i, id) in ids.take(3).indexed)
            TopicIdea(
              id: id,
              label: interestOption(id)?.label ?? id,
              emoji: interestOption(id)?.emoji ?? '•',
              score: 1 - i * 0.3,
            ),
        ],
      );
    });
  }

  @override
  Future<void> sendSignal(String postId, String kind, {bool on = true}) {
    return runMock(_controls, () {
      final set = kind == 'not_interested' ? _hidden : _opened;
      if (on) {
        set.add(postId);
      } else {
        set.remove(postId);
      }
    });
  }

  @override
  Future<void> setPersonalized(bool on) =>
      runMock(_controls, () => _personalized = on);

  @override
  Future<List<SimilarQuestion>> similarQuestions({
    String? title,
    required String content,
  }) async {
    final query = '${title ?? ''} $content'.trim();
    if (query.length < 8) return const [];
    final result = await searchPosts(query);
    return [
      for (final post in result.items.take(3))
        SimilarQuestion(
          id: post.id,
          title: post.title ?? post.content,
          commentCount: post.commentCount,
        ),
    ];
  }
}
