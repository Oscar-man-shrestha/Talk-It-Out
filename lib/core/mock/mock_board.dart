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
  var nextGroupNumber = 3;

  static List<Group> _seedGroups() {
    return [
      Group(
        id: MockIds.notesGroup,
        agenda: 'Making NLP notes',
        controllerId: MockIds.arhat,
        createdAt: DateTime.utc(2026, 10, 1, 10),
        myRole: GroupRole.contributor,
      ),
      Group(
        id: MockIds.dashboardGroup,
        agenda: 'Dashboard improvements',
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
