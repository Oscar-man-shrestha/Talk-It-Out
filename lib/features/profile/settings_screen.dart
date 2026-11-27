part of 'profile_screen.dart';

/// Settings: account and app preferences, kept apart from the profile
/// (which is about who you are). Grouped like iOS and Instagram settings:
/// Premium, Preferences, Account, About.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.passwordChanged)));
    }
  }

  Future<void> _inviteFriends() async {
    final text = inviteFriendsText();
    final messenger = ScaffoldMessenger.of(context);
    if (!await shareText(text, subject: 'Talk It Out')) {
      await Clipboard.setData(ClipboardData(text: text));
      messenger.showSnackBar(
        const SnackBar(content: Text('Invite copied. Paste it anywhere.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).value;
    final profile = ref.watch(userProfileProvider);
    final hPad = pageHPad(MediaQuery.sizeOf(context).width, maxContent: 680);

    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(PhosphorIconsRegular.caretLeft),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 40),
        children: [
          // Who is signed in (tap to see the profile).
          _SettingsAccountHeader(
            name: user?.name ?? profile.name,
            email: user?.email ?? '',
            avatarUrl: profile.avatarUrl,
          ),
          const SizedBox(height: 20),

          const _SettingsSectionLabel('Premium'),
          const PremiumProfileCard(),
          const SizedBox(height: 10),
          const PremiumToolsCard(),
          const SizedBox(height: 22),

          const _SettingsSectionLabel('Preferences'),
          _FeedInterestsCard(
            interests: ref.watch(interestsProvider).value,
            onEdit: () => context.push('/feed/interests'),
            onPersonalized: (on) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(interestsProvider.notifier).setPersonalized(on);
              } on RepositoryException catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _PreferenceTile(
                icon: PhosphorIconsRegular.shield,
                title: 'Default Tone Target',
                subtitle:
                    '${_ProfileScreenState._tones[profile.toneIndex]} · named messages only',
                trailing: const Icon(
                  PhosphorIconsRegular.slidersHorizontal,
                  size: 16,
                  color: _kTextSecondary,
                ),
                onTap: () => ref.read(userProfileProvider.notifier).cycleTone(),
              ),
              _PreferenceTile(
                key: const ValueKey('profile-blocked'),
                icon: PhosphorIconsRegular.prohibit,
                title: 'Blocked people',
                subtitle:
                    'People you blocked cannot find you or see your questions.',
                trailing: const _SettingsChevron(),
                onTap: () => context.push('/blocked'),
              ),
            ],
          ),
          const SizedBox(height: 22),

          const _SettingsSectionLabel('Account and security'),
          _SettingsGroup(
            children: [
              _PreferenceTile(
                icon: Icons.password,
                title: AppStrings.changePassword,
                subtitle: AppStrings.changePasswordSubtitle,
                trailing: const _SettingsChevron(),
                onTap: _openChangePassword,
              ),
              _PreferenceTile(
                icon: Icons.devices_other,
                title: AppStrings.logoutAll,
                subtitle: AppStrings.logoutAllSubtitle,
                trailing: const _SettingsChevron(),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => const _LogoutAllDialog(),
                ),
              ),
              _PreferenceTile(
                icon: PhosphorIconsRegular.signOut,
                title: AppStrings.logout,
                subtitle: 'Signs you out on this device',
                trailing: const _SettingsChevron(),
                onTap: () => ref.read(sessionProvider.notifier).logout(),
              ),
              _PreferenceTile(
                icon: PhosphorIconsRegular.trash,
                title: AppStrings.deleteAccount,
                subtitle: AppStrings.deleteAccountSubtitle,
                trailing: const _SettingsChevron(),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => const _DeleteAccountDialog(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          const _SettingsSectionLabel('About'),
          _SettingsGroup(
            children: [
              _PreferenceTile(
                key: const ValueKey('profile-invite-friends'),
                icon: Icons.favorite_outline,
                title: 'Invite friends to Talk It Out',
                subtitle: 'Safer conversations need more people in them.',
                trailing: const Icon(
                  Icons.ios_share,
                  size: 16,
                  color: _kTextSecondary,
                ),
                onTap: _inviteFriends,
              ),
              for (final (path, label, icon) in const [
                ('privacy', 'Privacy policy', PhosphorIconsRegular.lockSimple),
                ('terms', 'Terms of use', PhosphorIconsRegular.scales),
                (
                  'delete-account',
                  'How deletion works',
                  PhosphorIconsRegular.info,
                ),
              ])
                _PreferenceTile(
                  key: ValueKey('profile-legal-$path'),
                  icon: icon,
                  title: label,
                  subtitle: null,
                  trailing: const _SettingsChevron(),
                  onTap: () => context.push('/legal/$path'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsAccountHeader extends StatelessWidget {
  const _SettingsAccountHeader({
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  final String name;
  final String email;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Surfaces.radius),
        side: const BorderSide(color: Brand.border),
      ),
      child: InkWell(
        key: const ValueKey('settings-open-profile'),
        onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Brand.ink,
                backgroundImage: avatarUrl == null
                    ? null
                    : NetworkImage(avatarUrl!),
                child: avatarUrl == null
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Brand.ink,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Brand.inkSoft,
                        ),
                      ),
                    const SizedBox(height: 2),
                    const Text(
                      'View profile',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const _SettingsChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Brand.inkSoft,
        ),
      ),
    );
  }
}

/// White rounded group of rows with hairline dividers.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Surfaces.radius),
        side: const BorderSide(color: Brand.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Brand.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsChevron extends StatelessWidget {
  const _SettingsChevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      PhosphorIconsRegular.caretRight,
      size: 14,
      color: Brand.inkFaint,
    );
  }
}
