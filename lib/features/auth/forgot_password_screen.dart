import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';

// Stitch Monochrome Precision design tokens (same as the login screen).
const _kPrimary = Color(0xFF000000);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kBorderSubtle = Color(0xFFE4E4E7);
const _kBorderStrong = Color(0xFF27272A);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);
const _kError = Color(0xFFBA1A1A);

enum _Step { email, code, password }

/// Three steps (`API.md` 38, 48): the email gets a code, the code is
/// checked, and only then can a new password be set. Reached from
/// "Forgot?" on the login screen.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _resendSeconds = 60;

  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _codeFocus = FocusNode();
  var _step = _Step.email;
  var _busy = false;
  var _obscure = true;
  var _noAccount = false;
  String? _error;
  String? _resetToken;
  Timer? _timer;
  var _resendLeft = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String get _address => _email.text.trim();

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendLeft -= 1);
      if (_resendLeft <= 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _noAccount = false;
    });
    try {
      await action();
    } on RepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _noAccount = error.code == 'no_account';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_address)) {
      setState(() => _error = AppStrings.enterValidEmail);
      return;
    }
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: _address);
      if (!mounted) return;
      _code.clear();
      setState(() => _step = _Step.code);
      _startResendTimer();
      _codeFocus.requestFocus();
      if (resend) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.resetNewCodeSent)),
        );
      }
    });
  }

  Future<void> _verifyCode() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = AppStrings.resetCodeFormat);
      return;
    }
    await _run(() async {
      final token = await ref
          .read(authRepositoryProvider)
          .verifyResetCode(email: _address, code: code);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _resetToken = token;
        _step = _Step.password;
      });
    });
    if (mounted && _error != null) _code.clear();
  }

  Future<void> _setPassword() async {
    if (_password.text.length < 8) {
      setState(() => _error = AppStrings.passwordTooShort);
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = AppStrings.resetPasswordsDiffer);
      return;
    }
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .confirmPasswordReset(
            email: _address,
            resetToken: _resetToken!,
            newPassword: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(AppStrings.resetDone)));
      context.go('/login');
    });
  }

  void _changeEmail() {
    _timer?.cancel();
    setState(() {
      _step = _Step.email;
      _error = null;
      _resetToken = null;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 540 ? (screenWidth - 420) / 2 : 20.0;
    final useMock = ref.watch(appConfigProvider).useMock;
    final stepNumber = _step.index + 1;

    final (title, intro) = switch (_step) {
      _Step.email => (AppStrings.resetTitle, AppStrings.resetIntro),
      _Step.code => (
        AppStrings.resetCodeTitle,
        AppStrings.resetCodeIntro(_address),
      ),
      _Step.password => (
        AppStrings.resetPasswordTitle,
        AppStrings.resetPasswordIntro,
      ),
    };

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
                child: Icon(
                  switch (_step) {
                    _Step.email => Icons.lock_reset,
                    _Step.code => Icons.mark_email_unread_outlined,
                    _Step.password => Icons.key_outlined,
                  },
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _StepBar(step: stepNumber),
            const SizedBox(height: 6),
            Text(
              AppStrings.resetStep(stepNumber),
              key: const ValueKey('reset-step'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: _kTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              intro,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            ..._stepFields(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                key: const ValueKey('reset-error'),
                style: const TextStyle(
                  color: _kError,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_noAccount)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.go('/register'),
                    style: TextButton.styleFrom(
                      foregroundColor: _kTextPrimary,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      AppStrings.resetCreateAccount,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const ValueKey('reset-submit'),
                onPressed: _busy
                    ? null
                    : switch (_step) {
                        _Step.email => () => _sendCode(),
                        _Step.code => _verifyCode,
                        _Step.password => _setPassword,
                      },
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
                        switch (_step) {
                          _Step.email => AppStrings.resetSendCode,
                          _Step.code => AppStrings.resetVerify,
                          _Step.password => AppStrings.resetConfirm,
                        },
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_step == _Step.code) ...[
              TextButton(
                key: const ValueKey('reset-resend'),
                onPressed: _busy || _resendLeft > 0
                    ? null
                    : () => _sendCode(resend: true),
                style: TextButton.styleFrom(foregroundColor: _kTextPrimary),
                child: Text(
                  _resendLeft > 0
                      ? AppStrings.resetResendIn(_resendLeft)
                      : AppStrings.resetResend,
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _changeEmail,
                style: TextButton.styleFrom(foregroundColor: _kTextSecondary),
                child: const Text(AppStrings.resetChangeEmail),
              ),
            ],
            TextButton(
              onPressed: _busy ? null : () => context.go('/login'),
              style: TextButton.styleFrom(foregroundColor: _kTextSecondary),
              child: const Text(AppStrings.resetBackToLogin),
            ),
            if (_step == _Step.code)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  useMock
                      ? AppStrings.resetMockHint
                      : AppStrings.resetCheckSpam,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _kTextTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stepFields() {
    switch (_step) {
      case _Step.email:
        return [
          const _Label(AppStrings.emailLabel),
          _Field(
            key: const ValueKey('reset-email'),
            controller: _email,
            icon: Icons.alternate_email,
            hint: 'alex@example.com',
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _busy ? null : _sendCode(),
          ),
        ];
      case _Step.code:
        return [
          const _Label(AppStrings.resetCodeLabel),
          _CodeBoxes(
            key: const ValueKey('reset-code'),
            controller: _code,
            focusNode: _codeFocus,
            enabled: !_busy,
            onCompleted: _verifyCode,
          ),
        ];
      case _Step.password:
        Widget eye() => IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: _kTextTertiary,
          ),
        );
        return [
          const _Label(AppStrings.resetNewPasswordLabel),
          _Field(
            key: const ValueKey('reset-password'),
            controller: _password,
            icon: Icons.lock_outline,
            hint: '••••••••',
            enabled: !_busy,
            obscure: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            suffix: eye(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          _PasswordHint(length: _password.text.length),
          const SizedBox(height: 14),
          const _Label(AppStrings.resetConfirmPasswordLabel),
          _Field(
            key: const ValueKey('reset-password-confirm'),
            controller: _confirm,
            icon: Icons.lock_outline,
            hint: '••••••••',
            enabled: !_busy,
            obscure: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _busy ? null : _setPassword(),
          ),
        ];
    }
  }
}

/// Three segments; the ones up to the current step are filled.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 3; i++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: i <= step ? _kPrimary : _kBorderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (i < 3) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _PasswordHint extends StatelessWidget {
  const _PasswordHint({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final ok = length >= 8;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: ok ? _kTextPrimary : _kTextTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          'At least 8 characters',
          style: TextStyle(
            fontSize: 12,
            color: ok ? _kTextPrimary : _kTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// Six boxes over one hidden text field, so paste and the phone's
/// one-time-code autofill work. Calls [onCompleted] at six digits.
class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onCompleted;

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.focusNode.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.focusNode.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final focused = widget.focusNode.hasFocus;
    return GestureDetector(
      onTap: widget.focusNode.requestFocus,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 0.86,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kSurfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: focused && i == text.length.clamp(0, 5)
                              ? _kPrimary
                              : (i < text.length
                                    ? _kBorderStrong
                                    : _kBorderSubtle),
                          width: focused && i == text.length.clamp(0, 5)
                              ? 2
                              : 1,
                        ),
                      ),
                      child: Text(
                        i < text.length ? text[i] : '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: _kTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (i < 5) const SizedBox(width: 8),
              ],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (value) {
                  if (value.length == 6) widget.onCompleted();
                },
              ),
            ),
          ),
        ],
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
    this.onChanged,
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
  final ValueChanged<String>? onChanged;

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
        onChanged: onChanged,
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
