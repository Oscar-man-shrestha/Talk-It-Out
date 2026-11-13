import 'package:flutter/material.dart';

/// The fixed feed topics (`API.md` 42). [id] is what the API stores.
class PostTopic {
  const PostTopic(this.id, this.label, this.icon, this.keywords);

  final String id;
  final String label;
  final IconData icon;

  /// Used only for older posts that have no topic.
  final List<String> keywords;

  static const all = <PostTopic>[
    PostTopic('workplace_policy', 'Workplace Policy', Icons.policy_outlined, [
      'policy',
      'workplace',
      'remote',
    ]),
    PostTopic('engineering', 'Engineering & Tech', Icons.terminal_rounded, [
      'engineer',
      'tech',
      'dashboard',
      'estimate',
      'nlp',
    ]),
    PostTopic(
      'leadership',
      'Leadership & Exec',
      Icons.supervisor_account_outlined,
      ['lead', 'exec'],
    ),
    PostTopic(
      'compensation',
      'Compensation & Equity',
      Icons.monetization_on_outlined,
      ['pay', 'equity', 'compensation'],
    ),
    PostTopic(
      'safety',
      'Psychological Safety',
      Icons.health_and_safety_outlined,
      ['safety', 'retro', 'psych'],
    ),
    PostTopic('culture', 'Ethics & Culture', Icons.diversity_3_outlined, [
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
