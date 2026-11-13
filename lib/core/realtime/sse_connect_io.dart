import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:talk_it_out/core/realtime/sse_parser.dart';

/// Opens [url] as a `text/event-stream` and yields its messages. The
/// stream ends when the server closes it; errors are thrown.
Stream<SseMessage> connectSse(
  Uri url, {
  List<String> events = const [],
}) async* {
  final client = HttpClient()..idleTimeout = const Duration(seconds: 70);
  try {
    final request = await client.getUrl(url);
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('live stream refused (${response.statusCode})');
    }
    final parser = SseParser();
    await for (final chunk in response.transform(utf8.decoder)) {
      for (final message in parser.add(chunk)) {
        yield message;
      }
    }
  } finally {
    client.close(force: true);
  }
}
