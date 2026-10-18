import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';

// Stitch Monochrome Precision tokens
const _kPrimary = Color(0xFF000000);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kSurfaceSubtle = Color(0xFFFAFAFA);
const _kBorderSubtle = Color(0xFFE4E4E7);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);
const _kEmerald = Color(0xFF10B981);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController(text: 'Maya Lin');
  final _email = TextEditingController(text: 'maya.lin@domain.com');
  final _password = TextEditingController(text: 'RefinedTalk2024!');
  final _confirmPassword = TextEditingController(text: 'RefinedTalk2024!');

  var _obscurePassword = true;
  var _obscureConfirm = true;
  var _agreeToTerms = true;
  var _selectedRole = 'contributor'; // 'contributor' | 'controller'
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

  void _fillPersona(String role) {
    setState(() {
      _selectedRole = role;
      if (role == 'contributor') {
        _name.text = 'Maya Lin';
        _email.text = 'maya.lin@domain.com';
        _password.text = 'RefinedTalk2024!';
        _confirmPassword.text = 'RefinedTalk2024!';
      } else {
        _name.text = 'Julian Vance';
        _email.text = 'j.vance@governance.net';
        _password.text = 'ControlProtocol#2024';
        _confirmPassword.text = 'ControlProtocol#2024';
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_agreeToTerms) {
      setState(() => _error = 'Please agree to the Terms of Service.');
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 640 ? (screenWidth - 440) / 2 : 16.0;

    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 36),
          children: [
            // Top App Bar row with logo and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                        Icons.chat_bubble,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Talk It Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: _kTextPrimary,
                      ),
                    ),
                  ],
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
                        'V2.4 SECURE',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
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
              style: TextStyle(fontSize: 13, color: _kTextSecondary),
            ),
            const SizedBox(height: 18),

            // Quick Fill Persona Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kSurfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'QUICK FILL PERSONA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: _kTextTertiary,
                        ),
                      ),
                      Text(
                        'Tap to preview role defaults',
                        style: TextStyle(fontSize: 11, color: _kTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Contributor Button
                      Expanded(
                        child: InkWell(
                          onTap: () => _fillPersona('contributor'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'contributor'
                                  ? _kSurfaceMuted
                                  : _kSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedRole == 'contributor'
                                    ? _kTextPrimary
                                    : _kBorderSubtle,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  size: 18,
                                  color: _kTextSecondary,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Contributor',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _kTextPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Maya Lin',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _kTextTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.north_east,
                                  size: 13,
                                  color: _kTextTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Controller Button
                      Expanded(
                        child: InkWell(
                          onTap: () => _fillPersona('controller'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedRole == 'controller'
                                  ? _kSurfaceMuted
                                  : _kSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedRole == 'controller'
                                    ? _kTextPrimary
                                    : _kBorderSubtle,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 18,
                                  color: _kTextSecondary,
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Controller',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _kTextPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Julian Vance',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _kTextTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.north_east,
                                  size: 13,
                                  color: _kTextTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                    fontFamily: 'monospace',
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
                style: const TextStyle(fontSize: 13, color: _kTextPrimary),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: _kTextTertiary,
                  ),
                  hintText: 'e.g. Maya Lin',
                  hintStyle: TextStyle(fontSize: 13, color: _kTextTertiary),
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Work / Personal Email',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.verified, size: 12, color: _kPrimary),
                    SizedBox(width: 3),
                    Text(
                      'Domain check ready',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: _kTextSecondary,
                      ),
                    ),
                  ],
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
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 13, color: _kTextPrimary),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.alternate_email,
                    size: 18,
                    color: _kTextTertiary,
                  ),
                  suffixIcon: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: _kTextPrimary,
                  ),
                  hintText: 'maya.lin@domain.com',
                  hintStyle: TextStyle(fontSize: 13, color: _kTextTertiary),
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
                    fontFamily: 'monospace',
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
                style: const TextStyle(fontSize: 13, color: _kTextPrimary),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: _kTextTertiary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 18,
                      color: _kTextTertiary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
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
                style: const TextStyle(fontSize: 13, color: _kTextPrimary),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.lock_clock_outlined,
                    size: 18,
                    color: _kTextTertiary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                      size: 18,
                      color: _kTextTertiary,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
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
                      onChanged: (val) =>
                          setState(() => _agreeToTerms = val ?? true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'I agree to the Terms of Service & Privacy Policy',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary,
                          ),
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
                            const Text(
                              'End-to-end encrypted identity shielding',
                              style: TextStyle(
                                fontSize: 11,
                                color: _kTextSecondary,
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
                style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 12),
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
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Already have an account? Sign in
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(fontSize: 13, color: _kTextSecondary),
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

            // Footer Micro-badges
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_reset, size: 14, color: _kTextTertiary),
                SizedBox(width: 4),
                Text(
                  'Zero telemetry mode',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: _kTextTertiary,
                  ),
                ),
                SizedBox(width: 8),
                Text('•', style: TextStyle(color: _kTextTertiary)),
                SizedBox(width: 8),
                Icon(Icons.fingerprint, size: 14, color: _kTextTertiary),
                SizedBox(width: 4),
                Text(
                  'FIDO2 ready',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: _kTextTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
