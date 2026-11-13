import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/group_member.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/features/groups/data/message_reactions.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/data/sent_message.dart';

abstract class GroupRepository {
  Future<PageResult<Group>> listGroups({int? limit, String? cursor});

  Future<Group> createGroup({required String agenda});

  Future<Group> getGroup(String groupId);

  Future<PageResult<GroupMember>> listMembers(
    String groupId, {
    int? limit,
    String? cursor,
  });

  Future<PageResult<PublishedMessage>> listMessages(
    String groupId, {
    int? limit,
    String? cursor,
  });

  Future<SentMessage> sendMessage(
    String groupId, {
    required String text,
    required bool isAnonymous,
  });

  Future<PublishedMessage> sendControllerMessage(
    String groupId, {
    required String text,
  });

  Future<void> deleteMessage(String groupId, String messageId);

  Future<MessageReactions> getReactions(String groupId, String messageId);

  /// Adds the caller's [emoji] reaction, or removes it if already present.
  Future<MessageReactions> toggleReaction(
    String groupId,
    String messageId, {
    required String emoji,
  });

  Future<void> removeMember(String groupId, String userId);

  Future<GroupMember> addMember(
    String groupId, {
    required String username,
    GroupRole role = GroupRole.contributor,
  });

  Future<void> leaveGroup(String groupId);

  Future<PageResult<MyMessageStatus>> listMyMessages(
    String groupId, {
    int? limit,
    String? cursor,
  });
}
