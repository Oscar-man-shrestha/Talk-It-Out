import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/groups/chat_image.dart';
import 'package:talk_it_out/features/groups/data/mock_group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/review/data/raw_message.dart';

void main() {
  final fast = MockControls(delay: Duration.zero);
  final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);

  test(
    'an uploaded image travels with the message and can be fetched',
    () async {
      final bridge = MockMessageBridge();
      final groups = MockGroupRepository(fast, MockBoard(), bridge);

      final id = await groups.uploadAttachment(
        MockIds.notesGroup,
        bytes: bytes,
        filename: 'photo.jpg',
      );
      await groups.sendMessage(
        MockIds.notesGroup,
        text: 'The chart is cut off',
        isAnonymous: true,
        attachmentId: id,
      );
      expect(bridge.outgoing.last.attachmentId, id);
      expect(await groups.fetchAttachment(MockIds.notesGroup, id), bytes);

      // A controller announcement can carry one too.
      final pic = await groups.uploadAttachment(
        MockIds.dashboardGroup,
        bytes: bytes,
        filename: 'layout.png',
      );
      final sent = await groups.sendControllerMessage(
        MockIds.dashboardGroup,
        text: 'New layout',
        attachmentId: pic,
      );
      expect(sent.attachmentId, pic);
    },
  );

  test('attachment_id is read from the API and is optional', () {
    final published = PublishedMessage.fromJson({
      'id': 'p1',
      'group_id': 'g1',
      'text': 'hi',
      'display_sender': null,
      'attachment_id': 'a1',
      'published_at': '2026-11-14T10:00:00.000Z',
    });
    expect(published.attachmentId, 'a1');
    expect(published.displaySender, isNull);
    final plain = PublishedMessage.fromJson({
      'id': 'p2',
      'group_id': 'g1',
      'text': 'hi',
      'published_at': '2026-11-14T10:00:00.000Z',
    });
    expect(plain.attachmentId, isNull);
    final raw = RawMessage.fromJson({
      'id': 'm1',
      'group_id': 'g1',
      'sender_id': 'u1',
      'sender_name': 'A',
      'original_text': 'x',
      'is_anonymous': true,
      'pipeline_status': 'done',
      'status': 'pending',
      'created_at': '2026-11-14T10:00:00.000Z',
      'attachment_id': 'a9',
    });
    expect(raw.attachmentId, 'a9');
  });

  testWidgets('the preview warns anonymous senders about what a photo shows', (
    tester,
  ) async {
    var removed = false;
    Widget preview(bool anonymous) => MaterialApp(
      home: Scaffold(
        body: PendingImagePreview(
          image: (bytes: bytes, filename: 'photo.jpg'),
          anonymous: anonymous,
          onRemove: () => removed = true,
        ),
      ),
    );
    await tester.pumpWidget(preview(true));
    expect(find.text(AppStrings.imagePrivacyAnonymous), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove-pending-image')));
    expect(removed, isTrue);
    await tester.pumpWidget(preview(false));
    expect(find.text(AppStrings.imagePrivacyNamed), findsOneWidget);
  });
}
