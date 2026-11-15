import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/profile/data/profile.dart';

String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;
String? _strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;
int _int(Object? v) => v is num ? v.toInt() : 0;
List<Map<String, dynamic>> _maps(Object? v) => [
  if (v is List)
    for (final x in v)
      if (x is Map) Map<String, dynamic>.from(x),
];

/// One person in search results or suggestions (`API.md` 52).
class PersonResult {
  const PersonResult({
    required this.id,
    required this.name,
    this.handle,
    this.headline = '',
    this.avatarUrl,
    this.sharedGroups = 0,
    this.inGroup = false,
    this.match,
    this.reason,
  });

  factory PersonResult.fromJson(Map<String, dynamic> json) => PersonResult(
    id: _str(json['id']),
    name: _str(json['name'], 'Someone'),
    handle: _strOrNull(json['handle']),
    headline: _str(json['headline']),
    avatarUrl: _strOrNull(json['avatar_url']),
    sharedGroups: _int(json['shared_groups']),
    inGroup: json['in_group'] == true,
    match: _strOrNull(json['match']),
    reason: _strOrNull(json['reason']),
  );

  final String id;
  final String name;

  /// The chosen @handle, or null when the person has not picked one.
  final String? handle;
  final String headline;
  final String? avatarUrl;
  final int sharedGroups;
  final bool inGroup;

  /// exact, prefix, similar or sounds_like.
  final String? match;

  /// Why a suggestion is shown ("In 2 of your groups").
  final String? reason;

  /// The grey line under the name, like Instagram: handle, then context.
  String get subtitle {
    final parts = <String>[
      if (handle != null) '@$handle',
      if (headline.isNotEmpty) headline,
      if (reason != null)
        reason!
      else if (sharedGroups > 0)
        sharedGroups == 1
            ? 'In 1 of your groups'
            : 'In $sharedGroups of your groups',
    ];
    return parts.join(' · ');
  }

  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}

class PeopleSearchResult {
  const PeopleSearchResult({required this.items, this.similarOnly = false});

  factory PeopleSearchResult.fromJson(Map<String, dynamic> json) =>
      PeopleSearchResult(
        items: _maps(json['items']).map(PersonResult.fromJson).toList(),
        similarOnly: json['similar_only'] == true,
      );

  final List<PersonResult> items;

  /// Nothing matched exactly: the list shows similar names.
  final bool similarOnly;
}

/// One feed interest (`API.md` 54).
class InterestOption {
  const InterestOption({
    required this.id,
    required this.label,
    required this.icon,
    this.blurb = '',
  });

  factory InterestOption.fromJson(Map<String, dynamic> json) => InterestOption(
    id: _str(json['id']),
    label: _str(json['label']),
    icon: _str(json['icon']),
    blurb: _str(json['blurb']),
  );

  final String id;
  final String label;

  /// Icon name, drawn with `interestIcon` (never an emoji).
  final String icon;
  final String blurb;
}

class InterestState {
  const InterestState({
    required this.picked,
    required this.chosen,
    required this.available,
    this.personalized = true,
  });

  factory InterestState.fromJson(Map<String, dynamic> json) => InterestState(
    picked: [
      if (json['interests'] is List)
        for (final x in json['interests'] as List)
          if (x is String) x,
    ],
    chosen: json['chosen'] == true,
    available: _maps(json['available']).map(InterestOption.fromJson).toList(),
    personalized: json['personalized'] != false,
  );

  final List<String> picked;

  /// The person has been through the picker (even if they skipped it).
  final bool chosen;
  final List<InterestOption> available;

  /// False when the person turned personalisation off (`API.md` 57).
  final bool personalized;

  InterestOption? byId(String id) {
    for (final option in available) {
      if (option.id == id) return option;
    }
    return null;
  }
}

class HandleState {
  const HandleState({this.handle, this.suggestions = const []});

  factory HandleState.fromJson(Map<String, dynamic> json) => HandleState(
    handle: _strOrNull(json['handle']),
    suggestions: [
      if (json['suggestions'] is List)
        for (final x in json['suggestions'] as List)
          if (x is String) x,
    ],
  );

  final String? handle;
  final List<String> suggestions;
}

class HandleCheck {
  const HandleCheck({
    required this.handle,
    required this.available,
    this.problem,
    this.suggestions = const [],
  });

  factory HandleCheck.fromJson(Map<String, dynamic> json) => HandleCheck(
    handle: _str(json['handle']),
    available: json['available'] == true,
    problem: _strOrNull(json['problem']),
    suggestions: [
      if (json['suggestions'] is List)
        for (final x in json['suggestions'] as List)
          if (x is String) x,
    ],
  );

  final String handle;
  final bool available;
  final String? problem;
  final List<String> suggestions;
}

/// Why a post is in For You (`API.md` 55).
class FeedReason {
  const FeedReason({required this.kind, required this.text, this.interest});

  factory FeedReason.fromJson(Map<String, dynamic> json) => FeedReason(
    kind: _str(json['kind'], 'new'),
    text: _str(json['text']),
    interest: _strOrNull(json['interest']),
  );

  final String kind;
  final String text;
  final String? interest;
}

class RankedPost {
  const RankedPost({
    required this.post,
    this.reason,
    this.interests = const [],
  });

  factory RankedPost.fromJson(Map<String, dynamic> json) => RankedPost(
    post: Post.fromJson(json),
    reason: json['reason'] is Map
        ? FeedReason.fromJson(Map<String, dynamic>.from(json['reason'] as Map))
        : null,
    interests: [
      if (json['interests'] is List)
        for (final x in json['interests'] as List)
          if (x is String) x,
    ],
  );

  final Post post;
  final FeedReason? reason;
  final List<String> interests;
}

class FeedSearchResult {
  const FeedSearchResult({required this.items, this.didYouMean});

  factory FeedSearchResult.fromJson(Map<String, dynamic> json) =>
      FeedSearchResult(
        items: _maps(json['items']).map(Post.fromJson).toList(),
        didYouMean: _strOrNull(json['did_you_mean']),
      );

  final List<Post> items;
  final String? didYouMean;
}

class TopicIdea {
  const TopicIdea({
    required this.id,
    required this.label,
    required this.icon,
    required this.score,
  });

  final String id;
  final String label;
  final String icon;
  final double score;
}

class TopicIdeas {
  const TopicIdeas({this.topic, this.interests = const []});

  factory TopicIdeas.fromJson(Map<String, dynamic> json) => TopicIdeas(
    topic: _strOrNull(json['topic']),
    interests: [
      for (final m in _maps(json['interests']))
        TopicIdea(
          id: _str(m['id']),
          label: _str(m['label']),
          icon: _str(m['icon']),
          score: m['score'] is num ? (m['score'] as num).toDouble() : 0,
        ),
    ],
  );

  /// The suggested post topic (one of the six question topics), or null.
  final String? topic;
  final List<TopicIdea> interests;
}

/// An existing question that looks like a draft (`API.md` 58).
class SimilarQuestion {
  const SimilarQuestion({
    required this.id,
    required this.title,
    required this.commentCount,
  });

  factory SimilarQuestion.fromJson(Map<String, dynamic> json) =>
      SimilarQuestion(
        id: _str(json['id']),
        title: _str(json['title']),
        commentCount: _int(json['comment_count']),
      );

  final String id;

  /// The question's title, or the start of its text when it has none.
  final String title;
  final int commentCount;
}

/// Someone else's profile with what you share (`API.md` 59).
class PersonProfile {
  const PersonProfile({
    required this.profile,
    this.handle,
    this.sharedGroups = 0,
    this.blockedByMe = false,
  });

  factory PersonProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};
    return PersonProfile(
      profile: Profile.fromJson(json),
      handle: _strOrNull(user['handle']),
      sharedGroups: _int(json['shared_groups']),
      blockedByMe: json['blocked_by_me'] == true,
    );
  }

  final Profile profile;
  final String? handle;
  final int sharedGroups;

  /// You blocked them: only their name and an Unblock button are shown.
  final bool blockedByMe;
}

/// Why a question is reported (`API.md` 60).
enum ReportReason {
  spam('spam', 'Spam or ads'),
  harassment('harassment', 'Bullying or harassment'),
  hate('hate', 'Hate or discrimination'),
  selfHarm('self_harm', 'Self-harm or someone in danger'),
  misinformation('misinformation', 'False or misleading'),
  other('other', 'Something else');

  const ReportReason(this.id, this.label);

  final String id;
  final String label;
}

/// Who liked a question (`API.md` 64).
class LikersPage {
  const LikersPage({required this.items, required this.total});

  factory LikersPage.fromJson(Map<String, dynamic> json) => LikersPage(
    items: [
      for (final x in _maps(json['items']))
        PersonResult.fromJson({...x, if (x['is_me'] == true) 'reason': 'You'}),
    ],
    total: _int(json['total']),
  );

  final List<PersonResult> items;

  /// All likes, including people hidden from you by a block.
  final int total;
}
