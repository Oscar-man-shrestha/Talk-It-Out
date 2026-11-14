/// Typo-tolerant name matching for the demo data. The live app uses the
/// server's version (`backend/src/nlp/fuzzy.ts`); this is a smaller port.
library;

String _letters(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[^a-z]'), '')
    .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);

/// Edit distance with swapped neighbours counted as one edit.
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final d = List.generate(
    a.length + 1,
    (_) => List<int>.filled(b.length + 1, 0),
  );
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = [
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        v = v < d[i - 2][j - 2] + 1 ? v : d[i - 2][j - 2] + 1;
      }
      d[i][j] = v;
    }
  }
  return d[a.length][b.length];
}

/// Sound-alike key: "Rohan"/"Rohn", "Katherine"/"Catherine".
String soundKey(String s) {
  var w = s.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  if (w.isEmpty) return '';
  w = w
      .replaceAll('ph', 'f')
      .replaceAll('ck', 'k')
      .replaceAll('q', 'k')
      .replaceAll('x', 'ks')
      .replaceAllMapped(RegExp('c(?=[eiy])'), (_) => 's')
      .replaceAll('c', 'k')
      .replaceAllMapped(RegExp('([kgtdbsj])h'), (m) => m[1]!)
      .replaceAll('z', 's')
      .replaceAll('w', 'v')
      .replaceAll('y', 'i');
  final rest = w.substring(1).replaceAll(RegExp('[aeiou]'), '');
  return (w[0] + rest).replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);
}

/// A match score in (0, 1] and its kind, or null.
({double score, String kind})? matchName(
  String rawQuery,
  String name, {
  String? handle,
}) {
  final q = rawQuery.trim().toLowerCase().replaceFirst(RegExp('^@+'), '');
  if (q.isEmpty) return null;
  final full = name.trim().toLowerCase();
  final words = full.split(RegExp(r'\s+'));
  final h = handle?.toLowerCase();
  if (h != null && q == h) return (score: 1.0, kind: 'exact');
  if (q == full) return (score: 0.97, kind: 'exact');
  if (h != null && h.startsWith(q)) return (score: 0.92, kind: 'prefix');
  if (full.startsWith(q) || words.any((w) => w.startsWith(q))) {
    return (score: 0.88, kind: 'prefix');
  }
  if (q.length < 3) return null;
  final qk = _letters(q);
  final allowed = qk.length < 3 ? 0 : (qk.length < 6 ? 1 : 2);
  final targets = [...words, full.replaceAll(' ', ''), ?h];
  ({double score, String kind})? best;
  for (final t in targets) {
    final key = _letters(t);
    for (var len = qk.length - 1; len <= qk.length + 1; len++) {
      if (len < 1 || len > key.length) continue;
      final dist = editDistance(qk, key.substring(0, len));
      if (dist <= allowed) {
        final score = 0.8 - 0.08 * dist;
        if (best == null || score > best.score) {
          best = (score: score, kind: 'similar');
        }
      }
    }
    final qs = soundKey(q);
    final ts = soundKey(t);
    if (qs.length >= 2 && (ts == qs || (qs.length >= 3 && ts.startsWith(qs)))) {
      if (best == null || 0.72 > best.score) {
        best = (score: 0.72, kind: 'sounds_like');
      }
    }
  }
  return best;
}
