/// The demo's stand-in for the AI rewrite. The real app sends messages to a
/// language model; the public demo has no server, so this rule-based
/// rewriter shows what a rewrite does: it removes insults and shouting,
/// turns blame into "I" statements and demands into requests, and keeps
/// facts, names, numbers and questions. It runs in the browser only.
library;

const _replacements = <String, String>{
  // Insults and harsh words -> the problem they point at.
  'pathetic': 'disappointing',
  'ridiculous': 'frustrating',
  'stupid': 'unclear',
  'dumb': 'unclear',
  'idiotic': 'unclear',
  'useless': 'not helpful',
  'garbage': 'not working well',
  'trash': 'not working well',
  'crap': 'not good enough',
  'sucks': 'is not working well',
  'awful': 'difficult',
  'terrible': 'difficult',
  'horrible': 'difficult',
  'worst': 'most difficult',
  'a joke': 'not working',
  'nonsense': 'confusing',
  'incompetent': 'struggling',
  'clueless': 'unsure',
  'lazy': 'not engaged',
  'hate': 'really dislike',
  'disgusting': 'unacceptable',
  'shameful': 'disappointing',
};

final _drop = RegExp(
  r"\b(?:wtf|omg|ffs|damn|bloody|freaking|fucking|fuckin|shit|honestly)\b[,!]?\s*",
  caseSensitive: false,
);

final _blame = <RegExp, String>{
  RegExp(r"\b(?:it'?s|its) (?:all )?your fault\b", caseSensitive: false):
      'I think we need to look at what went wrong',
  RegExp(r'\bbecause of you\b', caseSensitive: false): 'after what happened',
  RegExp(r'\byou people\b', caseSensitive: false): 'the team',
  RegExp(r'\bmakes us look (?:stupid|bad|dumb)\b', caseSensitive: false):
      'makes us look unprepared',
  RegExp(r'\bwho even approved this\b', caseSensitive: false):
      'I would like to understand how this was approved',
};

/// A calm version of [text] that keeps its meaning.
String demoRewrite(String text) {
  var t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return t;

  // Shouting: ALL CAPS words (3+ letters) become lowercase; "!!!" -> "!".
  t = t.replaceAllMapped(
    RegExp(r"\b[A-Z]{3,}\b"),
    (m) => _keepAcronym(m[0]!) ? m[0]! : m[0]!.toLowerCase(),
  );
  t = t.replaceAll(RegExp(r'!{2,}'), '!').replaceAll(RegExp(r'\?{2,}'), '?');
  t = t.replaceAll(RegExp(r'[!?]*\?[!?]*'), '?');

  for (final e in _blame.entries) {
    t = t.replaceAll(e.key, e.value);
  }
  t = t.replaceAll(_drop, '');
  for (final e in _replacements.entries) {
    t = t.replaceAllMapped(
      RegExp('\\b${RegExp.escape(e.key)}\\b', caseSensitive: false),
      (_) => e.value,
    );
  }

  // Demands -> requests.
  t = t.replaceAllMapped(
    RegExp(
      r'^(fix|change|stop|send|update|finish|explain) ',
      caseSensitive: false,
    ),
    (m) => 'Please ${m[1]!.toLowerCase()} ',
  );
  t = t.replaceAllMapped(
    RegExp(r'\byou need to\b', caseSensitive: false),
    (_) => 'could you please',
  );

  // Tidy: one space, a capital first letter, closing punctuation.
  t = t
      .replaceAllMapped(RegExp(r'\s+([,.!?])'), (m) => m[1]!)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  t = t.replaceAll(RegExp(r'^[,.\s]+'), '');
  if (t.isEmpty) return text.trim();
  t = t[0].toUpperCase() + t.substring(1);
  t = t.replaceAllMapped(
    RegExp(r'([.!?] )([a-z])'),
    (m) => '${m[1]}${m[2]!.toUpperCase()}',
  );
  if (!RegExp(r'[.!?]$').hasMatch(t)) t = '$t.';
  return t;
}

bool _keepAcronym(String word) => const {
  'CSV',
  'API',
  'PR',
  'QA',
  'HR',
  'CEO',
  'CTO',
  'UI',
  'UX',
  'SQL',
  'PDF',
}.contains(word);
