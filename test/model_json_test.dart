import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/models/enums.dart';
import 'package:talk_it_out/core/models/group.dart';
import 'package:talk_it_out/core/models/group_member.dart';
import 'package:talk_it_out/features/feed/data/post.dart';
import 'package:talk_it_out/features/groups/data/my_message_status.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/notifications/data/app_notification.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';

void main() {
  test('unknown enums fall back without becoming controller', () {
    final group = Group.fromJson({
      'id': 'g1',
      'agenda': 'Notes',
      'controller_id': 'u9',
      'source_post_id': null,
      'created_at': '2026-10-01T10:00:00Z',
      'my_role': 'owner',
      'pending_count': null,
    });
    expect(group.myRole, GroupRole.contributor);

    final member = GroupMember.fromJson({
      'user_id': 'u1',
      'name': 'Priya',
      'role': 'nope',
    });
    expect(member.role, GroupRole.contributor);
    expect(member.role, isNot(GroupRole.controller));

    final mine = MyMessageStatus.fromJson({
      'id': 'm1',
      'group_id': 'g1',
      'status': 'archived',
      'is_anonymous': false,
      'created_at': '2026-10-11T08:00:00Z',
      'text': 'should be dropped',
      'original_text': 'should be dropped',
    });
    expect(mine.status, MessageStatus.pending);
    expect(mine.toJson().containsKey('text'), isFalse);
    expect(mine.toJson().containsKey('original_text'), isFalse);

    final raw = RawMessage.fromJson({
      'id': 'm2',
      'group_id': 'g2',
      'sender_id': 'u2',
      'sender_name': 'Rohan',
      'original_text': 'Hello',
      'rewritten_text': null,
      'is_anonymous': false,
      'intent_preservation_score': 1,
      'relevance_score': null,
      'relevance_label': 'weird',
      'pipeline_status': 'later',
      'status': 'pending',
      'created_at': '2026-10-12T09:00:00Z',
    });
    expect(raw.intentPreservationScore, 1);
    expect(raw.relevanceScore, isNull);
    expect(raw.relevanceLabel, RelevanceLabel.borderline);
    expect(raw.pipelineStatus, PipelineStatus.processing);
    expect(raw.rewriteUnavailable, isFalse);

    final failed = raw.copyWith(pipelineStatus: PipelineStatus.failed);
    expect(failed.rewriteUnavailable, isTrue);

    final notification = AppNotification.fromJson({
      'id': 'n4',
      'type': 'not_a_real_type',
      'ref_id': 'x',
      'group': {'id': 'g1', 'agenda': 'Making NLP notes'},
      'created_at': '2026-10-12T18:00:00Z',
      'read_at': null,
      'reason': 'too rude',
    });
    expect(notification.type, NotificationType.unknown);
    expect(notification.isUnread, isTrue);
    expect(notification.toJson().containsKey('reason'), isFalse);
  });

  test('published messages keep a null sender and drop private fields', () {
    final message = PublishedMessage.fromJson({
      'id': 'pm2',
      'group_id': 'g1',
      'text': 'Could we revisit the sprint timeline?',
      'display_sender': null,
      'published_at': '2026-10-10T12:05:00Z',
      'original_text': 'hidden',
      'sender_id': 'u1',
      'is_anonymous': true,
      'raw_message_id': 'm1',
    });

    expect(message.displaySender, isNull);
    final json = message.toJson();
    expect(json['display_sender'], isNull);
    expect(json.containsKey('original_text'), isFalse);
    expect(json.containsKey('sender_id'), isFalse);
    expect(json.containsKey('is_anonymous'), isFalse);
    expect(json.containsKey('raw_message_id'), isFalse);
  });

  test('posts keep unknown flag keys and a visible author', () {
    final post = Post.fromJson({
      'id': 'p3',
      'author': {'id': 'u2', 'name': 'Rohan'},
      'content': 'A note',
      'nsfw_flag': false,
      'other_flags': {'tone_flag': true},
      'reaction_count': 0,
      'my_reaction': null,
      'comment_count': 0,
      'created_at': '2026-10-06T09:00:00Z',
    });

    expect(post.author.id, 'u2');
    expect(post.otherFlags['tone_flag'], isTrue);
  });
}
