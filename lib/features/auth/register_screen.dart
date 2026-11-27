import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/features/auth/google/google_sign_in_section.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/auth/auth_frame.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

// Stitch Monochrome Precision tokens
const _kPrimary = Brand.accent;
const _kSurface = Brand.card;
const _kSurfaceMuted = Brand.muted;
const _kSurfaceSubtle = Brand.canvas;
const _kBorderSubtle = Brand.border;
const _kTextPrimary = Brand.ink;
const _kTextSecondary = Brand.inkSoft;
const _kTextTertiary = Brand.inkFaint;
const _kEmerald = Color(0xFF10B981);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  var _obscurePassword = true;
  var _obscureConfirm = true;
  var _agreeToTerms = false;

  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_agreeToTerms) {
      setState(() => _error = 'Please agree to the Terms of Service.');
      return;
    }
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      setState(() => _error = AppStrings.missingAccountFields);
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = AppStrings.passwordTooShort);
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
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
      backgroundColor: _kSurface,
      body: AuthFrame(
        form: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // Centred 440 px column in the space the form has.
              final hPad = box.maxWidth > 580 ? (box.maxWidth - 480) / 2 : 6.0;
              return ListView(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 36),
                children: [
                  AuthCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top App Bar row with logo and status badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: _kPrimary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      PhosphorIconsFill.chatCircle,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: const Text(
                                      'Talk It Out',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                        color: _kTextPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _kSurfaceMuted,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: _kEmerald,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'PRIVATE BY DESIGN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: _kTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Main Title & Subtitle
                        const Text(
                          'Create your account',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: _kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Thoughtful group conversations, refined together.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _kTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Form Fields
                        // 1. Full Name
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Full Name',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kTextPrimary,
                              ),
                            ),
                            Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 10,
                                color: _kTextTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: _kSurfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorderSubtle),
                          ),
                          child: TextField(
                            controller: _name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _kTextPrimary,
                            ),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                PhosphorIconsRegular.user,
                                size: 18,
                                color: _kTextTertiary,
                              ),
                              hintText: 'Your full name',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: _kTextTertiary,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 2. Work or Personal Email
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: _kSurfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorderSubtle),
                          ),
                          child: TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _kTextPrimary,
                            ),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                PhosphorIconsRegular.at,
                                size: 18,
                                color: _kTextTertiary,
                              ),
                              suffixIcon: Icon(
                                PhosphorIconsFill.checkCircle,
                                size: 16,
                                color: _kTextPrimary,
                              ),
                              hintText: 'you@example.com',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: _kTextTertiary,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3. Password
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kTextPrimary,
                              ),
                            ),
                            Text(
                              '8+ chars minimum',
                              style: TextStyle(
                                fontSize: 10,
                                color: _kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: _kSurfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorderSubtle),
                          ),
                          child: TextField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _kTextPrimary,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                PhosphorIconsRegular.lockSimple,
                                size: 18,
                                color: _kTextTertiary,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? PhosphorIconsRegular.eye
                                      : Icons.visibility_off,
                                  size: 18,
                                  color: _kTextTertiary,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                              hintText: '••••••••••••',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: _kTextTertiary,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 4. Confirm Password
                        const Text(
                          'Confirm Password',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: _kSurfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorderSubtle),
                          ),
                          child: TextField(
                            controller: _confirmPassword,
                            obscureText: _obscureConfirm,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _kTextPrimary,
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.lock_clock_outlined,
                                size: 18,
                                color: _kTextTertiary,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? PhosphorIconsRegular.eye
                                      : Icons.visibility_off,
                                  size: 18,
                                  color: _kTextTertiary,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                              hintText: '••••••••••••',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: _kTextTertiary,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Terms & Privacy Checkbox Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kSurfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorderSubtle),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _agreeToTerms,
                                  activeColor: _kPrimary,
                                  onChanged: (val) => setState(
                                    () => _agreeToTerms = val ?? true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Text(
                                          'I am 18+ and agree to the ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _kTextPrimary,
                                          ),
                                        ),
                                        GestureDetector(
                                          key: const ValueKey('register-terms'),
                                          onTap: () =>
                                              context.push('/legal/terms'),
                                          child: const Text(
                                            'Terms',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _kTextPrimary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                        const Text(
                                          ' and ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _kTextPrimary,
                                          ),
                                        ),
                                        GestureDetector(
                                          key: const ValueKey(
                                            'register-privacy',
                                          ),
                                          onTap: () =>
                                              context.push('/legal/privacy'),
                                          child: const Text(
                                            'Privacy Policy',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _kTextPrimary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.shield,
                                            size: 12,
                                            color: _kPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Expanded(
                                          child: Text(
                                            'Anonymous to the group, visible to the controller',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _kTextSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFBA1A1A),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),

                        // Create Account Submit Button
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
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
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(
                                        PhosphorIconsRegular.arrowRight,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        // Sign up with Google: creates the account the first
                        // time (the same Google flow as Sign in).
                        GoogleSignInSection(keepSession: true, disabled: _busy),
                        const SizedBox(height: 16),

                        // Already have an account? Sign in
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: _kTextSecondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Footer note (true statements only).
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_reset,
                              size: 14,
                              color: _kTextTertiary,
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Message text is never logged',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _kTextTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
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
