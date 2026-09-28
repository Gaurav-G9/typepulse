import 'dart:math';

/// How one word of the typed text lines up with the original passage.
enum WordMark { correct, wrong, missed, extra, unfinished }

class WordAlignment {
  final String? expected;
  final String? typed;
  final WordMark mark;
  const WordAlignment(this.expected, this.typed, this.mark);

  bool get isError =>
      mark == WordMark.wrong ||
      mark == WordMark.missed ||
      mark == WordMark.extra;
}

/// Word-by-word comparison of the passage and what was typed (edit-distance
/// alignment), so one skipped word doesn't shift every later word.
///
/// The untyped tail of the passage is ignored (timed tests rarely finish),
/// and a last word cut off mid-typing is [WordMark.unfinished].
class TextCompare {
  static final _ws = RegExp(r'\s+');

  static List<String> words(String s) {
    final t = s.trim();
    return t.isEmpty ? <String>[] : t.split(_ws);
  }

  static List<WordAlignment> align(String expected, String typed) {
    final exp = words(expected);
    final got = words(typed);
    final n = got.length;
    final m = exp.length;
    if (n == 0) return const [];
    final endsMidWord =
        typed.isNotEmpty && !_ws.hasMatch(typed[typed.length - 1]);

    // Costs: gap (missed/extra) = 2, misspelt look-alike = 1, unrelated
    // word = 2 — so "quikc" pairs with "quick" rather than a neighbour.
    int sub(int i, int j) {
      final a = exp[j];
      final b = got[i];
      if (a == b) return 0;
      if (i == n - 1 && endsMidWord && a.startsWith(b)) return 0;
      return _similar(a, b) ? 1 : 2;
    }

    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      d[i][0] = 2 * i;
    }
    for (var j = 1; j <= m; j++) {
      d[0][j] = 2 * j;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        d[i][j] = min(d[i - 1][j - 1] + sub(i - 1, j - 1),
            min(d[i - 1][j] + 2, d[i][j - 1] + 2));
      }
    }

    // Typed text may stop anywhere in the passage.
    var bestJ = 0;
    for (var j = 1; j <= m; j++) {
      if (d[n][j] < d[n][bestJ]) bestJ = j;
    }

    final out = <WordAlignment>[];
    var i = n;
    var j = bestJ;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && d[i][j] == d[i - 1][j - 1] + sub(i - 1, j - 1)) {
        final a = exp[j - 1];
        final b = got[i - 1];
        final WordMark mark;
        if (a == b) {
          mark = WordMark.correct;
        } else if (i == n && endsMidWord && a.startsWith(b)) {
          mark = WordMark.unfinished;
        } else {
          mark = WordMark.wrong;
        }
        out.add(WordAlignment(a, b, mark));
        i--;
        j--;
      } else if (i > 0 && d[i][j] == d[i - 1][j] + 2) {
        out.add(WordAlignment(null, got[i - 1], WordMark.extra));
        i--;
      } else {
        out.add(WordAlignment(exp[j - 1], null, WordMark.missed));
        j--;
      }
    }
    return out.reversed.toList();
  }

  /// Levenshtein distance within ~a third of the word length.
  static bool _similar(String a, String b) {
    final limit = max(1, (max(a.length, b.length) / 3).ceil());
    if ((a.length - b.length).abs() > limit) return false;
    var prev = List<int>.generate(b.length + 1, (k) => k);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      var rowMin = cur[0];
      for (var k = 1; k <= b.length; k++) {
        cur[k] = min(min(cur[k - 1] + 1, prev[k] + 1),
            prev[k - 1] + (a[i - 1] == b[k - 1] ? 0 : 1));
        rowMin = min(rowMin, cur[k]);
      }
      if (rowMin > limit) return false;
      prev = cur;
    }
    return prev[b.length] <= limit;
  }
}
