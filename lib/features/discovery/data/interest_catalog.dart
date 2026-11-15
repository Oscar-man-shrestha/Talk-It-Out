import 'package:talk_it_out/features/discovery/data/discovery_models.dart';

/// The 30 feed interests, as the API lists them (`API.md` 54). Generated
/// from `backend/src/nlp/topics.ts`; `test/interest_icons_test.dart` checks
/// the two stay the same. The demo data uses this list; live builds read
/// it from the server.
const kInterestCatalog = <InterestOption>[
  InterestOption(
    id: 'workplace_policy',
    label: 'Workplace policy',
    icon: 'policy',
    blurb: 'Rules, leave, HR and how things are done',
  ),
  InterestOption(
    id: 'engineering',
    label: 'Engineering & tech',
    icon: 'code',
    blurb: 'Code, systems, on-call and tech debt',
  ),
  InterestOption(
    id: 'leadership',
    label: 'Leadership',
    icon: 'explore',
    blurb: 'Managers, execs and decisions',
  ),
  InterestOption(
    id: 'compensation',
    label: 'Pay & equity',
    icon: 'payments',
    blurb: 'Salary, raises, bonuses and equity',
  ),
  InterestOption(
    id: 'safety',
    label: 'Psychological safety',
    icon: 'shield',
    blurb: 'Speaking up without fear',
  ),
  InterestOption(
    id: 'culture',
    label: 'Ethics & culture',
    icon: 'handshake',
    blurb: 'Values, ethics and team culture',
  ),
  InterestOption(
    id: 'career_growth',
    label: 'Career growth',
    icon: 'trending_up',
    blurb: 'Promotions, mentors and next steps',
  ),
  InterestOption(
    id: 'wellbeing',
    label: 'Wellbeing & burnout',
    icon: 'spa',
    blurb: 'Stress, burnout and work-life balance',
  ),
  InterestOption(
    id: 'remote_work',
    label: 'Remote & hybrid',
    icon: 'home_work',
    blurb: 'Working from home and across time zones',
  ),
  InterestOption(
    id: 'conflict',
    label: 'Conflict & feedback',
    icon: 'balance',
    blurb: 'Hard conversations and giving feedback',
  ),
  InterestOption(
    id: 'product_design',
    label: 'Product & design',
    icon: 'design',
    blurb: 'Users, UX and what to build',
  ),
  InterestOption(
    id: 'job_search',
    label: 'Jobs & interviews',
    icon: 'work_search',
    blurb: 'Hiring, interviews and switching jobs',
  ),
  InterestOption(
    id: 'learning',
    label: 'Learning & skills',
    icon: 'school',
    blurb: 'Courses, skills and getting better',
  ),
  InterestOption(
    id: 'startups',
    label: 'Startups',
    icon: 'rocket',
    blurb: 'Founders, funding and early teams',
  ),
  InterestOption(
    id: 'inclusion',
    label: 'Diversity & inclusion',
    icon: 'diversity',
    blurb: 'Fairness and belonging for everyone',
  ),
  InterestOption(
    id: 'data_ai',
    label: 'Data & AI',
    icon: 'insights',
    blurb: 'Analytics, machine learning and AI at work',
  ),
  InterestOption(
    id: 'sales_marketing',
    label: 'Sales & marketing',
    icon: 'campaign',
    blurb: 'Targets, customers, campaigns and growth',
  ),
  InterestOption(
    id: 'people_management',
    label: 'Managing people',
    icon: 'groups',
    blurb: 'First-time managers, 1:1s and feedback',
  ),
  InterestOption(
    id: 'communication',
    label: 'Communication',
    icon: 'record_voice_over',
    blurb: 'Speaking up, writing and presenting',
  ),
  InterestOption(
    id: 'productivity',
    label: 'Productivity & focus',
    icon: 'timer',
    blurb: 'Time, priorities, meetings and deep work',
  ),
  InterestOption(
    id: 'hiring',
    label: 'Hiring & interviewing',
    icon: 'person_search',
    blurb: 'Running interviews and building teams',
  ),
  InterestOption(
    id: 'benefits',
    label: 'Benefits & perks',
    icon: 'redeem',
    blurb: 'Insurance, leave, pensions and perks',
  ),
  InterestOption(
    id: 'rights_at_work',
    label: 'Rights at work',
    icon: 'gavel',
    blurb: 'Contracts, notice periods, layoffs and law',
  ),
  InterestOption(
    id: 'freelancing',
    label: 'Freelance & side projects',
    icon: 'work_outline',
    blurb: 'Freelancing, consulting and side income',
  ),
  InterestOption(
    id: 'students',
    label: 'Students & first jobs',
    icon: 'backpack',
    blurb: 'Internships, graduates and getting started',
  ),
  InterestOption(
    id: 'caregivers',
    label: 'Parents & caregivers',
    icon: 'family_restroom',
    blurb: 'Parental leave, childcare and caring at home',
  ),
  InterestOption(
    id: 'relocation',
    label: 'Relocation & visas',
    icon: 'flight_takeoff',
    blurb: 'Moving cities or countries for work',
  ),
  InterestOption(
    id: 'mental_health',
    label: 'Mental health',
    icon: 'psychology',
    blurb: 'Anxiety, stress and getting support',
  ),
  InterestOption(
    id: 'customer_support',
    label: 'Customer support',
    icon: 'support_agent',
    blurb: 'Tickets, difficult customers and service teams',
  ),
  InterestOption(
    id: 'money',
    label: 'Money & taxes',
    icon: 'savings',
    blurb: 'Savings, taxes and planning your finances',
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
  'data_ai': ['data', 'analytics', 'machine learning', 'ai', 'model', 'sql'],
  'sales_marketing': [
    'sales',
    'quota',
    'marketing',
    'campaign',
    'lead',
    'client',
  ],
  'people_management': [
    'new manager',
    'my team',
    'direct report',
    'one on one',
    'delegate',
    'team lead',
  ],
  'communication': [
    'communicat',
    'speak up',
    'present',
    'say no',
    'push back',
    'email',
  ],
  'productivity': [
    'productiv',
    'focus',
    'deep work',
    'priorit',
    'deadline',
    'meetings',
  ],
  'hiring': [
    'hiring',
    'hire',
    'recruit',
    'candidate',
    'interviewer',
    'onboarding',
  ],
  'benefits': [
    'benefit',
    'perk',
    'insurance',
    'pension',
    'stock option',
    'esop',
  ],
  'rights_at_work': [
    'contract',
    'notice period',
    'non compete',
    'layoff',
    'severance',
    'rights',
  ],
  'freelancing': [
    'freelanc',
    'consult',
    'side project',
    'side hustle',
    'invoice',
  ],
  'students': [
    'student',
    'intern',
    'graduate',
    'fresher',
    'first job',
    'university',
  ],
  'caregivers': [
    'parent',
    'maternity',
    'paternity',
    'childcare',
    'caregiver',
    'family',
  ],
  'relocation': [
    'relocat',
    'visa',
    'abroad',
    'immigration',
    'transfer',
    'new city',
  ],
  'mental_health': [
    'mental health',
    'anxiety',
    'anxious',
    'therapy',
    'imposter',
    'overwhelmed',
  ],
  'customer_support': [
    'customer support',
    'customer service',
    'ticket',
    'angry customer',
    'escalat',
  ],
  'money': ['tax', 'savings', 'invest', 'budget', 'loan', 'retirement'],
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
