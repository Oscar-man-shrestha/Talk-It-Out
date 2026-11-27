import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/group_member.dart';

/// Groups and membership shared by the group and feed mocks.
///
/// This board does not store message text or controller-only review data.
class MockBoard {
  MockBoard() {
    groups.addAll(_seedGroups());
    membersByGroup.addAll(_seedMembers());
    spawnedPostIds.add(MockIds.dashboardPost);
  }

  final List<Group> groups = [];
  final Map<String, List<GroupMember>> membersByGroup = {};
  final Set<String> spawnedPostIds = {};

  /// People the demo user blocked, and questions they reported. The feed
  /// mock hides both, like the server (`API.md` 59, 60).
  final Set<String> blockedUserIds = {};

  /// The demo's "you". Someone who creates an account in the demo takes
  /// over the sample user's seat (MockIds.priya) under their own name, so
  /// the sample groups and questions are theirs to try.
  String meName = 'Priya';

  /// [name], or your current name when [id] is your seat.
  String nameOf(String id, String name) => id == MockIds.priya ? meName : name;
  final Set<String> reportedPostIds = {};
  var nextGroupNumber = 3;

  static List<Group> _seedGroups() {
    return [
      Group(
        id: MockIds.notesGroup,
        agenda: 'Making NLP notes',
        description: 'Shared notes and questions while we learn NLP together.',
        rules: 'Share sources. Ask anything; there are no silly questions.',
        controllerId: MockIds.arhat,
        createdAt: DateTime.utc(2026, 10, 1, 10),
        myRole: GroupRole.contributor,
      ),
      Group(
        id: MockIds.dashboardGroup,
        agenda: 'Dashboard improvements',
        description:
            'Feedback on the analytics dashboard before the next release.',
        rules:
            'Talk about problems, not people. One idea per message. '
            'Anonymous is fine.',
        controllerId: MockIds.priya,
        sourcePostId: MockIds.dashboardPost,
        createdAt: DateTime.utc(2026, 10, 5, 9, 30),
        myRole: GroupRole.controller,
        pendingCount: 6,
      ),
    ];
  }

  static Map<String, List<GroupMember>> _seedMembers() {
    return {
      MockIds.notesGroup: const [
        GroupMember(
          userId: MockIds.arhat,
          name: 'Arhat',
          role: GroupRole.controller,
        ),
        GroupMember(
          userId: MockIds.priya,
          name: 'Priya',
          role: GroupRole.contributor,
        ),
        GroupMember(
          userId: MockIds.rohan,
          name: 'Rohan',
          role: GroupRole.contributor,
        ),
      ],
      MockIds.dashboardGroup: const [
        GroupMember(
          userId: MockIds.priya,
          name: 'Priya',
          role: GroupRole.controller,
        ),
        GroupMember(
          userId: MockIds.rohan,
          name: 'Rohan',
          role: GroupRole.contributor,
        ),
      ],
    };
  }
}
