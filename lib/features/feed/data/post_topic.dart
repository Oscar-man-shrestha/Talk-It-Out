import 'package:flutter/material.dart';
import 'package:talk_it_out/core/ui/app_icons.dart';

/// The fixed feed topics (`API.md` 42). [id] is what the API stores.
class PostTopic {
  const PostTopic(this.id, this.label, this.icon, this.keywords);

  final String id;
  final String label;
  final IconData icon;

  /// Used only for older posts that have no topic.
  final List<String> keywords;

  static const all = <PostTopic>[
    PostTopic(
      'workplace_policy',
      'Workplace Policy',
      PhosphorIconsRegular.scales,
      ['policy', 'workplace', 'remote'],
    ),
    PostTopic(
      'engineering',
      'Engineering & Tech',
      PhosphorIconsRegular.terminalWindow,
      ['engineer', 'tech', 'dashboard', 'estimate', 'nlp'],
    ),
    PostTopic(
      'leadership',
      'Leadership & Exec',
      PhosphorIconsRegular.usersFour,
      ['lead', 'exec'],
    ),
    PostTopic(
      'compensation',
      'Compensation & Equity',
      PhosphorIconsRegular.coins,
      ['pay', 'equity', 'compensation'],
    ),
    PostTopic(
      'safety',
      'Psychological Safety',
      PhosphorIconsRegular.firstAidKit,
      ['safety', 'retro', 'psych'],
    ),
    PostTopic('culture', 'Ethics & Culture', PhosphorIconsRegular.usersThree, [
      'ethic',
      'culture',
      'offsite',
    ]),
  ];

  static PostTopic? byId(String? id) {
    for (final topic in all) {
      if (topic.id == id) return topic;
    }
    return null;
  }
}
