import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';
import 'package:talk_it_out/features/feed/data/post.dart';

/// People search, @handles, interests and the personalised feed
/// (`API.md` 52 to 56).
abstract class DiscoveryRepository {
  /// Typo-tolerant people search. [groupId] marks who is already a member.
  Future<PeopleSearchResult> searchPeople(String query, {String? groupId});

  /// People you may know: from your groups and questions you liked.
  Future<List<PersonResult>> suggestedPeople({String? groupId});

  Future<HandleState> getHandle();

  Future<HandleCheck> checkHandle(String handle);

  /// Saves the @handle and returns it as stored (lowercase).
  Future<String> setHandle(String handle);

  Future<InterestState> getInterests();

  Future<void> setInterests(List<String> interests);

  /// Turns For You personalisation on or off (`API.md` 57).
  Future<void> setPersonalized(bool on);

  /// Questions like a draft, so people can read before asking (`API.md` 58).
  Future<List<SimilarQuestion>> similarQuestions({
    String? title,
    required String content,
  });

  Future<PageResult<RankedPost>> forYou({int? limit, String? cursor});

  Future<FeedSearchResult> searchPosts(String query);

  Future<TopicIdeas> classifyDraft({String? title, required String content});

  /// open, save or not_interested. [on] false undoes it.
  Future<void> sendSignal(String postId, String kind, {bool on = true});

  /// Someone's profile. Throws not_found when they blocked you.
  Future<PersonProfile> getPerson(String userId);

  /// Someone's public questions, newest first.
  Future<List<Post>> personPosts(String userId);

  Future<void> block(String userId);

  Future<void> unblock(String userId);

  Future<List<PersonResult>> blockedPeople();

  /// Hides the question from you; enough reports hide it for everyone.
  Future<void> reportPost(String postId, ReportReason reason);

  Future<void> withdrawReport(String postId);

  /// Who liked a question, you first (`API.md` 64).
  Future<LikersPage> likers(String postId);
}
