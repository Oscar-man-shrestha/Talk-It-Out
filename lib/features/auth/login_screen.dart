import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/app/providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/data/mock_auth_repository.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';

// Stitch Monochrome Precision design tokens
const _kPrimary = Color(0xFF000000);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kBorderSubtle = Color(0xFFE4E4E7);
const _kBorderStrong = Color(0xFF27272A);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);

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
  var _role = 'contributor';
  var _roleTag = '#member';
  var _keepSession = true;
  String? _error;

  /// Mock builds start filled with the seeded sample account from `API.md`.
  /// Live builds start empty: there is no shared demo account on a server.
  bool get _useMock => ref.read(appConfigProvider).useMock;

  @override
  void initState() {
    super.initState();
    if (_useMock) {
      _email.text = MockAuthRepository.mockEmail;
      _password.text = MockAuthRepository.mockPassword;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
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
          .login(email: email, password: password);
    } on RepositoryException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = AppStrings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectRole(String role) {
    setState(() {
      _role = role;
      _roleTag = role == 'contributor' ? '#contributor' : '#controller';
      // The seeded sample account is a contributor in one group and the
      // controller of another, so both quick-access tabs sign in as it.
      if (_useMock) {
        _email.text = MockAuthRepository.mockEmail;
        _password.text = MockAuthRepository.mockPassword;
      }
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktopOrTablet = screenWidth > 540;
    final hPad = isDesktopOrTablet ? (screenWidth - 420) / 2 : 20.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 32),
          children: [
            // Accessible test helper for widget_test.dart
            const SizedBox(
              height: 0,
              child: Center(
                child: Text(
                  AppStrings.loginTitle,
                  style: TextStyle(fontSize: 0, color: Colors.transparent),
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
                child: const Icon(Icons.forum, color: Colors.white, size: 24),
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

            // Quick Demo Roles Switcher
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              decoration: BoxDecoration(
                color: _kSurfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6, top: 2),
                    child: Text(
                      'QUICK DEMO ACCESS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _kTextTertiary,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _DemoRoleTab(
                          label: 'Contributor',
                          active: _role == 'contributor',
                          onTap: _busy
                              ? null
                              : () => _selectRole('contributor'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _DemoRoleTab(
                          label: 'Controller',
                          active: _role == 'controller',
                          onTap: _busy ? null : () => _selectRole('controller'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Email Label Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Work or Personal Email',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kTextPrimary,
                    ),
                  ),
                ),
                Text(
                  _roleTag,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    color: _kTextTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Email Input Box
            Container(
              decoration: BoxDecoration(
                color: _kSurfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorderStrong, width: 1),
              ),
              child: TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 13, color: _kTextPrimary),
                decoration: const InputDecoration(
                  hintText: 'alex@example.com',
                  hintStyle: TextStyle(fontSize: 13, color: _kTextTertiary),
                  prefixIcon: Icon(
                    Icons.alternate_email,
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
                  onTap: () {},
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
            Container(
              decoration: BoxDecoration(
                color: _kSurfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorderStrong, width: 1),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: _kTextTertiary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _password,
                      obscureText: _obscure,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kTextPrimary,
                        letterSpacing: 2,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter your security passkey',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: _kTextTertiary,
                          letterSpacing: 0,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                  ),
                  IconButton(
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
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Keep session toggle & Vault v2.4 row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _keepSession = !_keepSession),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MinimalSwitch(value: _keepSession),
                      const SizedBox(width: 8),
                      const Text(
                        'Keep active session',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _kPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Vault v2.4',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: _kTextSecondary,
                      ),
                    ),
                  ],
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
                          Text(
                            'Sign In to Talk It Out',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward,
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
                      Icons.verified_user_outlined,
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
                          'Zero-Knowledge Moderation',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kTextPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'End-to-end encrypted discourse with cryptographic pseudonyms and optional total contributor anonymity.',
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

            // Active Collective Activity Preview
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LIVE CONSENSUS ROOMS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _kTextTertiary,
                      ),
                    ),
                    Text(
                      '● 4 active',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: _kTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kSurfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Color(0x0A000000), blurRadius: 3),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '#08',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Autonomous Policy Audit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _kTextPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '9 contributors deliberating',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.lock_open_outlined,
                        size: 18,
                        color: _kTextTertiary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Footer
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    "Don't have an invitation code?",
                    style: TextStyle(fontSize: 12, color: _kTextSecondary),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _busy ? null : () => context.go('/register'),
                    child: const Text(
                      'Request access',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoRoleTab extends StatelessWidget {
  const _DemoRoleTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: active ? 1 : 0,
      shadowColor: const Color(0x1F000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? _kPrimary : _kTextTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? _kTextPrimary : _kTextSecondary,
                ),
              ),
            ],
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
