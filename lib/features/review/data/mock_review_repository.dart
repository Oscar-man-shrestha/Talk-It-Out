import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/mock/run_mock.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';
import 'package:talk_it_out/features/review/data/review_repository.dart';
import 'package:talk_it_out/features/review/data/review_result.dart';

class MockReviewRepository implements ReviewRepository {
  MockReviewRepository(this._controls, [MockMessageBridge? bridge])
    : _bridge = bridge ?? MockMessageBridge() {
    _messages.addAll(_seed());
  }

  final MockControls _controls;
  final MockMessageBridge _bridge;
  final List<RawMessage> _messages = [];

  @override
  Future<PageResult<RawMessage>> listQueue(
    String groupId, {
    int? limit,
    String? cursor,
    MessageStatus status = MessageStatus.pending,
  }) {
    return runMock(_controls, () {
      _requireControllerGroup(groupId);
      if (status != MessageStatus.pending) {
        final decided =
            _messages
                .where((m) => m.groupId == groupId && m.status == status)
                .toList()
              ..sort(
                (a, b) => (b.decidedAt ?? b.createdAt).compareTo(
                  a.decidedAt ?? a.createdAt,
                ),
              );
        return slicePage(decided, limit: limit, cursor: cursor);
      }
      final pending = [
        ..._messages.where(
          (message) =>
              message.groupId == groupId &&
              message.status == MessageStatus.pending,
        ),
        ..._bridge.outgoing
            .where((message) => message.groupId == groupId)
            .map(_fromOutgoing),
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return slicePage(pending, limit: limit, cursor: cursor);
    });
  }

  @override
  Future<ReviewCounts> counts(String groupId) {
    return runMock(_controls, () {
      _requireControllerGroup(groupId);
      int count(MessageStatus status) => _messages
          .where((m) => m.groupId == groupId && m.status == status)
          .length;
      final outgoing = _bridge.outgoing
          .where((message) => message.groupId == groupId)
          .length;
      return (
        pending: count(MessageStatus.pending) + outgoing,
        accepted: count(MessageStatus.accepted),
        rejected: count(MessageStatus.rejected),
      );
    });
  }

  /// Records a decision, keeping messages that came from the chat bridge
  /// so they show up in the decided tabs too.
  void _decide(RawMessage message, MessageStatus status) {
    final decided = message.copyWith(
      status: status,
      decidedAt: DateTime.now().toUtc(),
    );
    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      _messages[index] = decided;
    } else {
      _messages.add(decided);
    }
  }

  @override
  Future<RawMessage> getMessage(String groupId, String messageId) {
    return runMock(_controls, () {
      _requireControllerGroup(groupId);
      return _find(groupId, messageId);
    });
  }

  @override
  Future<AcceptResult> accept(String messageId) {
    return runMock(_controls, () {
      final message = _requireById(messageId);
      _requirePending(message);
      final rewrite = message.rewrittenText;
      if (message.pipelineStatus != PipelineStatus.done ||
          rewrite == null ||
          rewrite.trim().isEmpty) {
        throw const RepositoryException(
          code: 'conflict',
          message: AppStrings.acceptNoRewrite,
        );
      }
      final publishedId = 'pm-${message.id}';
      _publish(message, publishedId, rewrite.trim());
      _bridge.outgoing.removeWhere((item) => item.id == message.id);
      _decide(message, MessageStatus.accepted);
      _markMine(message.id, MessageStatus.accepted);
      return AcceptResult(
        id: message.id,
        status: MessageStatus.accepted,
        publishedMessageId: publishedId,
      );
    });
  }

  @override
  Future<RejectResult> reject(String messageId) {
    return runMock(_controls, () {
      final message = _requireById(messageId);
      _requirePending(message);
      _bridge.outgoing.removeWhere((item) => item.id == message.id);
      _decide(message, MessageStatus.rejected);
      _markMine(message.id, MessageStatus.rejected);
      return RejectResult(id: message.id, status: MessageStatus.rejected);
    });
  }

  @override
  Future<void> requestRewrite(String messageId) {
    return runMock(_controls, () {
      final message = _requireById(messageId);
      _requirePending(message);
      final index = _messages.indexWhere((item) => item.id == message.id);
      if (index >= 0) {
        // The mock "pipeline" answers at once with a tidied rewrite.
        _messages[index] = message.copyWith(
          pipelineStatus: PipelineStatus.done,
          rewrittenText: (message.rewrittenText ?? message.originalText).trim(),
        );
      }
    });
  }

  RawMessage _fromOutgoing(MockOutgoing item) {
    return RawMessage(
      id: item.id,
      groupId: item.groupId,
      senderId: item.senderId,
      senderName: item.senderName,
      originalText: item.text,
      rewrittenText: item.text,
      isAnonymous: item.isAnonymous,
      intentPreservationScore: 1,
      relevanceScore: 0.8,
      relevanceLabel: RelevanceLabel.relevant,
      pipelineStatus: PipelineStatus.done,
      status: MessageStatus.pending,
      createdAt: item.createdAt,
      attachmentId: item.attachmentId,
    );
  }

  RawMessage _find(String groupId, String messageId) {
    for (final message in _messages) {
      if (message.id == messageId && message.groupId == groupId) {
        return message;
      }
    }
    for (final item in _bridge.outgoing) {
      if (item.id == messageId && item.groupId == groupId) {
        return _fromOutgoing(item);
      }
    }
    throw const RepositoryException(
      code: 'not_found',
      message: AppStrings.notFound,
    );
  }

  void _publish(RawMessage message, String publishedId, String rewrite) {
    _bridge.published.add(
      PublishedMessage(
        id: publishedId,
        groupId: message.groupId,
        text: rewrite,
        displaySender: message.isAnonymous
            ? null
            : DisplaySender(id: message.senderId, name: message.senderName),
        attachmentId: message.attachmentId,
        replyTo: _quoteFor(message.id),
        publishedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// The reply quote for an outgoing message, if it replied to one.
  ReplyQuote? _quoteFor(String rawId) {
    String? target;
    for (final item in _bridge.outgoing) {
      if (item.id == rawId) target = item.replyToId;
    }
    for (final item in _bridge.replies.entries) {
      if (item.key == rawId) target = item.value;
    }
    if (target == null) return null;
    for (final m in _bridge.published) {
      if (m.id == target) {
        return ReplyQuote(
          id: m.id,
          text: m.text,
          displaySender: m.displaySender,
        );
      }
    }
    return null;
  }

  void _markMine(String id, MessageStatus status) {
    final index = _bridge.mine.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _bridge.mine[index] = _bridge.mine[index].copyWith(status: status);
  }

  void _requireControllerGroup(String groupId) {
    if (groupId != MockIds.dashboardGroup) {
      throw const RepositoryException(
        code: 'forbidden',
        message: AppStrings.notAllowed,
      );
    }
  }

  RawMessage _requireById(String messageId) {
    for (final message in _messages) {
      if (message.id == messageId) return message;
    }
    for (final item in _bridge.outgoing) {
      if (item.id == messageId) return _fromOutgoing(item);
    }
    throw const RepositoryException(
      code: 'not_found',
      message: AppStrings.notFound,
    );
  }

  void _requirePending(RawMessage message) {
    if (message.status != MessageStatus.pending) {
      throw const RepositoryException(
        code: 'conflict',
        message: AppStrings.alreadyReviewed,
      );
    }
  }

  static List<RawMessage> _seed() {
    const groupId = MockIds.dashboardGroup;
    RawMessage item({
      required String id,
      required String senderId,
      required String senderName,
      required String originalText,
      String? rewrittenText,
      required bool isAnonymous,
      double? intent,
      double? relevance,
      RelevanceLabel? label,
      required PipelineStatus pipeline,
      required int minute,
    }) {
      return RawMessage(
        id: id,
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        originalText: originalText,
        rewrittenText: rewrittenText,
        isAnonymous: isAnonymous,
        intentPreservationScore: intent,
        relevanceScore: relevance,
        relevanceLabel: label,
        pipelineStatus: pipeline,
        status: MessageStatus.pending,
        createdAt: DateTime.utc(2026, 10, 12, 9, minute),
      );
    }

    return [
      item(
        id: 'm201',
        senderId: MockIds.rohan,
        senderName: 'Rohan',
        originalText: 'The dashboard should show who changed a chart.',
        rewrittenText: 'I suggest the dashboard record who changed a chart.',
        isAnonymous: false,
        intent: 0.93,
        relevance: 0.9,
        label: RelevanceLabel.relevant,
        pipeline: PipelineStatus.done,
        minute: 0,
      ),
      item(
        id: 'm202',
        senderId: MockIds.arhat,
        senderName: 'Arhat',
        originalText: 'I am going to the cafe today.',
        rewrittenText: 'I will be at a cafe today.',
        isAnonymous: false,
        intent: 0.8,
        relevance: 0.18,
        label: RelevanceLabel.offTopic,
        pipeline: PipelineStatus.done,
        minute: 5,
      ),
      item(
        id: 'm203',
        senderId: MockIds.rohan,
        senderName: 'Rohan',
        originalText: 'These charts are confusing and we should simplify them.',
        rewrittenText:
            'The charts are hard to read. I suggest we simplify them.',
        isAnonymous: true,
        intent: 0.9,
        relevance: 0.74,
        label: RelevanceLabel.relevant,
        pipeline: PipelineStatus.done,
        minute: 10,
      ),
      item(
        id: 'm204',
        senderId: MockIds.rohan,
        senderName: 'Rohan',
        originalText: 'Can we add export to CSV?',
        isAnonymous: false,
        pipeline: PipelineStatus.processing,
        minute: 15,
      ),
      item(
        id: 'm205',
        senderId: MockIds.arhat,
        senderName: 'Arhat',
        originalText: 'The filter row is easy to miss.',
        isAnonymous: false,
        pipeline: PipelineStatus.queued,
        minute: 20,
      ),
      item(
        id: 'm206',
        senderId: MockIds.rohan,
        senderName: 'Rohan',
        originalText: 'The loading spinner never stops on the home chart.',
        isAnonymous: false,
        pipeline: PipelineStatus.failed,
        minute: 25,
      ),
    ];
  }
}
