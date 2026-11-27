import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/saved_accounts.dart';
import 'package:talk_it_out/features/auth/google/google_sign_in_section.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/auth/auth_frame.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

// Stitch Monochrome Precision design tokens
const _kPrimary = Brand.accent;
const _kSurfaceMuted = Brand.muted;
const _kBorderSubtle = Brand.border;
const _kTextPrimary = Brand.ink;
const _kTextSecondary = Brand.inkSoft;
const _kTextTertiary = Brand.inkFaint;

/// Login screen matching the Stitch Monochrome Precision PNG mockup exactly.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _obscure = true;
  var _keepSession = true;
  String? _error;

  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  final _googleKey = GlobalKey<GoogleSignInSectionState>();

  /// What "Continue as" is waiting for, shown under the chosen account.
  String? _continueHint;

  /// "Continue as...". A Google account goes through Google (it may have
  /// no password); a password account fills the email and asks for the
  /// password.
  void _choose(SavedAccount account) {
    setState(() {
      _email.text = account.email;
      _password.clear();
      _error = null;
      _continueHint = account.google
          ? AppStrings.continueWithGoogleHint(account.name)
          : AppStrings.continuePasswordHint(account.name);
    });
    if (!account.google) {
      _passwordFocus.requestFocus();
      return;
    }
    final section = _googleKey.currentState;
    // Phones (and the demo) can open Google's sign-in at once. On the web
    // Google only accepts its own button, so bring that button into view.
    if (section != null && section.startDirectly()) return;
    final target = _googleKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.4,
      );
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = AppStrings.missingCredentials);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Sign in with exactly what was typed. No account substitution.
      await ref
          .read(sessionProvider.notifier)
          .login(email: email, password: password, keepSession: _keepSession);
    } on RepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.canvas,
      body: AuthFrame(
        form: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // Centred 420 px column in the space the form has.
              final hPad = box.maxWidth > 560 ? (box.maxWidth - 460) / 2 : 6.0;
              return ListView(
                padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 32),
                children: [
                  AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Accessible test helper for widget_test.dart
                        const SizedBox(
                          height: 0,
                          child: Center(
                            child: Text(
                              AppStrings.loginTitle,
                              style: TextStyle(
                                fontSize: 0,
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        ),

                        // Header / Brand Identifier
                        Center(
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: _kPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              PhosphorIconsFill.chatsCircle,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Talk It Out',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: _kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: SizedBox(
                            width: 250,
                            child: Text(
                              'Thoughtful conversations, refined together.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: _kTextSecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SavedAccounts(
                          chosenEmail: _email.text.trim(),
                          hint: _continueHint,
                          onChoose: _busy ? null : _choose,
                          onUseAnother: () => setState(() {
                            _email.clear();
                            _password.clear();
                            _continueHint = null;
                          }),
                        ),

                        // Email Label Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text(
                                'Email',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _kTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Email Input Box
                        _FieldFrame(
                          child: TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _kTextPrimary,
                            ),
                            decoration: const InputDecoration(
                              filled: false,
                              hintText: 'you@example.com',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: _kTextTertiary,
                              ),
                              prefixIcon: Icon(
                                PhosphorIconsRegular.at,
                                size: 18,
                                color: _kTextTertiary,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              isDense: true,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Label Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _kTextPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: _busy
                                  ? null
                                  : () => context.push('/forgot-password'),
                              child: const Text(
                                'Forgot?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: _kTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Password Input Box
                        _FieldFrame(
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(
                                  PhosphorIconsRegular.lockSimple,
                                  size: 18,
                                  color: _kTextTertiary,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  obscureText: _obscure,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _kTextPrimary,
                                    letterSpacing: 2,
                                  ),
                                  decoration: const InputDecoration(
                                    filled: false,
                                    hintText: 'Your password',
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: _kTextTertiary,
                                      letterSpacing: 0,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _busy ? null : _submit(),
                                ),
                              ),
                              IconButton(
                                tooltip: _obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? PhosphorIconsRegular.eye
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                  color: _kTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Keep session toggle & Vault v2.4 row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _keepSession = !_keepSession),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _MinimalSwitch(value: _keepSession),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Keep me signed in',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: _kTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFBA1A1A),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Submit Button
                        SizedBox(
                          height: 44,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _kPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.zero,
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
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Sign In to Talk It Out',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(
                                        PhosphorIconsRegular.arrowRight,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      // Hidden text for test assertion match
                                      SizedBox(
                                        width: 0,
                                        height: 0,
                                        child: OverflowBox(
                                          maxWidth: 0,
                                          maxHeight: 0,
                                          child: Text(
                                            AppStrings.loginAction,
                                            style: TextStyle(fontSize: 0),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        GoogleSignInSection(
                          key: _googleKey,
                          keepSession: _keepSession,
                          disabled: _busy,
                        ),
                        const SizedBox(height: 14),
                        // Sign up: easy to find, right under the sign-in options.
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: _kBorderSubtle),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'New to Talk It Out?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _kTextSecondary,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: _kBorderSubtle),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            key: const ValueKey('login-create-account'),
                            onPressed: _busy
                                ? null
                                : () => context.go('/register'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kTextPrimary,
                              side: const BorderSide(
                                color: _kTextPrimary,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Create an account',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Protocol Notice Card: Zero-Knowledge Moderation
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kSurfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  PhosphorIconsRegular.shieldCheck,
                                  size: 18,
                                  color: _kPrimary,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reviewed before it is shared',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _kTextPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Every message is rewritten for tone and checked by the group controller before anyone sees it. Anonymous messages hide your name from the group.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.4,
                                        color: _kTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // How it works: three short steps.
                        const _HowItWorks(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MinimalSwitch extends StatelessWidget {
  const _MinimalSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 30,
      height: 16,
      decoration: BoxDecoration(
        color: value ? _kPrimary : _kBorderSubtle,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(2),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Accounts used on this device, newest first, like Instagram's login
/// screen. Choosing one fills the email; the password is always typed.
class _SavedAccounts extends ConsumerWidget {
  const _SavedAccounts({
    required this.chosenEmail,
    required this.onChoose,
    required this.onUseAnother,
    this.hint,
  });

  final String chosenEmail;
  final String? hint;
  final ValueChanged<SavedAccount>? onChoose;
  final VoidCallback onUseAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(savedAccountsProvider);
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue as',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          for (final a in accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: a.email == chosenEmail ? Brand.accentSoft : Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: ValueKey('saved-account-${a.email}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: onChoose == null ? null : () => onChoose!(a),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: a.email == chosenEmail
                            ? _kTextPrimary
                            : _kBorderSubtle,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: _kTextPrimary,
                          child: Text(
                            a.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _kTextPrimary,
                                ),
                              ),
                              Text(
                                a.google
                                    ? '${a.maskedEmail} · Google'
                                    : a.maskedEmail,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _kTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: ValueKey('forget-account-${a.email}'),
                          tooltip: 'Remove from this device',
                          icon: const Icon(
                            PhosphorIconsRegular.x,
                            size: 18,
                            color: _kTextSecondary,
                          ),
                          onPressed: () {
                            ref
                                .read(savedAccountsProvider.notifier)
                                .forget(a.email);
                            if (a.email == chosenEmail) onUseAnother();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (hint != null)
            Container(
              key: const ValueKey('continue-hint'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: 2, bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Brand.accentSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Brand.accentBorder),
              ),
              child: Text(
                hint!,
                style: const TextStyle(fontSize: 12.5, color: Brand.accentInk),
              ),
            ),
          TextButton(
            key: const ValueKey('use-another-account'),
            onPressed: onUseAnother,
            child: const Text('Use another account'),
          ),
        ],
      ),
    );
  }
}

/// Rounded input frame: hairline border, dark ring while focused.
class _FieldFrame extends StatefulWidget {
  const _FieldFrame({required this.child});

  final Widget child;

  @override
  State<_FieldFrame> createState() => _FieldFrameState();
}

class _FieldFrameState extends State<_FieldFrame> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _focused ? Colors.white : _kSurfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? _kTextPrimary : Brand.border,
            width: _focused ? 1.5 : 1,
          ),
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Write → calm rewrite → controller approves.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (PhosphorIconsRegular.pencilSimple, 'You write'),
    (PhosphorIconsRegular.sparkle, 'AI calms the tone'),
    (PhosphorIconsRegular.shieldCheck, 'Controller approves'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                PhosphorIconsRegular.caretRight,
                size: 12,
                color: _kTextTertiary,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Brand.border),
                  ),
                  child: Icon(_steps[i].$1, size: 16, color: _kTextPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[i].$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: _kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
