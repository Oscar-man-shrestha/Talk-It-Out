import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/mock/run_mock.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/group_member.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/groups/data/group_repository.dart';
import 'package:talk_it_out/features/groups/data/message_reactions.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/data/sent_message.dart';

class MockGroupRepository implements GroupRepository {
  MockGroupRepository(this._controls, this._board, this._bridge) {
    if (_bridge.published.isEmpty) {
      _bridge.published.addAll(_seedMessages());
    }
    if (_bridge.mine.isEmpty) _bridge.mine.addAll(_seedMine());
  }

  final MockControls _controls;
  final MockBoard _board;
  final MockMessageBridge _bridge;
  var _nextMessage = 400;

  /// Sample reactions for the seeded chat. Counts only, never identities.
  final Map<String, MessageReactions> _reactions = {
    'pm10': const MessageReactions(
      messageId: 'pm10',
      counts: {'❤️': 2, '👍': 3},
      mine: {'❤️'},
    ),
    'pm11': const MessageReactions(
      messageId: 'pm11',
      counts: {'🔥': 4, '👏': 2},
    ),
    'pm12': const MessageReactions(
      messageId: 'pm12',
      counts: {'💡': 3, '👍': 1},
    ),
  };

  @override
  Future<PageResult<Group>> listGroups({int? limit, String? cursor}) {
    return runMock(_controls, () {
      return slicePage(
        List<Group>.of(_board.groups),
        limit: limit,
        cursor: cursor,
      );
    });
  }

  @override
  Future<Group> createGroup({required String agenda}) {
    return runMock(_controls, () {
      final clean = agenda.trim();
      if (clean.isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.agendaRequired,
        );
      }
      final id = 'g${_board.nextGroupNumber}';
      _board.nextGroupNumber += 1;
      final group = Group(
        id: id,
        agenda: clean,
        controllerId: MockIds.priya,
        createdAt: DateTime.now().toUtc(),
        myRole: GroupRole.controller,
        pendingCount: 0,
      );
      _board.groups.insert(0, group);
      _board.membersByGroup[id] = const [
        GroupMember(
          userId: MockIds.priya,
          name: 'Priya',
          role: GroupRole.controller,
        ),
      ];
      return group;
    });
  }

  @override
  Future<Group> getGroup(String groupId) {
    return runMock(_controls, () => _requireGroup(groupId));
  }

  @override
  Future<PageResult<GroupMember>> listMembers(
    String groupId, {
    int? limit,
    String? cursor,
  }) {
    return runMock(_controls, () {
      _requireGroup(groupId);
      final members = _board.membersByGroup[groupId] ?? const <GroupMember>[];
      return slicePage(
        List<GroupMember>.of(members),
        limit: limit,
        cursor: cursor,
      );
    });
  }

  @override
  Future<PageResult<PublishedMessage>> listMessages(
    String groupId, {
    int? limit,
    String? cursor,
  }) {
    return runMock(_controls, () {
      _requireGroup(groupId);
      final messages = _bridge.published.where(
        (message) => message.groupId == groupId,
      );
      return slicePage(messages.toList(), limit: limit, cursor: cursor);
    });
  }

  @override
  Future<SentMessage> sendMessage(
    String groupId, {
    required String text,
    required bool isAnonymous,
  }) {
    return runMock(_controls, () {
      final group = _requireGroup(groupId);
      if (group.myRole == GroupRole.controller) {
        throw const RepositoryException(
          code: 'forbidden',
          message: AppStrings.notAllowed,
        );
      }
      if (text.trim().isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.messageRequired,
        );
      }
      final createdAt = DateTime.now().toUtc();
      final id = 'm$_nextMessage';
      _nextMessage += 1;
      final clean = text.trim();
      _bridge.mine.add(
        MyMessageStatus(
          id: id,
          groupId: groupId,
          status: MessageStatus.pending,
          isAnonymous: isAnonymous,
          createdAt: createdAt,
        ),
      );
      _bridge.outgoing.add(
        MockOutgoing(
          id: id,
          groupId: groupId,
          text: clean,
          isAnonymous: isAnonymous,
          senderId: MockIds.priya,
          senderName: 'Priya',
          createdAt: createdAt,
        ),
      );
      return SentMessage(
        id: id,
        groupId: groupId,
        status: MessageStatus.pending,
        createdAt: createdAt,
      );
    });
  }

  @override
  Future<PublishedMessage> sendControllerMessage(
    String groupId, {
    required String text,
  }) {
    return runMock(_controls, () {
      final group = _requireGroup(groupId);
      if (group.myRole != GroupRole.controller) {
        throw const RepositoryException(
          code: 'forbidden',
          message: 'Only controllers can send controller announcements.',
        );
      }
      final clean = text.trim();
      if (clean.isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.messageRequired,
        );
      }
      final id = 'pm${_nextMessage++}';
      final msg = PublishedMessage(
        id: id,
        groupId: groupId,
        text: clean,
        displaySender: const DisplaySender(
          id: MockIds.priya,
          name: 'Priya (Controller)',
        ),
        publishedAt: DateTime.now().toUtc(),
      );
      _bridge.published.add(msg);
      return msg;
    });
  }

  @override
  Future<void> deleteMessage(String groupId, String messageId) {
    return runMock(_controls, () {
      _requireGroup(groupId);
      _bridge.published.removeWhere(
        (m) => m.id == messageId && m.groupId == groupId,
      );
      _reactions.remove(messageId);
    });
  }

  @override
  Future<MessageReactions> getReactions(String groupId, String messageId) {
    return runMock(_controls, () {
      _requireGroup(groupId);
      return _reactions[messageId] ?? MessageReactions(messageId: messageId);
    });
  }

  @override
  Future<MessageReactions> toggleReaction(
    String groupId,
    String messageId, {
    required String emoji,
  }) {
    return runMock(_controls, () {
      _requireGroup(groupId);
      if (!kReactionEmojis.contains(emoji)) {
        throw const RepositoryException(
          code: 'validation',
          message: AppStrings.reactionRequired,
        );
      }
      final current =
          _reactions[messageId] ?? MessageReactions(messageId: messageId);
      return _reactions[messageId] = current.toggled(emoji);
    });
  }

  @override
  Future<void> removeMember(String groupId, String userId) {
    return runMock(_controls, () {
      _requireGroup(groupId);
      final currentMembers = _board.membersByGroup[groupId];
      if (currentMembers != null) {
        _board.membersByGroup[groupId] = currentMembers
            .where((m) => m.userId != userId)
            .toList();
      }
    });
  }

  @override
  Future<GroupMember> addMember(
    String groupId, {
    required String username,
    GroupRole role = GroupRole.contributor,
  }) {
    return runMock(_controls, () {
      _requireGroup(groupId);
      final clean = username.trim().replaceAll('@', '');
      if (clean.isEmpty) {
        throw const RepositoryException(
          code: 'validation',
          message: 'Username cannot be empty.',
        );
      }
      final newMember = GroupMember(
        userId: 'u_${DateTime.now().millisecondsSinceEpoch}',
        name: clean,
        role: role,
      );
      final currentMembers =
          _board.membersByGroup[groupId] ?? const <GroupMember>[];
      _board.membersByGroup[groupId] = [...currentMembers, newMember];
      return newMember;
    });
  }

  @override
  Future<void> leaveGroup(String groupId) {
    return runMock(_controls, () {
      _requireGroup(groupId);
      final currentMembers = _board.membersByGroup[groupId];
      if (currentMembers != null) {
        _board.membersByGroup[groupId] = currentMembers
            .where((m) => m.userId != MockIds.priya)
            .toList();
      }
      _board.groups.removeWhere((g) => g.id == groupId);
    });
  }

  @override
  Future<PageResult<MyMessageStatus>> listMyMessages(
    String groupId, {
    int? limit,
    String? cursor,
  }) {
    return runMock(_controls, () {
      _requireGroup(groupId);
      final mine = _bridge.mine.where((message) => message.groupId == groupId);
      return slicePage(mine.toList(), limit: limit, cursor: cursor);
    });
  }

  Group _requireGroup(String groupId) {
    for (final group in _board.groups) {
      if (group.id == groupId) return group;
    }
    throw const RepositoryException(
      code: 'not_found',
      message: AppStrings.notFound,
    );
  }

  static List<PublishedMessage> _seedMessages() {
    const notes = MockIds.notesGroup;
    const priya = DisplaySender(id: MockIds.priya, name: 'Priya');
    const rohan = DisplaySender(id: MockIds.rohan, name: 'Rohan');
    const arhat = DisplaySender(id: MockIds.arhat, name: 'Arhat');
    PublishedMessage note(
      String id,
      int minute,
      String text,
      DisplaySender? sender,
    ) {
      return PublishedMessage(
        id: id,
        groupId: notes,
        text: text,
        displaySender: sender,
        publishedAt: DateTime.utc(2026, 10, 10, 12, minute),
      );
    }

    return [
      note(
        'pm1',
        0,
        'I suggest we keep a shared glossary for the NLP notes.',
        priya,
      ),
      note('pm2', 5, 'Could we revisit the sprint timeline?', null),
      note(
        'pm3',
        10,
        'The token example in section 2 needs a clearer explanation.',
        rohan,
      ),
      note('pm4', 15, 'I can draft the evaluation checklist next.', arhat),
      note(
        'pm5',
        20,
        'Let us separate preprocessing from the model notes.',
        priya,
      ),
      note('pm6', 25, 'The agenda should stay on annotation quality.', null),
      note('pm7', 30, 'I added three examples for intent preservation.', rohan),
      note(
        'pm8',
        35,
        'We still need a definition for borderline relevance.',
        arhat,
      ),
      note('pm9', 40, 'Please review the label names before Friday.', priya),
      note('pm10', 45, 'The dataset split is documented in the notes.', rohan),
      note('pm11', 50, 'I will bring a short demo of the rewrite step.', arhat),
      note(
        'pm12',
        55,
        'Contributors can send questions before the review.',
        priya,
      ),
      note(
        'pm13',
        60,
        'The glossary now includes pipeline status words.',
        rohan,
      ),
      note('pm14', 65, 'Next we should collect one off-topic example.', arhat),
      PublishedMessage(
        id: 'pm-d1',
        groupId: MockIds.dashboardGroup,
        text: 'The home chart should load without a full refresh.',
        displaySender: priya,
        publishedAt: DateTime.utc(2026, 10, 8, 11),
      ),
      PublishedMessage(
        id: 'pm-d2',
        groupId: MockIds.dashboardGroup,
        text: 'Could we label the filters more clearly?',
        publishedAt: DateTime.utc(2026, 10, 8, 11, 15),
      ),
    ];
  }

  static List<MyMessageStatus> _seedMine() {
    return [
      MyMessageStatus(
        id: 'm301',
        groupId: MockIds.notesGroup,
        status: MessageStatus.pending,
        isAnonymous: true,
        createdAt: DateTime.utc(2026, 10, 12, 17),
      ),
      MyMessageStatus(
        id: 'm302',
        groupId: MockIds.notesGroup,
        status: MessageStatus.accepted,
        isAnonymous: false,
        createdAt: DateTime.utc(2026, 10, 11, 8),
      ),
      MyMessageStatus(
        id: 'm303',
        groupId: MockIds.notesGroup,
        status: MessageStatus.rejected,
        isAnonymous: false,
        createdAt: DateTime.utc(2026, 10, 11, 9),
      ),
    ];
  }
}
