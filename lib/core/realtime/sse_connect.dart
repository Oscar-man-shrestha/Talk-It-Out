// Platform transport for the live stream: the browser's EventSource on
// web, a streaming HTTP request elsewhere.
export 'sse_connect_io.dart'
    if (dart.library.js_interop) 'sse_connect_web.dart';
