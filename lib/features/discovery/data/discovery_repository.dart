import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/discovery/data/discovery_models.dart';

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

  Future<PageResult<RankedPost>> forYou({int? limit, String? cursor});

  Future<FeedSearchResult> searchPosts(String query);

  Future<TopicIdeas> classifyDraft({String? title, required String content});

  /// open, save or not_interested. [on] false undoes it.
  Future<void> sendSignal(String postId, String kind, {bool on = true});
}
