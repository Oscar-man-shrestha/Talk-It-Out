/**
 * Approximate string matching for people search and typo-tolerant feed
 * search: edit distance, Jaro-Winkler and a phonetic key.
 */
import { fold, nameKey } from './text';

/**
 * Damerau-Levenshtein distance (optimal string alignment): insertions,
 * deletions, substitutions and swapped neighbours each cost 1.
 */
export function editDistance(a: string, b: string): number {
  if (a === b) return 0;
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;
  const rows = a.length + 1;
  const cols = b.length + 1;
  const d: number[][] = Array.from({ length: rows }, () => new Array<number>(cols).fill(0));
  for (let i = 0; i < rows; i++) d[i][0] = i;
  for (let j = 0; j < cols; j++) d[0][j] = j;
  for (let i = 1; i < rows; i++) {
    for (let j = 1; j < cols; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
      }
    }
  }
  return d[a.length][b.length];
}

/** Jaro-Winkler similarity in [0, 1]; rewards a shared beginning. */
export function jaroWinkler(a: string, b: string): number {
  if (a === b) return a.length === 0 ? 0 : 1;
  if (a.length === 0 || b.length === 0) return 0;
  const window = Math.max(0, Math.floor(Math.max(a.length, b.length) / 2) - 1);
  const aMatched = new Array<boolean>(a.length).fill(false);
  const bMatched = new Array<boolean>(b.length).fill(false);
  let matches = 0;
  for (let i = 0; i < a.length; i++) {
    const from = Math.max(0, i - window);
    const to = Math.min(b.length - 1, i + window);
    for (let j = from; j <= to; j++) {
      if (bMatched[j] || a[i] !== b[j]) continue;
      aMatched[i] = true;
      bMatched[j] = true;
      matches++;
      break;
    }
  }
  if (matches === 0) return 0;
  let transpositions = 0;
  let k = 0;
  for (let i = 0; i < a.length; i++) {
    if (!aMatched[i]) continue;
    while (!bMatched[k]) k++;
    if (a[i] !== b[k]) transpositions++;
    k++;
  }
  const m = matches;
  const jaro = (m / a.length + m / b.length + (m - transpositions / 2) / m) / 3;
  let prefix = 0;
  while (prefix < 4 && prefix < a.length && prefix < b.length && a[prefix] === b[prefix]) {
    prefix++;
  }
  return jaro + prefix * 0.1 * (1 - jaro);
}

/**
 * A sound-alike key tuned for English and romanised South Asian names:
 * "Rohan"/"Rohn", "Katherine"/"Catherine", "Shrestha"/"Shresta",
 * "Vikram"/"Wikram" share a key. Keeps the first letter, drops later vowels.
 */
export function phoneticKey(text: string): string {
  let s = fold(text).replace(/[^a-z]/g, '');
  if (s.length === 0) return '';
  s = s
    .replace(/ph/g, 'f')
    .replace(/ck/g, 'k')
    .replace(/q/g, 'k')
    .replace(/x/g, 'ks')
    .replace(/c(?=[eiy])/g, 's')
    .replace(/c/g, 'k')
    .replace(/([kgtdbcsj])h/g, '$1')
    .replace(/z/g, 's')
    .replace(/w/g, 'v')
    .replace(/y/g, 'i');
  const first = s[0];
  const rest = s.slice(1).replace(/[aeiou]/g, '');
  return (first + rest).replace(/(.)\1+/g, '$1');
}

/**
 * Smallest edit distance between the query and any beginning of the target
 * of about the same length: "rhoan" vs "rohan shrestha" -> 1. Lets people
 * search while they are still typing, with a typo.
 */
export function prefixDistance(query: string, target: string): number {
  let best = Number.POSITIVE_INFINITY;
  for (let len = query.length - 1; len <= query.length + 1; len++) {
    if (len < 1 || len > target.length) continue;
    best = Math.min(best, editDistance(query, target.slice(0, len)));
  }
  return best;
}

/** Typos allowed for a query of this length. */
export function allowedTypos(length: number): number {
  if (length < 3) return 0;
  if (length < 6) return 1;
  return 2;
}

export type NameMatchKind = 'exact' | 'prefix' | 'similar' | 'sounds_like';

export interface NameCandidate {
  name: string;
  username: string;
  /** Only a chosen @handle is searchable beyond an exact match. */
  usernameChosen: boolean;
}

export interface NameMatch {
  score: number;
  kind: NameMatchKind;
}

/**
 * How well a search query matches a person, in [0, 1], or null when it
 * does not match. Order: exact handle > exact name > prefix > typo-tolerant
 * prefix > sounds alike > generally similar.
 */
export function matchPerson(rawQuery: string, person: NameCandidate): NameMatch | null {
  const query = fold(rawQuery).trim().replace(/^@/, '').replace(/\s+/g, ' ');
  if (query.length === 0) return null;
  const handle = person.username.toLowerCase();
  const fullName = fold(person.name).trim().replace(/\s+/g, ' ');
  const words = fullName.split(' ').filter(Boolean);

  if (query === handle) return { score: 1, kind: 'exact' };
  if (query === fullName) return { score: 0.97, kind: 'exact' };

  if (person.usernameChosen && handle.startsWith(query)) {
    return { score: 0.9 + 0.05 * (query.length / handle.length), kind: 'prefix' };
  }
  if (fullName.startsWith(query) || words.some((w) => w.startsWith(query))) {
    const target = fullName.startsWith(query) ? fullName : words.find((w) => w.startsWith(query))!;
    return { score: 0.86 + 0.06 * (query.length / target.length), kind: 'prefix' };
  }
  if (query.length < 3) return null;

  const qKey = nameKey(query);
  const targets = [...words, fullName.replace(/ /g, '')];
  if (person.usernameChosen) targets.push(nameKey(handle));
  const keys = targets.map(nameKey).filter((k) => k.length > 0);
  if (qKey.length === 0 || keys.length === 0) return null;

  let best: NameMatch | null = null;
  const consider = (m: NameMatch) => {
    if (!best || m.score > best.score) best = m;
  };

  const typos = allowedTypos(qKey.length);
  for (const key of keys) {
    const dist = prefixDistance(qKey, key);
    if (dist <= typos) {
      consider({ score: 0.8 - 0.08 * dist, kind: 'similar' });
    }
  }

  const qSound = phoneticKey(query.replace(/ /g, ''));
  if (qSound.length >= 2) {
    for (const target of targets) {
      const sound = phoneticKey(target);
      if (sound === qSound || (qSound.length >= 3 && sound.startsWith(qSound))) {
        consider({ score: 0.72, kind: 'sounds_like' });
      }
    }
  }

  for (const key of keys) {
    const jw = jaroWinkler(qKey, key);
    if (jw >= 0.86) consider({ score: 0.55 + (jw - 0.86) * 1.2, kind: 'similar' });
  }
  return best;
}
