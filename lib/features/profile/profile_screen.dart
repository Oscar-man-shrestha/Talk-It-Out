import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talk_it_out/core/strings/app_strings.dart';
import 'package:talk_it_out/core/ui/screen_async.dart';
import 'package:talk_it_out/core/widgets/async_body.dart';
import 'package:talk_it_out/features/auth/session_controller.dart';

// Stitch Monochrome Precision tokens
const _kPrimary = Color(0xFF09090B);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceMuted = Color(0xFFF4F4F5);
const _kSurfaceSubtle = Color(0xFFFAFAFA);
const _kBorderSubtle = Color(0xFFE4E4E7);
const _kTextPrimary = Color(0xFF09090B);
const _kTextSecondary = Color(0xFF71717A);
const _kTextTertiary = Color(0xFFA1A1AA);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _salts = [
    '#7b99c8f2...9f2a',
    '#3e41b99a...6d8c',
    '#91a0c842...4aa1',
    '#19fec390...7e0b',
  ];
  int _saltIndex = 0;

  static const _tones = [
    'Professional & Diplomatic',
    'Direct & Concise',
    'Socratic & Inquisitive',
    'Empathetic & Supportive',
  ];
  int _toneIndex = 0;

  void _rotateSalt() {
    setState(() {
      _saltIndex = (_saltIndex + 1) % _salts.length;
    });
  }

  void _cycleTone() {
    setState(() {
      _toneIndex = (_toneIndex + 1) % _tones.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final user = session.value;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth > 860 ? (screenWidth - 800) / 2 : 16.0;

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            border: Border(bottom: BorderSide(color: _kBorderSubtle)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.chat_bubble,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'TALK IT OUT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: _kTextPrimary,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: _kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Talk It Out Profile',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 20,
                      color: _kTextSecondary,
                    ),
                    onPressed: () {},
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AsyncBody(
        status: asyncStatus(session, isEmpty: user == null),
        errorMessage: errorText(session.error),
        onRetry: () => ref.invalidate(sessionProvider),
        empty: const Center(child: Text(AppStrings.profileTitle)),
        child: user == null
            ? const SizedBox.shrink()
            : ListView(
                padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 48),
                children: [
                  // Blueprint Technical Grid Profile Identity Banner (matches image5)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CustomPaint(
                      painter: const _GridPatternPainter(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: _kSurface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kBorderSubtle),
                        ),
                        child: Column(
                          children: [
                            // Avatar circle with ZK-ACTIVE badge
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: const BoxDecoration(
                                    color: _kPrimary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x1F000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'AM',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kPrimary,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'ZK-ACTIVE',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Name & Verified Checkmark
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Alex Morgan',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: _kTextPrimary,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: _kPrimary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'alex.morgan@domain.com',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: _kTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Dual Role Badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kSurface,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: _kBorderSubtle),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x08000000),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'CONTRIBUTOR',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kPrimary,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.security,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'VERIFIED CONTROLLER',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Peer Anonymity Shield Card (Delight Micro-Interaction)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kSurfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
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
                                  child: const Icon(
                                    Icons.fingerprint,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PEER ANONYMITY SHIELD',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: _kTextPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Ephemeral mask enabled',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _kTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: _rotateSalt,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kSurface,
                                foregroundColor: _kTextPrimary,
                                elevation: 0.5,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(0, 32),
                              ),
                              icon: const Icon(Icons.sync, size: 14),
                              label: const Text(
                                'Rotate',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _kSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'SALT: ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: _kTextTertiary,
                                    ),
                                  ),
                                  Text(
                                    _salts[_saltIndex],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _kSurfaceMuted,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '12h left',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _kTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Metrics 2x2 Bento Grid (matches image5)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.35,
                    children: [
                      // Card 1: Groups Joined
                      const _BentoCard(
                        title: 'GROUPS JOINED',
                        icon: Icons.groups_outlined,
                        value: '14',
                        subtitle: 'active squads',
                      ),
                      // Card 2: Contributions
                      const _BentoCard(
                        title: 'CONTRIBUTIONS',
                        icon: Icons.forum_outlined,
                        value: '38',
                        subtitle: '+5 this week',
                      ),
                      // Card 3: AI Clarity
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kSurfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'AI CLARITY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: _kTextSecondary,
                                  ),
                                ),
                                Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: _kTextSecondary,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '94%',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                        color: _kTextPrimary,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Top 5%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _kTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 4,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _kSurfaceMuted,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: 0.94,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _kPrimary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Diplomatic clarity',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _kTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Card 4: Moderated
                      const _BentoCard(
                        title: 'MODERATED',
                        icon: Icons.gavel_outlined,
                        value: '3',
                        subtitle: 'squad spaces',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Cryptographic Privacy Guarantee Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kSurfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorderSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _kSurface,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: _kPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cryptographic Decoupling',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kTextPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your direct profile identity is mathematically decoupled from submissions via blinded Schnorr signatures. Even platform controllers cannot correlate your identity to discourse entries.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: _kTextSecondary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.lock, size: 12, color: _kPrimary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Zero-Knowledge Ratchet v2.4',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: _kTextPrimary,
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
                  const SizedBox(height: 16),

                  // Preferences & Governance Navigation Menu (matches image5)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'PREFERENCES & GOVERNANCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: _kTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _kSurfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorderSubtle),
                    ),
                    child: Column(
                      children: [
                        _PreferenceTile(
                          icon: Icons.vpn_key_outlined,
                          title: 'Account & Security',
                          subtitle: 'Passkeys, Hardware 2FA linked',
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: _kTextTertiary,
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 1, color: _kBorderSubtle),
                        _PreferenceTile(
                          icon: Icons.notifications_none_outlined,
                          title: 'Notification Preferences',
                          subtitle: 'Summary digest & mention alerts',
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: _kTextTertiary,
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 1, color: _kBorderSubtle),
                        _PreferenceTile(
                          icon: Icons.tune_outlined,
                          title: 'AI Rephrase Tone',
                          subtitle: _tones[_toneIndex],
                          trailing: OutlinedButton(
                            onPressed: _cycleTone,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              side: const BorderSide(color: _kBorderSubtle),
                              minimumSize: const Size(0, 28),
                            ),
                            child: const Text(
                              'Adjust',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _kTextPrimary,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: _kBorderSubtle),
                        _PreferenceTile(
                          icon: Icons.archive_outlined,
                          title: 'My Messages & Submissions',
                          subtitle: '38 encrypted records',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _kSurfaceMuted,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '38',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: _kTextSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: _kTextTertiary,
                              ),
                            ],
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 1, color: _kBorderSubtle),
                        _PreferenceTile(
                          icon: Icons.download_for_offline_outlined,
                          title: 'Data & Privacy Export',
                          subtitle: 'Cryptographic ledger audit log',
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: _kTextTertiary,
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bottom Actions: Logout Button (matches image5)
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).logout(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kBorderSubtle),
                        foregroundColor: _kTextPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Signed Footer Micro-copy (matches image5)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: _kTextSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Talk It Out Engine • End-to-End Signed',
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

class _GridPatternPainter extends CustomPainter {
  const _GridPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE4E4E7).withValues(alpha: 0.55)
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final IconData icon;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kSurfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: _kTextSecondary,
                ),
              ),
              Icon(icon, size: 16, color: _kTextSecondary),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: _kTextPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: _kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _kTextSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
