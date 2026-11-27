import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:talk_it_out/app/providers.dart';

/// Thin wrapper over the google_sign_in plugin that yields Google ID
/// tokens for `POST /auth/google` (`API.md` 40).
///
/// The client id comes from `--dart-define=GOOGLE_CLIENT_ID=...` (the Web
/// client id from Google Cloud). On Android it is passed as the server
/// client id so Google issues an ID token for our backend.
class GoogleSignInService {
  GoogleSignInService(this.clientId);

  final String clientId;
  Future<void>? _init;

  bool get configured => clientId.isNotEmpty;

  Future<void> ensureInitialized() {
    return _init ??= GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? clientId : null,
      serverClientId: kIsWeb ? null : clientId,
    );
  }

  /// ID tokens from completed sign-ins (web button or [authenticate]).
  Stream<String> get idTokens => GoogleSignIn.instance.authenticationEvents
      .where((e) => e is GoogleSignInAuthenticationEventSignIn)
      .map(
        (e) => (e as GoogleSignInAuthenticationEventSignIn)
            .user
            .authentication
            .idToken,
      )
      .where((t) => t != null && t.isNotEmpty)
      .cast<String>();

  /// True where the app draws its own button (mobile); web uses
  /// Google's rendered button instead.
  bool get supportsAuthenticate => GoogleSignIn.instance.supportsAuthenticate();

  Future<void> authenticate() => GoogleSignIn.instance.authenticate();
}

final googleSignInServiceProvider = Provider<GoogleSignInService>(
  (ref) => GoogleSignInService(ref.watch(appConfigProvider).googleClientId),
);
