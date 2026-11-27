import 'dart:convert';

/// One Server-Sent Events message: its `event:` name and `data:` text.
class SseMessage {
  const SseMessage(this.event, this.data);

  final String event;
  final String data;
}

/// Incremental parser for `text/event-stream` (WHATWG spec subset:
/// `event`, `data`, comments; `id` and `retry` are ignored). Feed it text
/// chunks in any split; it returns complete messages.
class SseParser {
  final _buffer = StringBuffer();
  var _event = 'message';
  final _data = <String>[];

  List<SseMessage> add(String chunk) {
    _buffer.write(chunk);
    final text = _buffer.toString();
    final lastNewline = text.lastIndexOf('\n');
    if (lastNewline < 0) return const [];
    _buffer
      ..clear()
      ..write(text.substring(lastNewline + 1));
    final out = <SseMessage>[];
    for (var line in const LineSplitter().convert(
      text.substring(0, lastNewline + 1),
    )) {
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.isEmpty) {
        if (_data.isNotEmpty) out.add(SseMessage(_event, _data.join('\n')));
        _event = 'message';
        _data.clear();
      } else if (line.startsWith(':')) {
        // Comment (heartbeat).
      } else {
        final colon = line.indexOf(':');
        final field = colon < 0 ? line : line.substring(0, colon);
        var value = colon < 0 ? '' : line.substring(colon + 1);
        if (value.startsWith(' ')) value = value.substring(1);
        if (field == 'event') _event = value;
        if (field == 'data') _data.add(value);
      }
    }
    return out;
  }
}
