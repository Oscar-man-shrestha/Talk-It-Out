import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/mock/mock_board.dart';
import 'package:talk_it_out/core/mock/mock_controls.dart';
import 'package:talk_it_out/core/mock/mock_ids.dart';
import 'package:talk_it_out/core/models/page_result.dart';
import 'package:talk_it_out/core/realtime/live_event.dart';
import 'package:talk_it_out/core/realtime/realtime_client.dart';
import 'package:talk_it_out/core/realtime/sse_parser.dart';
import 'package:talk_it_out/core/storage/token_store.dart';
import 'package:talk_it_out/features/groups/data/mock_group_repository.dart';
import 'package:talk_it_out/features/groups/data/mock_message_bridge.dart';
import 'package:talk_it_out/features/groups/data/published_message.dart';
import 'package:talk_it_out/features/groups/group_providers.dart';

/// Counts chat fetches per group.
class _CountingGroups extends MockGroupRepository {
  _CountingGroups(super.c, super.b, super.m);

  final calls = <String, int>{};

  @override
  Future<PageResult<PublishedMessage>> listMessages(
    String groupId, {
    int? limit,
    String? cursor,
  }) {
    calls[groupId] = (calls[groupId] ?? 0) + 1;
    return super.listMessages(groupId, limit: limit, cursor: cursor);
  }
}

/// A live client whose events the test pushes directly.
class _FakeRealtime extends RealtimeClient {
  _FakeRealtime()
    : super(fetchTicket: () async => 't', streamUrl: (_) => Uri());

  final controller = StreamController<LiveEvent>.broadcast();

  @override
  Stream<LiveEvent> get events => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SseParser', () {
    test('handles events split across chunks, comments and CRLF', () {
      final parser = SseParser();
      expect(parser.add('retry: 3000\nevent: ready\nda'), isEmpty);
      final first = parser.add('ta: {"type":"ready"}\n\n: ping\n\n');
      expect(first.single.event, 'ready');
      expect(first.single.data, '{"type":"ready"}');
      final more = parser.add(
        'event: chat\r\ndata: {"group_id":"g1"}\r\n\r\nevent: feed\ndata: a\ndata: b\n\n',
      );
      expect(more.map((m) => m.event), ['chat', 'feed']);
      expect(more.last.data, 'a\nb');
    });
  });

  group('RealtimeClient', () {
    test(
      'parses events, reconnects with a fresh ticket, then asks for a resync',
      () async {
        var tickets = 0;
        final streams = <StreamController<SseMessage>>[];
        final urls = <Uri>[];
        final client = RealtimeClient(
          fetchTicket: () async => 'ticket-${++tickets}',
          streamUrl: (t) => Uri.parse('http://api.test/events?ticket=$t'),
          connector: (url, {events = const []}) {
            urls.add(url);
            final c = StreamController<SseMessage>();
            streams.add(c);
            return c.stream;
          },
          minBackoff: const Duration(milliseconds: 10),
          maxBackoff: const Duration(milliseconds: 20),
        );
        addTearDown(client.dispose);
        final got = <LiveEvent>[];
        client.events.listen(got.add);

        client.start();
        await pumpEventQueue();
        streams.last
          ..add(const SseMessage('ready', '{}'))
          ..add(const SseMessage('chat', '{"type":"chat","group_id":"g1"}'))
          ..add(const SseMessage('unknown', '{}'))
          ..add(const SseMessage('chat', 'not json'));
        await pumpEventQueue();
        expect(client.connected, isTrue);
        expect(got.map((e) => '${e.type}:${e.groupId}'), ['chat:g1']);

        // The server drops the stream: reconnect with a NEW ticket.
        await streams.last.close();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(urls.length, 2);
        expect(urls.last.queryParameters['ticket'], 'ticket-2');
        streams.last.add(const SseMessage('ready', '{}'));
        await pumpEventQueue();
        expect(got.last.isResync, isTrue);

        client.stop();
        await streams.last.close();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(urls.length, 2, reason: 'no reconnect after stop');
      },
    );

    test('a failing ticket request is retried', () async {
      var calls = 0;
      final client = RealtimeClient(
        fetchTicket: () async {
          calls += 1;
          if (calls < 3) throw StateError('offline');
          return 'ok';
        },
        streamUrl: (t) => Uri.parse('http://api.test/events?ticket=$t'),
        connector: (url, {events = const []}) => const Stream.empty(),
        minBackoff: const Duration(milliseconds: 5),
        maxBackoff: const Duration(milliseconds: 10),
      );
      addTearDown(client.dispose);
      client.start();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(calls, greaterThanOrEqualTo(3));
    });
  });

  test(
    'a chat refreshes on its own group\'s signal, merged per burst',
    () async {
      final live = _FakeRealtime();
      final board = MockBoard();
      final controls = MockControls(delay: Duration.zero);
      final repo = _CountingGroups(controls, board, MockMessageBridge());
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(
            MemoryTokenStore()..value = 'mock-token',
          ),
          mockControlsProvider.overrideWithValue(controls),
          realtimeClientProvider.overrideWithValue(live),
          groupRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        groupMessagesProvider(MockIds.notesGroup),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(groupMessagesProvider(MockIds.notesGroup).future);
      expect(repo.calls[MockIds.notesGroup], 1);

      // Another group's chat changed: no refetch here.
      live.controller.add(
        const LiveEvent('chat', groupId: MockIds.dashboardGroup),
      );
      // Three signals for this group in a burst: one refetch.
      for (var i = 0; i < 3; i++) {
        live.controller.add(
          const LiveEvent('chat', groupId: MockIds.notesGroup),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await container.read(groupMessagesProvider(MockIds.notesGroup).future);
      expect(repo.calls[MockIds.notesGroup], 2);

      // A resync after a dropped connection refetches too.
      live.controller.add(LiveEvent.resync);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await container.read(groupMessagesProvider(MockIds.notesGroup).future);
      expect(repo.calls[MockIds.notesGroup], 3);
    },
  );
}
