/**
 * Feed ranking and feed search. Pure functions over posts already loaded
 * from the database, so they are easy to test and explain.
 */
import { allowedTypos, editDistance } from './fuzzy';
import { classify, interestById, interestTerms, TopicScore } from './topics';
import { fold, stem, terms, tokenize } from './text';

// ---------------------------------------------------------------- TF-IDF

type Vec = Map<string, number>;

function termCounts(words: string[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const w of words) counts.set(w, (counts.get(w) ?? 0) + 1);
  return counts;
}

/** Inverse document frequency over a set of documents (term lists). */
export function idfOf(docs: string[][]): Map<string, number> {
  const df = new Map<string, number>();
  for (const doc of docs) {
    for (const t of new Set(doc)) df.set(t, (df.get(t) ?? 0) + 1);
  }
  const n = docs.length;
  const idf = new Map<string, number>();
  for (const [t, f] of df) idf.set(t, Math.log(1 + (n + 1) / (f + 0.5)));
  return idf;
}

/** Sublinear TF-IDF vector, L2-normalised. */
export function tfidf(words: string[], idf: Map<string, number>): Vec {
  const vec: Vec = new Map();
  for (const [t, c] of termCounts(words)) {
    vec.set(t, (1 + Math.log(c)) * (idf.get(t) ?? Math.log(2)));
  }
  return normalize(vec);
}

function normalize(vec: Vec): Vec {
  let sum = 0;
  for (const v of vec.values()) sum += v * v;
  const len = Math.sqrt(sum);
  if (len === 0) return vec;
  for (const [k, v] of vec) vec.set(k, v / len);
  return vec;
}

export function cosine(a: Vec, b: Vec): number {
  const [small, large] = a.size <= b.size ? [a, b] : [b, a];
  let dot = 0;
  for (const [k, v] of small) {
    const w = large.get(k);
    if (w !== undefined) dot += v * w;
  }
  return dot;
}

function addInto(target: Vec, vec: Vec, weight: number): void {
  for (const [k, v] of vec) target.set(k, (target.get(k) ?? 0) + v * weight);
}

// ---------------------------------------------------------------- For You

export interface RankPost {
  id: string;
  title: string | null;
  content: string;
  topic: string | null;
  authorId: string;
  createdAt: Date;
  likes: number;
  comments: number;
  /** The author shares at least one group with the viewer. */
  inMyGroups: boolean;
  /** The viewer already liked or answered it. */
  engagedByMe: boolean;
}

export interface EngagedPost {
  title: string | null;
  content: string;
  topic: string | null;
  /** Positive for likes, answers, saves and opens. */
  weight: number;
  at: Date;
}

export interface ViewerProfile {
  userId: string;
  picked: string[];
  engaged: EngagedPost[];
  hidden: Set<string>;
  /** Interests the viewer said "Not interested" to (with strength). */
  disliked: Map<string, number>;
  now: Date;
}

export type ReasonKind =
  | 'interest'
  | 'learned'
  | 'similar'
  | 'network'
  | 'popular'
  | 'new'
  | 'explore'
  | 'yours';

export interface Reason {
  kind: ReasonKind;
  text: string;
  interest?: string;
}

export interface RankedPost {
  id: string;
  score: number;
  reason: Reason;
  interests: string[];
}

const DAY_MS = 24 * 3600 * 1000;
// Signals fade with a 30-day time constant.
const SIGNAL_DECAY_DAYS = 30;

/** Interest weights the viewer has shown through their actions. */
export function learnedInterests(engaged: EngagedPost[], now: Date): Map<string, number> {
  const learned = new Map<string, number>();
  for (const e of engaged) {
    const ageDays = Math.max(0, (now.getTime() - e.at.getTime()) / DAY_MS);
    const decay = Math.exp(-ageDays / SIGNAL_DECAY_DAYS);
    for (const t of classify(e.title, e.content, e.topic)) {
      learned.set(t.id, (learned.get(t.id) ?? 0) + e.weight * decay * t.score);
    }
  }
  return learned;
}

function labelOf(id: string): string {
  return interestById(id)?.label ?? id;
}

/**
 * Ranks posts for one viewer. Steps, as in large feeds:
 *  1. score each candidate (interest, content similarity, engagement with
 *     time decay, freshness, people from your groups);
 *  2. drop hidden posts;
 *  3. re-rank for diversity (no topic or author three times in a row);
 *  4. slot in one "something new" post in every five for exploration.
 * Every post carries the main reason it was chosen.
 */
export function rankForYou(candidates: RankPost[], viewer: ViewerProfile): RankedPost[] {
  const now = viewer.now.getTime();
  const posts = candidates.filter((p) => !viewer.hidden.has(p.id));
  if (posts.length === 0) return [];

  const topicsOf = new Map<string, TopicScore[]>();
  const docTerms = new Map<string, string[]>();
  for (const p of posts) {
    topicsOf.set(p.id, classify(p.title, p.content, p.topic));
    docTerms.set(p.id, [...terms(p.title ?? ''), ...terms(p.title ?? ''), ...terms(p.content)]);
  }
  const engagedTerms = viewer.engaged.map((e) => [...terms(e.title ?? ''), ...terms(e.content)]);
  const idf = idfOf([...docTerms.values(), ...engagedTerms]);

  // Interest weights: picked = 1 each, plus what the viewer's actions show,
  // minus "Not interested".
  const learned = learnedInterests(viewer.engaged, viewer.now);
  const weights = new Map<string, number>();
  for (const id of viewer.picked) weights.set(id, 1);
  for (const [id, w] of learned) weights.set(id, (weights.get(id) ?? 0) + Math.min(w, 2) * 0.5);
  for (const [id, w] of viewer.disliked) weights.set(id, (weights.get(id) ?? 0) - w);
  // Relative taste: the strongest interest counts fully, even when it was
  // only learned from actions.
  const maxWeight = Math.max(0.25, ...weights.values());

  // The viewer's taste as one TF-IDF vector.
  const taste: Vec = new Map();
  viewer.engaged.forEach((e, i) => {
    const ageDays = Math.max(0, (now - e.at.getTime()) / DAY_MS);
    addInto(taste, tfidf(engagedTerms[i], idf), e.weight * Math.exp(-ageDays / SIGNAL_DECAY_DAYS));
  });
  for (const id of viewer.picked) addInto(taste, tfidf(interestTerms(id), idf), 0.5);
  normalize(taste);
  const hasTaste = taste.size > 0;

  // Engagement with time decay (Hacker News style), normalised later.
  const hot = new Map<string, number>();
  for (const p of posts) {
    const ageHours = Math.max(0, (now - p.createdAt.getTime()) / 3600000);
    hot.set(p.id, Math.log1p(p.likes + 2 * p.comments) / Math.pow(ageHours + 2, 0.8));
  }
  const maxHot = Math.max(1e-9, ...hot.values());

  interface Scored {
    post: RankPost;
    score: number;
    parts: Record<'interest' | 'similar' | 'popular' | 'fresh' | 'network', number>;
    topInterest: string | null;
    topSource: 'picked' | 'learned' | null;
    interests: string[];
  }

  const scored: Scored[] = posts.map((p) => {
    const topics = topicsOf.get(p.id)!;
    let interest = 0;
    let topInterest: string | null = null;
    let topContribution = 0;
    for (const t of topics) {
      const w = weights.get(t.id) ?? 0;
      const c = (w / maxWeight) * t.score;
      interest += c;
      if (c > topContribution) {
        topContribution = c;
        topInterest = t.id;
      }
    }
    interest = Math.max(-1, Math.min(1, interest));
    const similar = hasTaste ? cosine(tfidf(docTerms.get(p.id)!, idf), taste) : 0;
    const popular = hot.get(p.id)! / maxHot;
    const ageDays = (now - p.createdAt.getTime()) / DAY_MS;
    const fresh = Math.exp(-Math.max(0, ageDays) / 3);
    const network = p.inMyGroups ? 1 : 0;
    let score = 0.4 * interest + 0.2 * similar + 0.2 * popular + 0.12 * fresh + 0.08 * network;
    // Your own question: on top for its first hour (so you see it went out,
    // as on Instagram), then rarely.
    const mineFresh = p.authorId === viewer.userId && now - p.createdAt.getTime() < 3600000;
    if (mineFresh) score += 1;
    else if (p.authorId === viewer.userId) score -= 0.3;
    // Already liked or answered: rarely worth showing again.
    if (p.engagedByMe) score -= 0.5;
    return {
      post: p,
      score,
      parts: { interest, similar, popular, fresh, network },
      topInterest: topContribution > 0 ? topInterest : null,
      topSource: topInterest === null || topContribution <= 0
        ? null
        : viewer.picked.includes(topInterest) ? 'picked' : 'learned',
      interests: topics.slice(0, 3).map((t) => t.id),
    };
  });

  scored.sort((a, b) => b.score - a.score || b.post.createdAt.getTime() - a.post.createdAt.getTime());

  // Exploration pool: good posts outside the viewer's strongest interests.
  const strong = new Set(
    [...weights.entries()].filter(([, w]) => w >= 0.5).map(([id]) => id),
  );
  const isExplore = (s: Scored) =>
    strong.size > 0 && s.interests.length > 0 && !s.interests.some((id) => strong.has(id)) && s.parts.interest >= 0;

  const out: RankedPost[] = [];
  const remaining = [...scored];
  const recentTopics: (string | null)[] = [];
  const recentAuthors: string[] = [];

  while (remaining.length > 0) {
    const slot = out.length;
    let pickIndex = -1;
    if (slot % 5 === 4) {
      // Every fifth slot: the best post from outside the bubble, if any.
      pickIndex = remaining.findIndex(isExplore);
    }
    if (pickIndex < 0) {
      // Never a third post in a row on one topic, or two in a row by one
      // author, while something else is left.
      const blockedTopic =
        recentTopics.length === 2 && recentTopics[0] !== null && recentTopics[0] === recentTopics[1]
          ? recentTopics[0]
          : null;
      const lastAuthor = recentAuthors[recentAuthors.length - 1];
      const allowed = (s: Scored) =>
        (blockedTopic === null || s.interests[0] !== blockedTopic) && s.post.authorId !== lastAuthor;
      const anyAllowed = remaining.some(allowed);
      let bestAdjusted = Number.NEGATIVE_INFINITY;
      remaining.forEach((s, i) => {
        if (anyAllowed && !allowed(s)) return;
        let adjusted = s.score;
        if (recentAuthors.includes(s.post.authorId)) adjusted -= 0.1;
        if (adjusted > bestAdjusted) {
          bestAdjusted = adjusted;
          pickIndex = i;
        }
      });
    }
    const [chosen] = remaining.splice(pickIndex, 1);
    const explore = slot % 5 === 4 && isExplore(chosen);
    out.push({
      id: chosen.post.id,
      score: Math.round(chosen.score * 1000) / 1000,
      reason: reasonFor(chosen, explore),
      interests: chosen.interests,
    });
    recentTopics.push(chosen.interests[0] ?? null);
    if (recentTopics.length > 2) recentTopics.shift();
    recentAuthors.push(chosen.post.authorId);
    if (recentAuthors.length > 2) recentAuthors.shift();
  }
  return out;

  function reasonFor(s: Scored, explore: boolean): Reason {
    const primary = s.interests[0];
    if (s.post.authorId === viewer.userId && now - s.post.createdAt.getTime() < 3600000) {
      return { kind: 'yours', text: 'Your new question' };
    }
    if (explore && primary) {
      return { kind: 'explore', text: `Something new: ${labelOf(primary)}`, interest: primary };
    }
    const p = s.parts;
    if (s.topInterest && p.interest >= 0.25) {
      return s.topSource === 'picked'
        ? { kind: 'interest', text: `Because you follow ${labelOf(s.topInterest)}`, interest: s.topInterest }
        : { kind: 'learned', text: `Because you engage with ${labelOf(s.topInterest)}`, interest: s.topInterest };
    }
    if (p.similar >= 0.2) return { kind: 'similar', text: 'Similar to posts you liked' };
    if (p.network > 0) return { kind: 'network', text: 'From someone in your groups' };
    if (p.popular >= 0.5) return { kind: 'popular', text: 'Popular right now' };
    return { kind: 'new', text: 'New in the community' };
  }
}

// ---------------------------------------------------------------- Search

export interface SearchDoc {
  id: string;
  title: string | null;
  content: string;
}

export interface SearchResult {
  ids: string[];
  /** A corrected query when a word was misspelled. */
  didYouMean: string | null;
}

/**
 * BM25 search over titles (counted twice) and bodies, with stemming,
 * typo tolerance (edit distance) and prefix matching on the last word, so
 * results appear while the person is still typing.
 */
export function searchPosts(docs: SearchDoc[], query: string): SearchResult {
  const words = tokenize(query);
  if (words.length === 0 || docs.length === 0) return { ids: [], didYouMean: null };

  const docTerms = docs.map((d) => [...terms(d.title ?? ''), ...terms(d.title ?? ''), ...terms(d.content)]);
  const df = new Map<string, number>();
  for (const doc of docTerms) for (const t of new Set(doc)) df.set(t, (df.get(t) ?? 0) + 1);

  // Surface words for each stem, so a correction reads like a real word.
  const surface = new Map<string, string>();
  for (const d of docs) {
    for (const w of tokenize(`${d.title ?? ''} ${d.content}`)) {
      const s = stem(w);
      if (!surface.has(s)) surface.set(s, w);
    }
  }

  // Expand each query word to matching vocabulary stems with a weight.
  const expansions: Map<string, number>[] = [];
  const corrected: string[] = [];
  let anyCorrection = false;
  words.forEach((word, index) => {
    const s = stem(word);
    const exp = new Map<string, number>();
    if (df.has(s)) exp.set(s, 1);
    const isLast = index === words.length - 1;
    if (isLast && word.length >= 3) {
      for (const v of df.keys()) if (v !== s && v.startsWith(s)) exp.set(v, Math.max(exp.get(v) ?? 0, 0.8));
    }
    if (exp.size === 0 && word.length >= 4) {
      const typos = allowedTypos(word.length);
      let best: { term: string; dist: number } | null = null;
      for (const v of df.keys()) {
        if (Math.abs(v.length - s.length) > typos) continue;
        const dist = editDistance(s, v);
        if (dist <= typos) {
          exp.set(v, Math.max(exp.get(v) ?? 0, 0.7 - 0.1 * (dist - 1)));
          if (!best || dist < best.dist || (dist === best.dist && (df.get(v) ?? 0) > (df.get(best.term) ?? 0))) {
            best = { term: v, dist };
          }
        }
      }
      if (best) {
        anyCorrection = true;
        corrected.push(surface.get(best.term) ?? best.term);
      } else {
        corrected.push(word);
      }
    } else {
      corrected.push(word);
    }
    expansions.push(exp);
  });

  const n = docs.length;
  const avgLen = docTerms.reduce((sum, d) => sum + d.length, 0) / n || 1;
  const k1 = 1.2;
  const b = 0.75;
  const scores: { id: string; score: number; matched: number }[] = [];
  docTerms.forEach((doc, i) => {
    const tf = termCounts(doc);
    let score = 0;
    let matched = 0;
    for (const exp of expansions) {
      let best = 0;
      for (const [t, weight] of exp) {
        const f = tf.get(t);
        if (!f) continue;
        const idf = Math.log(1 + (n - (df.get(t) ?? 0) + 0.5) / ((df.get(t) ?? 0) + 0.5));
        const part = weight * idf * ((f * (k1 + 1)) / (f + k1 * (1 - b + (b * doc.length) / avgLen)));
        best = Math.max(best, part);
      }
      if (best > 0) matched++;
      score += best;
    }
    if (score > 0) scores.push({ id: docs[i].id, score: score * (matched / expansions.length), matched });
  });
  scores.sort((a, b2) => b2.matched - a.matched || b2.score - a.score);
  const didYouMean = anyCorrection && fold(corrected.join(' ')) !== fold(words.join(' '))
    ? corrected.join(' ')
    : null;
  return { ids: scores.map((s) => s.id), didYouMean };
}

// ---------------------------------------------------------------- Similar

export interface SimilarHit {
  id: string;
  /** 0..1: how much of the draft's weight the question covers. */
  score: number;
}

/**
 * Questions like a draft, for "already asked?" while writing (like Stack
 * Overflow and Quora). The draft's most distinctive words (by IDF) are the
 * query; each question's BM25 score is divided by the best possible score,
 * so the threshold means the same for short and long drafts.
 */
export function similarPosts(
  docs: SearchDoc[],
  title: string | null,
  content: string,
  opts: { max?: number; threshold?: number } = {},
): SimilarHit[] {
  const max = opts.max ?? 3;
  const threshold = opts.threshold ?? 0.3;
  const draft = [...terms(title ?? ''), ...terms(title ?? ''), ...terms(content)];
  if (draft.length < 2 || docs.length === 0) return [];

  const docTerms = docs.map((d) => [...terms(d.title ?? ''), ...terms(d.title ?? ''), ...terms(d.content)]);
  const n = docs.length;
  const df = new Map<string, number>();
  for (const doc of docTerms) for (const t of new Set(doc)) df.set(t, (df.get(t) ?? 0) + 1);
  const idf = (t: string) => Math.log(1 + (n - (df.get(t) ?? 0) + 0.5) / ((df.get(t) ?? 0) + 0.5));

  // Up to 12 distinct draft words that occur somewhere, rarest first.
  const query = [...new Set(draft)]
    .filter((t) => df.has(t))
    .sort((a, b) => idf(b) - idf(a))
    .slice(0, 12);
  if (query.length === 0) return [];
  const best = query.reduce((sum, t) => sum + idf(t), 0);

  const avgLen = docTerms.reduce((s, d) => s + d.length, 0) / n || 1;
  const k1 = 1.2;
  const b = 0.75;
  const hits: SimilarHit[] = [];
  docTerms.forEach((doc, i) => {
    const tf = termCounts(doc);
    let score = 0;
    for (const t of query) {
      const f = tf.get(t);
      if (!f) continue;
      // Saturated term weight, capped at the term's idf.
      score += idf(t) * Math.min(1, (f * (k1 + 1)) / (f + k1 * (1 - b + (b * doc.length) / avgLen)) / (k1 + 1) * 1.6);
    }
    const normalized = score / best;
    if (normalized >= threshold) hits.push({ id: docs[i].id, score: Math.round(normalized * 1000) / 1000 });
  });
  return hits.sort((a, b2) => b2.score - a.score).slice(0, max);
}
