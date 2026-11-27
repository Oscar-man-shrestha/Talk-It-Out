/**
 * Deterministic moderation signals for public feed questions and answers
 * (FEED_PROVIDER=lexicon). The same rules as the rewrite worker's
 * pipeline/talkitout_pipeline/moderation.py; keep the two in step.
 *
 * Advisory: a flag marks content (the app shows "Flagged"); it never
 * deletes or hides anything by itself. Criticism of things ("the
 * dashboard is useless") is not abuse.
 */

export type ModerationFlag = 'hate_speech' | 'threat' | 'abusive_language' | 'profanity' | 'self_harm';

const ORDER: ModerationFlag[] = ['hate_speech', 'threat', 'abusive_language', 'profanity', 'self_harm'];

const LEET: Record<string, string> = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', $: 's' };

function normalize(text: string): string {
  // "!" stands for "i" only inside a word ("sh!t"), not at its end ("idiots!!").
  return text
    .toLowerCase()
    .replace(/[013457@$]/g, (c) => LEET[c] ?? c)
    .replace(/(?<=[a-z])!(?=[a-z])/g, 'i');
}

function escape(ch: string): string {
  return ch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** 'idiot' -> i+[\W_]*d+... : tolerant of repeated letters and separators. */
function lexicon(words: string[]): RegExp {
  const alts = [...words]
    .sort((a, b) => b.length - a.length)
    .map((w) => [...w].map((ch) => `${escape(ch)}+`).join('[\\W_]*'))
    .join('|');
  return new RegExp(`(?<![a-z])(?:${alts})(?:s|es|ed|ing|er|ers|y)?(?![a-z])`);
}

const PROFANITY = lexicon([
  'fuck', 'motherfucker', 'shit', 'bullshit', 'bitch', 'bastard', 'asshole', 'arsehole',
  'dickhead', 'piss', 'crap', 'wtf', 'stfu', 'bloody hell', 'bsdk', 'chutiya', 'madarchod',
  'behenchod', 'gandu',
]);

const INSULT = lexicon([
  'idiot', 'moron', 'stupid', 'dumb', 'dumbass', 'imbecile', 'retard', 'loser', 'clown',
  'jerk', 'scum', 'scumbag', 'fool', 'nincompoop', 'pig', 'donkey', 'ullu', 'bewakoof', 'pagal',
]);

const GROUPS =
  '(women|woman|men|girls|girl|boys|muslims|muslim|hindus|hindu|christians|jews|sikhs|buddhists|blacks|whites|asians|' +
  'africans|gays|lesbians|trans people|transgender people|immigrants|foreigners|migrants|biharis|' +
  'south indians|north indians|northeasterners|dalits|brahmins|old people|freshers|disabled people)';

const HATE: RegExp[] = [
  new RegExp(
    `\\b(all|those|these|typical|most|every)\\s+${GROUPS}\\b[^.!?\\n]{0,40}?\\b(are|r|is)\\s+` +
      '(stupid|lazy|useless|dirty|criminals?|animals?|idiots?|thieves|terrorists?|inferior|' +
      'worthless|trash|disgusting|subhuman|vermin|parasites?|filth)\\b',
  ),
  new RegExp(`\\b${GROUPS}\\b[^.!?\\n]{0,20}?\\b(should|must|need to)\\s+(die|be killed|be removed|go back|be banned|disappear)\\b`),
  /\bgo back to (your|their) (own )?(country|village|state)\b/,
  // Denying a group's ability: "women can't do backend work".
  new RegExp(
    `\\b${GROUPS}\\s+(can('|no)?t|cannot|can not|shouldn'?t|should not|don'?t|do not|never|are not able to|aren'?t able to)\\s+` +
      '(do|be|handle|code|lead|work|understand|manage|think|drive|learn|build|program|perform|take|hold|run|write|teach|solve|make|deliver|grasp|cope)\\b',
  ),
  // Softened versions: "women may not be suited for backend work".
  new RegExp(
    `\\b${GROUPS}\\s+(may|might|could|would|do|does|are|is|r)?\\s*(not|never|less|rarely)\\s+` +
      '(be\\s+)?(suited|suitable|fit|cut out|qualified|good at|good enough|able|right)\\b',
  ),
  new RegExp(
    `\\b${GROUPS}\\s+(are|r|is)\\s+(not|never|less)\\s+(capable|smart|intelligent|good enough|fit|competent|logical|technical)\\b`,
  ),
  new RegExp(`\\b${GROUPS}\\s+(are|r)\\s+(animals|vermin|cockroaches|rats|parasites|subhuman)\\b`),
];

const THREAT: RegExp[] = [
  /\b(i('| wi)ll|i am going to|i'm going to|im going to|gonna|i will)\s+(kill|hurt|beat|stab|shoot|smash|break|slap|punch|attack|destroy|end)\s+(you|u|him|her|them|your|his|their|everyone)\b/,
  /\b(kill|shoot|stab|beat up|slap|punch)\s+(you|u|him|her|them|everyone)\b/,
  /\byou\s+(should|deserve to|better|will)\s+(die|be killed|be hurt)\b/,
  /\b(kys|watch your back|you('| a)re dead|i know where you live)\b/,
];

const SELF_HARM =
  /\b(kill myself|end my life|ending my life|suicid\w*|want to die|wanna die|self[- ]harm|hurt myself|no reason to live)\b/;

/** Advisory flags for a piece of text, in a stable order. */
export function moderationFlags(text: string): ModerationFlag[] {
  const t = normalize(text);
  const found = new Set<ModerationFlag>();
  if (HATE.some((r) => r.test(t))) found.add('hate_speech');
  if (THREAT.some((r) => r.test(t))) found.add('threat');
  if (INSULT.test(t)) found.add('abusive_language');
  if (PROFANITY.test(t)) found.add('profanity');
  if (SELF_HARM.test(t)) found.add('self_harm');
  return ORDER.filter((f) => found.has(f));
}
