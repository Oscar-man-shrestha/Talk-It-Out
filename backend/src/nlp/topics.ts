/**
 * The interest taxonomy and a lexicon-based topic classifier (zero-shot:
 * no training data needed). Phrases are stemmed the same way as the text,
 * so "promotions", "promoted" and "promotion" all hit "promotion".
 */
import { stem, terms, tokenize } from './text';

export interface Interest {
  id: string;
  label: string;
  emoji: string;
  /** One line for the interest picker. */
  blurb: string;
  /** Words and short phrases that signal the interest. */
  phrases: string[];
}

// The first six ids are also the post topics a question can carry
// (POST_TOPICS in routes/feed.ts).
export const INTERESTS: Interest[] = [
  {
    id: 'workplace_policy',
    label: 'Workplace policy',
    emoji: '📋',
    blurb: 'Rules, leave, HR and how things are done',
    phrases: ['policy', 'hr', 'human resources', 'leave', 'sick leave', 'parental leave', 'vacation',
      'holiday', 'handbook', 'rule', 'compliance', 'attendance', 'dress code', 'probation',
      'contract', 'notice period', 'overtime', 'expense', 'reimbursement', 'office'],
  },
  {
    id: 'engineering',
    label: 'Engineering & tech',
    emoji: '💻',
    blurb: 'Code, systems, on-call and tech debt',
    phrases: ['engineer', 'engineering', 'code', 'coding', 'deploy', 'bug', 'tech debt', 'technical debt',
      'architecture', 'api', 'backend', 'frontend', 'database', 'on call', 'incident', 'sprint',
      'estimate', 'pull request', 'code review', 'devops', 'testing', 'dashboard', 'nlp', 'machine learning',
      'ai', 'data', 'software', 'developer', 'refactor'],
  },
  {
    id: 'leadership',
    label: 'Leadership',
    emoji: '🧭',
    blurb: 'Managers, execs and decisions',
    phrases: ['leader', 'leadership', 'manager', 'management', 'exec', 'executive', 'ceo', 'cto', 'director',
      'boss', 'decision', 'strategy', 'vision', 'roadmap', 'delegate', 'one on one', '1:1', 'skip level',
      'reorg', 'accountability', 'micromanage', 'credit'],
  },
  {
    id: 'compensation',
    label: 'Pay & equity',
    emoji: '💰',
    blurb: 'Salary, raises, bonuses and equity',
    phrases: ['salary', 'pay', 'paid', 'raise', 'bonus', 'equity', 'stock', 'esop', 'compensation', 'wage',
      'increment', 'appraisal', 'pay gap', 'benefit', 'negotiate', 'negotiation', 'offer', 'ctc', 'payroll'],
  },
  {
    id: 'safety',
    label: 'Psychological safety',
    emoji: '🛡️',
    blurb: 'Speaking up without fear',
    phrases: ['psychological safety', 'safe', 'safety', 'speak up', 'fear', 'retaliation', 'retro',
      'retrospective', 'blame', 'trust', 'honest', 'candid', 'anonymous', 'voice', 'silenced',
      'whistleblow', 'admit mistake', 'mistake'],
  },
  {
    id: 'culture',
    label: 'Ethics & culture',
    emoji: '🤝',
    blurb: 'Values, ethics and team culture',
    phrases: ['culture', 'ethic', 'ethics', 'values', 'integrity', 'toxic', 'politics', 'gossip', 'offsite',
      'team building', 'morale', 'favoritism', 'nepotism', 'transparency', 'respect', 'harassment'],
  },
  {
    id: 'career_growth',
    label: 'Career growth',
    emoji: '📈',
    blurb: 'Promotions, mentors and next steps',
    phrases: ['career', 'promotion', 'promote', 'growth', 'mentor', 'mentorship', 'senior', 'junior',
      'level', 'title', 'ladder', 'performance review', 'goal', 'okr', 'stretch', 'visibility', 'sponsor',
      'switch role', 'next step'],
  },
  {
    id: 'wellbeing',
    label: 'Wellbeing & burnout',
    emoji: '🌿',
    blurb: 'Stress, burnout and work-life balance',
    phrases: ['burnout', 'burned out', 'stress', 'anxiety', 'mental health', 'tired', 'exhausted',
      'overwork', 'work life balance', 'balance', 'wellbeing', 'well being', 'sleep', 'therapy',
      'boundary', 'weekend', 'late night', 'pressure', 'overwhelm'],
  },
  {
    id: 'remote_work',
    label: 'Remote & hybrid',
    emoji: '🏠',
    blurb: 'Working from home and across time zones',
    phrases: ['remote', 'hybrid', 'work from home', 'wfh', 'return to office', 'rto', 'time zone',
      'async', 'asynchronous', 'zoom', 'video call', 'meeting', 'commute', 'distributed', 'slack'],
  },
  {
    id: 'conflict',
    label: 'Conflict & feedback',
    emoji: '🕊️',
    blurb: 'Hard conversations and giving feedback',
    phrases: ['conflict', 'disagree', 'disagreement', 'argument', 'feedback', 'criticism', 'difficult conversation',
      'hard conversation', 'confront', 'tension', 'resolve', 'mediation', 'apology', 'apologize', 'complaint',
      'rude', 'interrupt', 'tone'],
  },
  {
    id: 'product_design',
    label: 'Product & design',
    emoji: '🎨',
    blurb: 'Users, UX and what to build',
    phrases: ['product', 'design', 'designer', 'ux', 'ui', 'user research', 'prototype', 'feature',
      'customer', 'user', 'figma', 'launch', 'roadmap', 'requirement', 'spec', 'usability', 'label'],
  },
  {
    id: 'job_search',
    label: 'Jobs & interviews',
    emoji: '🔎',
    blurb: 'Hiring, interviews and switching jobs',
    phrases: ['job', 'interview', 'hiring', 'hire', 'recruiter', 'resume', 'cv', 'cover letter', 'applying',
      'application', 'quit', 'resign', 'resignation', 'layoff', 'laid off', 'fired', 'job offer', 'internship',
      'onboarding', 'notice'],
  },
  {
    id: 'learning',
    label: 'Learning & skills',
    emoji: '📚',
    blurb: 'Courses, skills and getting better',
    phrases: ['learn', 'learning', 'skill', 'course', 'certification', 'training', 'study', 'book',
      'practice', 'upskill', 'workshop', 'tutorial', 'glossary', 'notes', 'documentation', 'knowledge'],
  },
  {
    id: 'startups',
    label: 'Startups',
    emoji: '🚀',
    blurb: 'Founders, funding and early teams',
    phrases: ['startup', 'founder', 'cofounder', 'co founder', 'funding', 'investor', 'vc', 'seed', 'pitch',
      'runway', 'mvp', 'early stage', 'bootstrap', 'scale', 'side project', 'entrepreneur'],
  },
  {
    id: 'inclusion',
    label: 'Diversity & inclusion',
    emoji: '🌍',
    blurb: 'Fairness and belonging for everyone',
    phrases: ['diversity', 'inclusion', 'inclusive', 'dei', 'bias', 'discrimination', 'gender', 'women',
      'minority', 'belonging', 'accessibility', 'disability', 'equal', 'fair', 'fairness', 'caste', 'religion',
      'neurodivergent'],
  },
];

export const INTEREST_IDS = INTERESTS.map((i) => i.id);
const BY_ID = new Map(INTERESTS.map((i) => [i.id, i]));

export function interestById(id: string): Interest | undefined {
  return BY_ID.get(id);
}

/** Phrase -> stemmed token sequence, per interest. */
const LEXICON: { id: string; seq: string[] }[] = INTERESTS.flatMap((interest) =>
  interest.phrases.map((phrase) => ({
    id: interest.id,
    seq: tokenizeKeepShort(phrase).map(stem),
  })),
).filter((entry) => entry.seq.length > 0);

// Lexicon phrases are written by hand, so keep short words such as "ai",
// "hr", "ui" that the general tokenizer keeps anyway (>= 2 chars), and
// keep "1:1" usable as "1 1".
function tokenizeKeepShort(text: string): string[] {
  const tokens = tokenize(text);
  return tokens.length > 0 ? tokens : text.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
}

function countSequence(haystack: string[], seq: string[]): number {
  let count = 0;
  outer: for (let i = 0; i + seq.length <= haystack.length; i++) {
    for (let j = 0; j < seq.length; j++) {
      if (haystack[i + j] !== seq[j]) continue outer;
    }
    count++;
  }
  return count;
}

export interface TopicScore {
  id: string;
  score: number;
}

/**
 * Multi-label topic scores in [0, 1] (the best topic is 1), strongest
 * first. The title counts double; multi-word phrases count more than single
 * words; repeated hits grow slowly (log). Empty when nothing matched.
 */
export function classify(title: string | null | undefined, content: string, chosenTopic?: string | null): TopicScore[] {
  const titleTerms = terms(title ?? '');
  const bodyTerms = terms(content);
  const raw = new Map<string, number>();
  for (const { id, seq } of LEXICON) {
    const hits = 2 * countSequence(titleTerms, seq) + countSequence(bodyTerms, seq);
    if (hits === 0) continue;
    const weight = seq.length > 1 ? 1.6 : 1;
    raw.set(id, (raw.get(id) ?? 0) + weight * Math.log2(1 + hits));
  }
  if (chosenTopic && BY_ID.has(chosenTopic)) {
    // The author's own choice is strong evidence.
    const best = Math.max(0, ...raw.values());
    raw.set(chosenTopic, Math.max(2, best + 1));
  }
  const max = Math.max(0, ...raw.values());
  if (max === 0) return [];
  return [...raw.entries()]
    .map(([id, score]) => ({ id, score: Math.round((score / max) * 1000) / 1000 }))
    .filter((t) => t.score >= 0.15)
    .sort((a, b) => b.score - a.score || a.id.localeCompare(b.id));
}

/** Stemmed lexicon words of an interest (used to seed a user's profile). */
export function interestTerms(id: string): string[] {
  return LEXICON.filter((e) => e.id === id).flatMap((e) => e.seq);
}
