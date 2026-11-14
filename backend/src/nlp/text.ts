/**
 * Text normalisation, tokenising and stemming shared by search, topic
 * tagging and feed ranking. Pure functions, no I/O.
 */

/** Lowercase and strip accents: "José Ñúñez" -> "jose nunez". */
export function fold(text: string): string {
  return text
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();
}

/**
 * Key for comparing names and handles: letters only, repeated letters
 * collapsed. "Arhaat_99" -> "arhat", "oscar.man" -> "oscarman".
 */
export function nameKey(text: string): string {
  return fold(text)
    .replace(/[^a-z]/g, '')
    .replace(/(.)\1+/g, '$1');
}

// Common English function words; they carry no topic.
const STOP_WORDS = new Set(
  `a about above after again against all am an and any are as at be because been
  before being below between both but by can could did do does doing down during
  each few for from further had has have having he her here hers herself him himself
  his how i if in into is it its itself just me more most my myself no nor not now of
  off on once only or other our ours ourselves out over own same she should so some
  such than that the their theirs them themselves then there these they this those
  through to too under until up very was we were what when where which while who whom
  why will with would you your yours yourself yourselves also get got really still
  even much many lot lots thing things like one two im ive dont cant wont us let
  anyone someone something anything every everyone way ask asked asking question`
    .split(/\s+/)
    .filter(Boolean),
);

export function isStopWord(word: string): boolean {
  return STOP_WORDS.has(word);
}

/** Lowercased word tokens (letters and digits), stop words removed. */
export function tokenize(text: string): string[] {
  const out: string[] = [];
  for (const raw of fold(text).split(/[^a-z0-9]+/)) {
    if (raw.length < 2 || STOP_WORDS.has(raw)) continue;
    out.push(raw);
  }
  return out;
}

// Longest first; one suffix is removed per word.
const SUFFIXES = [
  'izations', 'ization', 'ational', 'fulness', 'iveness', 'ousness',
  'ations', 'ation', 'ments', 'ment', 'ness', 'ities', 'ity', 'ings', 'ing',
  'ables', 'able', 'ibles', 'ible', 'ates', 'ated', 'ate', 'ions', 'ion',
  'ives', 'ive', 'ers', 'er', 'ed', 'ly', 'ful', 'ism', 'ist', 'als', 'al',
  'ies', 'es', 's',
];

/**
 * A light Porter-style stemmer. It only has to be consistent: the same
 * function runs on posts and on queries, so "promoted", "promotion" and
 * "promoting" all become "promot", and "manager"/"managing" become "manag".
 */
export function stem(word: string): string {
  let w = word;
  if (w.length <= 3 || /^\d+$/.test(w)) return w;
  for (const suffix of SUFFIXES) {
    if (w.endsWith(suffix) && w.length - suffix.length >= 3) {
      if (suffix === 'ies') {
        w = `${w.slice(0, -3)}i`;
      } else if (suffix === 's' && w.endsWith('ss')) {
        // "boss" keeps its s.
      } else {
        w = w.slice(0, -suffix.length);
      }
      break;
    }
  }
  if (w.length > 3 && w.endsWith('e')) w = w.slice(0, -1);
  if (w.length > 3 && w.endsWith('y')) w = `${w.slice(0, -1)}i`;
  // Undouble a final consonant: "runn" -> "run", "boss" -> "bos".
  if (w.length > 3 && /([^aeiou])\1$/.test(w)) w = w.slice(0, -1);
  return w;
}

/** Stemmed content terms of a text. */
export function terms(text: string): string[] {
  return tokenize(text).map(stem);
}
