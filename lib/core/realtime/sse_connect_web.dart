import 'dart:async';
import 'dart:js_interop';

import 'package:talk_it_out/core/realtime/sse_parser.dart';
import 'package:web/web.dart' as web;

/// Opens [url] with the browser's EventSource and yields messages for the
/// named [events]. Any error ends the stream (the caller reconnects with a
/// fresh ticket; EventSource's own retry would reuse an expired one).
Stream<SseMessage> connectSse(Uri url, {List<String> events = const []}) {
  late final web.EventSource source;
  late final StreamController<SseMessage> controller;
  controller = StreamController<SseMessage>(
    onListen: () {
      source = web.EventSource(url.toString());
      for (final name in [...events, 'ready']) {
        source.addEventListener(
          name,
          ((web.Event e) {
            final data = (e as web.MessageEvent).data;
            final text = data.isA<JSString>() ? (data as JSString).toDart : '';
            if (!controller.isClosed) controller.add(SseMessage(name, text));
          }).toJS,
        );
      }
      source.onerror = ((web.Event _) {
        source.close();
        if (!controller.isClosed) {
          controller.addError(StateError('live stream interrupted'));
          controller.close();
        }
      }).toJS;
    },
    onCancel: () => source.close(),
  );
  return controller.stream;
}
