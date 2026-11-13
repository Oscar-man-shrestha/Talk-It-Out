import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/core/api/dio_provider.dart';
import 'package:talk_it_out/core/api/endpoints.dart';
import 'package:talk_it_out/core/realtime/live_event.dart';
import 'package:talk_it_out/core/realtime/sse_connect.dart';
import 'package:talk_it_out/core/realtime/sse_parser.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';

typedef SseConnector = Stream<SseMessage> Function(
  Uri url, {
  List<String> events,
});

/// Keeps one live-update stream (`API.md` 41) open while a user is signed
/// in to a live backend, and turns it into [LiveEvent]s.
///
/// - Connects on sign-in, disconnects on sign-out; never in mock mode.
/// - Each attempt fetches a fresh 60-second ticket, then opens
///   `GET /events?ticket=…`.
/// - Reconnects with exponential backoff (1 s → 30 s, with jitter) and,
///   after any reconnect, emits [LiveEvent.resync] so screens refetch
///   whatever changed while the stream was down.
/// - Reconnects immediately when the app returns to the foreground.
class RealtimeClient with WidgetsBindingObserver {
  RealtimeClient({
    required this.fetchTicket,
    required this.streamUrl,
    this.connector = connectSse,
    this.minBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 30),
  });

  final Future<String> Function() fetchTicket;
  final Uri Function(String ticket) streamUrl;
  final SseConnector connector;
  final Duration minBackoff;
  final Duration maxBackoff;
  final _events = StreamController<LiveEvent>.broadcast();
  final _random = Random();

  StreamSubscription<SseMessage>? _sub;
  Timer? _retry;
  var _wanted = false;
  var _connected = false;
  var _hadConnection = false;
  var _attempt = 0;
  var _generation = 0;

  /// Signals for screens. Subscribe in a provider's build and cancel on
  /// dispose.
  Stream<LiveEvent> get events => _events.stream;

  bool get connected => _connected;

  void start() {
    if (_wanted) return;
    _wanted = true;
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  void stop() {
    _wanted = false;
    WidgetsBinding.instance.removeObserver(this);
    _generation += 1;
    _retry?.cancel();
    _sub?.cancel();
    _sub = null;
    _connected = false;
    _hadConnection = false;
    _attempt = 0;
  }

  void dispose() {
    stop();
    _events.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wanted && !_connected) {
      _retry?.cancel();
      _attempt = 0;
      _connect();
    }
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    _sub?.cancel();
    _sub = null;
    final String ticket;
    try {
      ticket = await fetchTicket();
    } catch (_) {
      if (generation == _generation) _scheduleRetry();
      return;
    }
    if (!_wanted || generation != _generation) return;
    _sub = connector(streamUrl(ticket), events: LiveEvent.types).listen(
      (message) {
        if (message.event == 'ready') {
          _connected = true;
          _attempt = 0;
          // Anything may have changed while we were away.
          if (_hadConnection) _emit(LiveEvent.resync);
          _hadConnection = true;
          return;
        }
        final Object? decoded;
        try {
          decoded = jsonDecode(message.data);
        } catch (_) {
          return;
        }
        if (decoded is! Map<String, dynamic>) return;
        final event = LiveEvent.fromSse(message.event, decoded);
        if (event != null) _emit(event);
      },
      onError: (Object _) => _lost(generation),
      onDone: () => _lost(generation),
      cancelOnError: true,
    );
  }

  void _emit(LiveEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _lost(int generation) {
    if (generation != _generation) return;
    _connected = false;
    _sub = null;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_wanted) return;
    _retry?.cancel();
    final base = minBackoff * pow(2, min(_attempt, 5)).toInt();
    final capped = base > maxBackoff ? maxBackoff : base;
    // Up to 30% jitter so many clients do not reconnect in lockstep.
    final jitter = capped * (_random.nextDouble() * 0.3);
    _attempt += 1;
    _retry = Timer(capped + jitter, _connect);
  }
}

/// The app-wide live client. Follows the session: connected while a user
/// is signed in to a live backend, idle otherwise (and always in mock
/// mode, where nothing changes server-side).
final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = ref.watch(dioProvider);
  final base = config.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  final client = RealtimeClient(
    fetchTicket: () async {
      final response = await dio.post<Map<String, dynamic>>(
        Endpoints.eventsTicket,
      );
      final ticket = response.data?['ticket'];
      if (ticket is! String || ticket.isEmpty) {
        throw const FormatException('missing ticket');
      }
      return ticket;
    },
    streamUrl: (ticket) =>
        Uri.parse('$base${Endpoints.events}')
            .replace(queryParameters: {'ticket': ticket}),
  );
  ref.onDispose(client.dispose);
  if (!config.useMock) {
    ref.listen<String?>(
      sessionProvider.select((session) => session.value?.id),
      (_, userId) => userId == null ? client.stop() : client.start(),
      fireImmediately: true,
    );
  }
  return client;
});

/// Lets a provider refetch itself when matching live events arrive.
/// Bursts are merged: many events within [debounce] cause one refetch.
/// [LiveEvent.resync] always matches.
void refreshOnLiveEvents(
  Ref ref,
  bool Function(LiveEvent event) matches, {
  required void Function() refresh,
  Duration debounce = const Duration(milliseconds: 250),
}) {
  Timer? timer;
  final sub = ref.read(realtimeClientProvider).events.listen((event) {
    if (!event.isResync && !matches(event)) return;
    timer?.cancel();
    timer = Timer(debounce, () {
      if (ref.mounted) refresh();
    });
  });
  ref.onDispose(() {
    timer?.cancel();
    sub.cancel();
  });
}
