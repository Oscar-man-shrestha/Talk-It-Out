import 'dart:typed_data';

import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';

/// In-memory link between send, review, and the group chat.
///
/// Widgets never read [outgoing]. Only the mock repositories do.
class MockOutgoing {
  MockOutgoing({
    required this.id,
    required this.groupId,
    required this.text,
    required this.isAnonymous,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    this.attachmentId,
  });

  final String id;
  final String groupId;
  final String text;
  final bool isAnonymous;
  final String senderId;
  final String senderName;
  final DateTime createdAt;
  final String? attachmentId;
}

class MockMessageBridge {
  final List<PublishedMessage> published = [];
  final List<MyMessageStatus> mine = [];
  final List<MockOutgoing> outgoing = [];

  /// Uploaded chat images by id (mock storage).
  final Map<String, Uint8List> attachments = {};
}
