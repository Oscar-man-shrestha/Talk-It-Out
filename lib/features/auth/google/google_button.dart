// Google's own sign-in button on web; nothing elsewhere (mobile builds
// draw a regular button that calls GoogleSignIn.authenticate()).
export 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart';
