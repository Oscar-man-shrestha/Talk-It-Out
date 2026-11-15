import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:talk_it_out/app/repository_providers.dart';
import 'package:talk_it_out/core/errors/repository_exception.dart';
import 'package:talk_it_out/core/ui/brand.dart';
import 'package:talk_it_out/features/invites/invite_repository.dart';
import 'package:talk_it_out/core/share/share_links.dart';

/// The text people send on WhatsApp, Telegram and the like.
String inviteMessage(String agenda, InviteLink link) =>
    'Join "$agenda" on Talk It Out. Say what matters, anonymously if you '
    'need to: ${link.url}';

final _invitesProvider = FutureProvider.autoDispose
    .family<List<InviteLink>, String>(
      (ref, groupId) =>
          ref.watch(inviteRepositoryProvider).listInvites(groupId),
    );

/// Controller-only sheet: make a link (expiry and use limit), copy it,
/// share it, show a QR code, and turn old links off (`API.md` 61).
Future<void> showInviteSheet(
  BuildContext context, {
  required String groupId,
  required String agenda,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Brand.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => InviteSheet(groupId: groupId, agenda: agenda),
  );
}

class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({required this.groupId, required this.agenda, super.key});

  final String groupId;
  final String agenda;

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  int? _days = 7;
  int? _maxUses;
  InviteLink? _link;
  var _busy = false;
  var _showQr = false;
  String? _error;

  static const _expiry = <(int?, String)>[
    (1, '1 day'),
    (7, '7 days'),
    (30, '30 days'),
    (null, 'Never'),
  ];
  static const _uses = <(int?, String)>[
    (null, 'No limit'),
    (1, '1 person'),
    (10, '10 people'),
    (50, '50 people'),
  ];

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await ref
          .read(inviteRepositoryProvider)
          .createInvite(
            widget.groupId,
            expiresInDays: _days,
            maxUses: _maxUses,
          );
      ref.invalidate(_invitesProvider(widget.groupId));
      if (mounted) setState(() => _link = link);
    } on RepositoryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(InviteLink link) async {
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Brand.ink,
        content: Text('Invite link copied.'),
      ),
    );
  }

  Future<void> _share(InviteLink link) async {
    final shared = await shareText(
      inviteMessage(widget.agenda, link),
      subject: 'Join ${widget.agenda} on Talk It Out',
    );
    // No share sheet (some desktop browsers): copying still works.
    if (!shared) await _copy(link);
  }

  Future<void> _revoke(InviteLink link) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(inviteRepositoryProvider)
          .revokeInvite(widget.groupId, link.code);
      ref.invalidate(_invitesProvider(widget.groupId));
      if (_link?.code == link.code && mounted) setState(() => _link = null);
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Brand.ink,
          content: Text('Link turned off. It no longer works.'),
        ),
      );
    } on RepositoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _chips<T>(
    List<(T, String)> options,
    T value,
    ValueChanged<T> onPick,
    String keyPrefix,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (v, label) in options)
          ChoiceChip(
            key: ValueKey('$keyPrefix-$label'),
            label: Text(label),
            selected: v == value,
            onSelected: _busy ? null : (_) => onPick(v),
            selectedColor: Brand.ink,
            labelStyle: TextStyle(
              fontSize: 12.5,
              color: v == value ? Colors.white : Brand.ink,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final active = ref.watch(_invitesProvider(widget.groupId));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            children: [
              Text(
                'Invite people',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Brand.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Anyone with the link can join "${widget.agenda}" as a contributor. '
                'You still review every message before the group sees it.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Brand.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              if (link == null) ...[
                const Text(
                  'Link works for',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _chips<int?>(
                  _expiry,
                  _days,
                  (v) => setState(() => _days = v),
                  'invite-expiry',
                ),
                const SizedBox(height: 12),
                const Text(
                  'How many people can join',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _chips<int?>(
                  _uses,
                  _maxUses,
                  (v) => setState(() => _maxUses = v),
                  'invite-uses',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('invite-create'),
                  onPressed: _busy ? null : _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: Brand.ink,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link, size: 18),
                  label: const Text('Create invite link'),
                ),
              ] else ...[
                Container(
                  key: const ValueKey('invite-link-box'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Brand.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 18, color: Brand.inkSoft),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          link.url,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Brand.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _describe(link),
                  style: const TextStyle(fontSize: 12, color: Brand.inkSoft),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('invite-share'),
                        onPressed: () => _share(link),
                        style: FilledButton.styleFrom(
                          backgroundColor: Brand.ink,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('invite-copy'),
                        onPressed: () => _copy(link),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      key: const ValueKey('invite-qr'),
                      tooltip: _showQr ? 'Hide QR code' : 'Show QR code',
                      onPressed: () => setState(() => _showQr = !_showQr),
                      icon: const Icon(Icons.qr_code_2),
                    ),
                  ],
                ),
                if (_showQr) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Brand.border),
                      ),
                      child: QrImageView(
                        key: const ValueKey('invite-qr-image'),
                        data: link.url,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Point a phone camera at the code to join.',
                      style: TextStyle(fontSize: 12, color: Brand.inkSoft),
                    ),
                  ),
                ],
                TextButton(
                  onPressed: () => setState(() {
                    _link = null;
                    _showQr = false;
                  }),
                  child: const Text('Make another link'),
                ),
              ],
              const SizedBox(height: 10),
              active.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const Text(
                            'Active links',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          for (final i in items)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                '…/join/${i.code}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(_describe(i)),
                              trailing: TextButton(
                                key: ValueKey('invite-revoke-${i.code}'),
                                onPressed: () => _revoke(i),
                                child: Text(
                                  'Turn off',
                                  style: TextStyle(color: Colors.red.shade800),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _describe(InviteLink link) {
    final used = link.maxUses == null
        ? (link.uses == 1 ? '1 joined' : '${link.uses} joined')
        : '${link.uses} of ${link.maxUses} joined';
    final expires = link.expiresAt;
    if (expires == null) return '$used · never expires';
    final left = expires.difference(DateTime.now());
    final when = left.inHours < 24
        ? 'expires in ${left.inHours.clamp(1, 24)} h'
        : 'expires in ${(left.inHours / 24).ceil()} days';
    return '$used · $when';
  }
}
