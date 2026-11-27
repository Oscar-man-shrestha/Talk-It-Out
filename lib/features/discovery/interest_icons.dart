import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

/// Interest icon names from the API (`API.md` 54) as vector icons, so
/// interests look the same on every device instead of depending on emoji
/// fonts.
const Map<String, IconData> _icons = {
  'backpack': Icons.backpack_outlined,
  'balance': Icons.balance,
  'campaign': Icons.campaign_outlined,
  'code': PhosphorIconsRegular.code,
  'design': Icons.palette_outlined,
  'diversity': PhosphorIconsRegular.usersThree,
  'explore': PhosphorIconsRegular.compass,
  'family_restroom': Icons.family_restroom,
  'flight_takeoff': Icons.flight_takeoff,
  'gavel': Icons.gavel,
  'groups': Icons.groups_outlined,
  'handshake': Icons.handshake_outlined,
  'home_work': Icons.home_work_outlined,
  'insights': Icons.insights,
  'payments': Icons.payments_outlined,
  'person_search': Icons.person_search_outlined,
  'policy': PhosphorIconsRegular.scales,
  'psychology': Icons.psychology_outlined,
  'record_voice_over': Icons.record_voice_over_outlined,
  'redeem': Icons.redeem,
  'rocket': Icons.rocket_launch_outlined,
  'savings': Icons.savings_outlined,
  'school': PhosphorIconsRegular.graduationCap,
  'shield': PhosphorIconsRegular.shield,
  'spa': Icons.spa_outlined,
  'support_agent': Icons.support_agent,
  'timer': Icons.timer_outlined,
  'trending_up': Icons.trending_up,
  'work_outline': PhosphorIconsRegular.briefcase,
  'work_search': Icons.work_history_outlined,
};

/// Every icon name the app knows (tests check the server uses only these).
Iterable<String> get knownInterestIcons => _icons.keys;

IconData interestIcon(String name) => _icons[name] ?? Icons.label_outline;
