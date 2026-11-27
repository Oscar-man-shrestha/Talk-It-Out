/// A gentle, on-device tone check for chat drafts. Nothing leaves the
/// phone: the draft is checked as it is typed and never stored or logged.
/// It never blocks sending; the AI rewrite and the controller review still
/// apply to every message.
library;

class ToneHint {
  const ToneHint(this.kind, this.message);

  /// insult, blame, absolute or shouting.
  final String kind;
  final String message;
}

// Words that attack a person rather than describe a problem.
const _insults = {
  'stupid',
  'idiot',
  'idiots',
  'idiotic',
  'useless',
  'incompetent',
  'pathetic',
  'dumb',
  'moron',
  'morons',
  'clueless',
  'lazy',
  'worthless',
  'garbage',
  'trash',
  'ridiculous',
  'disgusting',
  'shameful',
  'liar',
  'liars',
  'fool',
  'fools',
  'crap',
  'damn',
  'wtf',
  'nonsense',
};

final _blame = RegExp(
  r"\b(your fault|because of you|you people|"
  r"blame (you|him|her|them)|you (?:made|ruined|messed|broke|screwed)|"
  r"(?:he|she|they) (?:ruined|messed|screwed))\b",
);

final _absolute = RegExp(
  r"\b(you|he|she|they|management|leadership|this team)\s+(?:\w+\s+)?"
  r"(always|never)\b",
);

/// The most important hint for a draft, or null when it reads fine.
ToneHint? checkTone(String draft) {
  final text = draft.trim();
  if (text.length < 6) return null;
  final lower = text.toLowerCase();
  final words = lower.split(RegExp(r"[^a-z']+")).where((w) => w.isNotEmpty);

  if (words.any(_insults.contains) ||
      RegExp(r'f+u+c+k|sh[i!1]t').hasMatch(lower)) {
    return const ToneHint(
      'insult',
      'Some words may read as an attack. Describe the problem, not the person.',
    );
  }
  if (_blame.hasMatch(lower)) {
    return const ToneHint(
      'blame',
      'This may read as blame. Try "I" statements: what happened and how it affected you.',
    );
  }
  if (_absolute.hasMatch(lower)) {
    return const ToneHint(
      'absolute',
      '"Always" and "never" can feel unfair. A specific example lands better.',
    );
  }
  final letters = text.replaceAll(RegExp('[^A-Za-z]'), '');
  final upper = letters.replaceAll(RegExp('[^A-Z]'), '');
  if ((letters.length >= 12 && upper.length / letters.length > 0.7) ||
      RegExp('[!?]{3,}').hasMatch(text)) {
    return const ToneHint(
      'shouting',
      'Capitals and !!! can feel like shouting. A calm version is easier to hear.',
    );
  }
  return null;
}
