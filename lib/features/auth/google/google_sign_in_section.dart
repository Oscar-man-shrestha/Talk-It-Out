import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/auth/google/google_button.dart';
import 'package:talk_it_out/features/auth/google/google_sign_in_service.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';

/// "or" divider plus Sign in with Google (`API.md` 40). Web shows Google's
/// own button; mobile draws one that opens Google's sign-in sheet. Shown
/// only when the build has a `GOOGLE_CLIENT_ID` (the demo has no Google
/// account behind it). Used on both Sign in and Sign up: Google creates the
/// account the first time.
class GoogleSignInSection extends ConsumerStatefulWidget {
  const GoogleSignInSection({
    required this.keepSession,
    required this.disabled,
    super.key,
  });

  final bool keepSession;
  final bool disabled;

  @override
  ConsumerState<GoogleSignInSection> createState() =>
      GoogleSignInSectionState();
}

class GoogleSignInSectionState extends ConsumerState<GoogleSignInSection> {
  StreamSubscription<String>? _tokens;
  var _ready = false;
  var _busy = false;
  String? _error;

  bool get _useMock => ref.read(appConfigProvider).useMock;
  GoogleSignInService get _google => ref.read(googleSignInServiceProvider);

  @override
  void initState() {
    super.initState();
    if (_google.configured) _setUp();
  }

  Future<void> _setUp() async {
    try {
      await _google.ensureInitialized();
      _tokens = _google.idTokens.listen(
        _signIn,
        onError: (Object _) {
          if (mounted) setState(() => _error = AppStrings.googleFailed);
        },
      );
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.googleFailed);
    }
  }

  @override
  void dispose() {
    _tokens?.cancel();
    super.dispose();
  }

  Future<void> _signIn(String idToken) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .loginWithGoogle(idToken: idToken, keepSession: widget.keepSession);
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.googleFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Starts Google sign-in without the button when the platform allows it
  /// (phones, the demo). False on the web, where only Google's button can.
  bool startDirectly() {
    if (widget.disabled || _busy) return false;
    if (_useMock) {
      _tap();
      return true;
    }
    if (!_google.configured || !_ready || !_google.supportsAuthenticate) {
      return false;
    }
    _tap();
    return true;
  }

  Future<void> _tap() async {
    if (_useMock) {
      await _signIn('mock-google-id-token');
      return;
    }
    try {
      await _google.authenticate();
      // The ID token arrives on the idTokens stream.
    } catch (_) {
      // Closing Google's sheet is not an error worth showing.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_google.configured) return const SizedBox.shrink();
    final webButton = kIsWeb && _ready ? renderGoogleButton() : null;
    final showOwnButton = !kIsWeb && _ready;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(child: Divider(color: Brand.border)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  AppStrings.orDivider,
                  style: TextStyle(fontSize: 12, color: Brand.inkFaint),
                ),
              ),
              Expanded(child: Divider(color: Brand.border)),
            ],
          ),
          const SizedBox(height: 14),
          if (webButton != null)
            Center(child: SizedBox(height: 44, child: webButton))
          else if (showOwnButton)
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: widget.disabled || _busy ? null : _tap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Brand.ink,
                  side: const BorderSide(color: Brand.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'G',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Brand.ink,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            AppStrings.continueWithGoogle,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
