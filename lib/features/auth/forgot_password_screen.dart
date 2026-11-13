import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

// Stitch Monochrome Precision design tokens (same as the login screen).
const _kPrimary = Color(0xFF000000);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kBorderStrong = Color(0xFF27272A);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);
const _kError = Color(0xFFBA1A1A);

/// Two steps: ask for a code by email, then set a new password with it
/// (`API.md` 38). Reached from "Forgot?" on the login screen.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  var _codeSent = false;
  var _busy = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = AppStrings.enterValidEmail);
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
      if (mounted) setState(() => _codeSent = true);
    });
  }

  Future<void> _setPassword() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = AppStrings.resetCodeFormat);
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = AppStrings.passwordTooShort);
      return;
    }
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            email: _email.text.trim(),
            code: code,
            newPassword: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(AppStrings.resetDone)));
      context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 540 ? (screenWidth - 420) / 2 : 20.0;
    final useMock = ref.watch(appConfigProvider).useMock;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 32),
          children: [
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              AppStrings.resetTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _codeSent ? AppStrings.resetCodeSent : AppStrings.resetIntro,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            const _Label(AppStrings.emailLabel),
            _Field(
              key: const ValueKey('reset-email'),
              controller: _email,
              icon: Icons.alternate_email,
              hint: 'alex@example.com',
              enabled: !_codeSent && !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _busy || _codeSent ? null : _sendCode(),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 14),
              const _Label(AppStrings.resetCodeLabel),
              _Field(
                key: const ValueKey('reset-code'),
                controller: _code,
                icon: Icons.pin_outlined,
                hint: '123456',
                enabled: !_busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
              ),
              const SizedBox(height: 14),
              const _Label(AppStrings.resetNewPasswordLabel),
              _Field(
                key: const ValueKey('reset-password'),
                controller: _password,
                icon: Icons.lock_outline,
                hint: '••••••••',
                enabled: !_busy,
                obscure: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _busy ? null : _setPassword(),
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: _kTextTertiary,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: _kError,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : (_codeSent ? _setPassword : _sendCode),
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _codeSent
                            ? AppStrings.resetConfirm
                            : AppStrings.resetSendCode,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_codeSent)
              TextButton(
                onPressed: _busy ? null : _sendCode,
                style: TextButton.styleFrom(foregroundColor: _kTextPrimary),
                child: const Text(AppStrings.resetResend),
              ),
            TextButton(
              onPressed: _busy ? null : () => context.go('/login'),
              style: TextButton.styleFrom(foregroundColor: _kTextSecondary),
              child: const Text(AppStrings.resetBackToLogin),
            ),
            if (useMock && _codeSent)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  AppStrings.resetMockHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _kTextTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _kTextPrimary,
        ),
      ),
    );
  }
}

/// Bordered input matching the login screen's fields.
class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    required this.enabled,
    this.keyboardType,
    this.autofillHints,
    this.obscure = false,
    this.suffix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool enabled;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorderStrong, width: 1),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 13, color: _kTextPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: _kTextTertiary),
          prefixIcon: Icon(icon, size: 18, color: _kTextTertiary),
          suffixIcon: suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
