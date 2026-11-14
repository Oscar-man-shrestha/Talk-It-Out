import 'package:talk_it_out/features/discovery/data/discovery_models.dart';

/// The 15 feed interests, as the API lists them (`API.md` 54). The demo
/// data uses this list; live builds read it from the server.
const kInterestCatalog = <InterestOption>[
  InterestOption(
    id: 'workplace_policy',
    label: 'Workplace policy',
    emoji: '📋',
    blurb: 'Rules, leave, HR and how things are done',
  ),
  InterestOption(
    id: 'engineering',
    label: 'Engineering & tech',
    emoji: '💻',
    blurb: 'Code, systems, on-call and tech debt',
  ),
  InterestOption(
    id: 'leadership',
    label: 'Leadership',
    emoji: '🧭',
    blurb: 'Managers, execs and decisions',
  ),
  InterestOption(
    id: 'compensation',
    label: 'Pay & equity',
    emoji: '💰',
    blurb: 'Salary, raises, bonuses and equity',
  ),
  InterestOption(
    id: 'safety',
    label: 'Psychological safety',
    emoji: '🛡️',
    blurb: 'Speaking up without fear',
  ),
  InterestOption(
    id: 'culture',
    label: 'Ethics & culture',
    emoji: '🤝',
    blurb: 'Values, ethics and team culture',
  ),
  InterestOption(
    id: 'career_growth',
    label: 'Career growth',
    emoji: '📈',
    blurb: 'Promotions, mentors and next steps',
  ),
  InterestOption(
    id: 'wellbeing',
    label: 'Wellbeing & burnout',
    emoji: '🌿',
    blurb: 'Stress, burnout and work-life balance',
  ),
  InterestOption(
    id: 'remote_work',
    label: 'Remote & hybrid',
    emoji: '🏠',
    blurb: 'Working from home and across time zones',
  ),
  InterestOption(
    id: 'conflict',
    label: 'Conflict & feedback',
    emoji: '🕊️',
    blurb: 'Hard conversations and giving feedback',
  ),
  InterestOption(
    id: 'product_design',
    label: 'Product & design',
    emoji: '🎨',
    blurb: 'Users, UX and what to build',
  ),
  InterestOption(
    id: 'job_search',
    label: 'Jobs & interviews',
    emoji: '🔎',
    blurb: 'Hiring, interviews and switching jobs',
  ),
  InterestOption(
    id: 'learning',
    label: 'Learning & skills',
    emoji: '📚',
    blurb: 'Courses, skills and getting better',
  ),
  InterestOption(
    id: 'startups',
    label: 'Startups',
    emoji: '🚀',
    blurb: 'Founders, funding and early teams',
  ),
  InterestOption(
    id: 'inclusion',
    label: 'Diversity & inclusion',
    emoji: '🌍',
    blurb: 'Fairness and belonging for everyone',
  ),
];

/// Short keyword lists for the demo's topic tagging. The server has the
/// full stemmed lexicon (`backend/src/nlp/topics.ts`).
const kDemoInterestKeywords = <String, List<String>>{
  'workplace_policy': [
    'policy',
    'leave',
    'hr',
    'rule',
    'office',
    'remote policy',
  ],
  'engineering': [
    'engineer',
    'code',
    'dashboard',
    'estimate',
    'nlp',
    'sprint',
    'bug',
    'deploy',
    'tech',
  ],
  'leadership': ['lead', 'manager', 'exec', 'decision', 'strategy', 'boss'],
  'compensation': ['pay', 'salary', 'bonus', 'raise', 'equity', 'compensation'],
  'safety': ['safety', 'safe', 'retro', 'speak up', 'fear', 'blame', 'psych'],
  'culture': ['culture', 'ethic', 'values', 'offsite', 'toxic', 'respect'],
  'career_growth': [
    'career',
    'promotion',
    'promot',
    'mentor',
    'growth',
    'senior',
    'review',
  ],
  'wellbeing': [
    'burnout',
    'stress',
    'tired',
    'balance',
    'weekend',
    'wellbeing',
    'overwork',
  ],
  'remote_work': ['remote', 'hybrid', 'home', 'time zone', 'async', 'meeting'],
  'conflict': [
    'conflict',
    'feedback',
    'disagree',
    'tension',
    'complaint',
    'tone',
  ],
  'product_design': [
    'product',
    'design',
    'ux',
    'user',
    'label',
    'feature',
    'filter',
  ],
  'job_search': ['job', 'interview', 'hiring', 'resume', 'quit', 'offer'],
  'learning': [
    'learn',
    'skill',
    'course',
    'glossary',
    'notes',
    'study',
    'example',
  ],
  'startups': ['startup', 'founder', 'funding', 'investor', 'mvp'],
  'inclusion': [
    'diversity',
    'inclusion',
    'bias',
    'gender',
    'fair',
    'belonging',
  ],
};

/// Topic ids found in a text, best first (demo only).
List<String> demoInterestsOf(String text) {
  final lower = text.toLowerCase();
  final scored = <MapEntry<String, int>>[];
  kDemoInterestKeywords.forEach((id, words) {
    final hits = words.where(lower.contains).length;
    if (hits > 0) scored.add(MapEntry(id, hits));
  });
  scored.sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in scored) e.key];
}

InterestOption? interestOption(String id) {
  for (final option in kInterestCatalog) {
    if (option.id == id) return option;
  }
  return null;
}
