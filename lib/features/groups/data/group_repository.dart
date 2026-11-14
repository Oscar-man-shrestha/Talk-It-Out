import 'dart:typed_data';

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
    String? attachmentId,
    String? replyToId,
  });

  Future<PublishedMessage> sendControllerMessage(
    String groupId, {
    required String text,
    String? attachmentId,
    String? replyToId,
  });

  /// The page of messages just before [before] (null: the latest), in
  /// reading order, with a cursor for the next older page (API.md 50).
  Future<MessageHistoryPage> listMessagesBefore(
    String groupId, {
    String? before,
    int? limit,
  });

  /// Published messages containing [query], newest first.
  Future<List<PublishedMessage>> searchMessages(String groupId, String query);

  /// Asks the AI to rewrite a draft before sending (API.md 50). Returns the
  /// preview id; nothing reaches the controller yet.
  Future<String> requestPreview(
    String groupId, {
    required String text,
    required bool isAnonymous,
  });

  /// The preview's wording once ready (null while the AI is working).
  Future<RewritePreview> getPreview(String groupId, String previewId);

  /// Sends a previewed draft for review.
  Future<SentMessage> sendPreview(
    String groupId,
    String previewId, {
    required bool isAnonymous,
    String? attachmentId,
    String? replyToId,
  });

  Future<void> discardPreview(String groupId, String previewId);

  /// Takes back your own message while it is still waiting for review.
  Future<void> withdrawMessage(String messageId);

  /// Controller: pin or unpin a message.
  Future<void> setPinned(
    String groupId,
    String messageId, {
    required bool pinned,
  });

  /// Controller: post a poll (2 to 6 options).
  Future<PublishedMessage> createPoll(
    String groupId, {
    required String question,
    required List<String> options,
  });

  /// Votes for [optionIndex], or removes your vote when it is null.
  Future<void> vote(String groupId, String pollId, int? optionIndex);

  /// Uploads a chat image (API.md 49). The server removes hidden photo
  /// details (location, camera, author) before storing it. Returns the id
  /// to send with the message.
  Future<String> uploadAttachment(
    String groupId, {
    required Uint8List bytes,
    required String filename,
  });

  /// The image bytes, if the caller may see them.
  Future<Uint8List> fetchAttachment(String groupId, String attachmentId);

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

typedef MessageHistoryPage = ({
  List<PublishedMessage> items,
  String? prevCursor,
});

/// Where a rewrite preview stands. [failed] means the AI could not reword
/// it; the draft can still be sent as is for the controller to judge.
typedef RewritePreview = ({bool ready, bool failed, String? rewrittenText});
