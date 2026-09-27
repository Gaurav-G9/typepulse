import 'dart:math';

class ScoreBreakdown {
  final int typedChars;
  final int correctChars;
  final int errors;
  final double wordsTyped;
  final int fullMistakes;
  final int halfMistakes;
  final double totalWrongWords;
  final double netWrongWords;
  final double netCorrectWords;
  final double grossWpm;
  final double netWpm;
  final double accuracy;
  final bool qualified;
  final String formulaNote;
  final int errorAllowance;
  final double penaltyMultiplier;
  final bool useDurationForSpeed;
  final bool keystrokeWordFormula;

  const ScoreBreakdown({
    required this.typedChars,
    required this.correctChars,
    required this.errors,
    required this.wordsTyped,
    required this.fullMistakes,
    required this.halfMistakes,
    required this.totalWrongWords,
    required this.netWrongWords,
    required this.netCorrectWords,
    required this.grossWpm,
    required this.netWpm,
    required this.accuracy,
    required this.qualified,
    required this.formulaNote,
    required this.errorAllowance,
    required this.penaltyMultiplier,
    required this.useDurationForSpeed,
    required this.keystrokeWordFormula,
  });

  /// Same mistake breakdown, but with speeds/result reported by AR Typing.
  ScoreBreakdown withOfficial({
    required double grossWpm,
    required double netWpm,
    required double accuracy,
    required bool qualified,
    required String note,
  }) =>
      ScoreBreakdown(
        typedChars: typedChars,
        correctChars: correctChars,
        errors: errors,
        wordsTyped: wordsTyped,
        fullMistakes: fullMistakes,
        halfMistakes: halfMistakes,
        totalWrongWords: totalWrongWords,
        netWrongWords: netWrongWords,
        netCorrectWords: netCorrectWords,
        grossWpm: grossWpm,
        netWpm: netWpm,
        accuracy: accuracy,
        qualified: qualified,
        formulaNote: note,
        errorAllowance: errorAllowance,
        penaltyMultiplier: penaltyMultiplier,
        useDurationForSpeed: useDurationForSpeed,
        keystrokeWordFormula: keystrokeWordFormula,
      );
}

/// How one typed word lines up against the passage.
enum WordMark { correct, half, full, omitted, extra, pending }

class WordAlignment {
  final String? expected;
  final String? typed;
  final WordMark mark;
  const WordAlignment(this.expected, this.typed, this.mark);

  bool get isError =>
      mark == WordMark.half ||
      mark == WordMark.full ||
      mark == WordMark.omitted ||
      mark == WordMark.extra;
}

class Scoring {
  static final _ws = RegExp(r'\s+');

  static List<String> _words(String s) {
    final t = s.trim();
    return t.isEmpty ? <String>[] : t.split(_ws);
  }

  /// Aligns typed words against the passage (word-level edit distance).
  ///
  /// - A skipped or extra word costs one full mistake, but only that word —
  ///   the rest of the passage re-syncs instead of cascading into errors.
  /// - A word within one character edit of the original is a half mistake.
  /// - The untyped tail of the passage is never penalised (timed tests rarely
  ///   finish the passage), and a trailing word still being typed when time
  ///   ran out counts as [WordMark.pending] if it is a prefix of the original.
  static List<WordAlignment> alignWords(String expected, String typed) {
    final exp = _words(expected);
    final got = _words(typed);
    final n = got.length;
    final m = exp.length;
    if (n == 0) return const [];
    final endsMidWord = typed.isNotEmpty && !_ws.hasMatch(typed[typed.length - 1]);

    // Costs in half-mistake units: half = 1, full = 2.
    int sub(int i, int j) {
      final a = exp[j];
      final b = got[i];
      if (a == b) return 0;
      if (i == n - 1 && endsMidWord && a.startsWith(b)) return 0;
      return _oneEdit(a, b) ? 1 : 2;
    }

    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      d[i][0] = i * 2;
    }
    for (var j = 1; j <= m; j++) {
      d[0][j] = j * 2;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final diag = d[i - 1][j - 1] + sub(i - 1, j - 1);
        final extra = d[i - 1][j] + 2;
        final omit = d[i][j - 1] + 2;
        d[i][j] = min(diag, min(extra, omit));
      }
    }

    // Free tail: typed text may stop anywhere in the passage.
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
          mark = WordMark.pending;
        } else {
          mark = _oneEdit(a, b) ? WordMark.half : WordMark.full;
        }
        out.add(WordAlignment(a, b, mark));
        i--;
        j--;
      } else if (i > 0 && d[i][j] == d[i - 1][j] + 2) {
        out.add(WordAlignment(null, got[i - 1], WordMark.extra));
        i--;
      } else {
        out.add(WordAlignment(exp[j - 1], null, WordMark.omitted));
        j--;
      }
    }
    return out.reversed.toList();
  }

  static ScoreBreakdown evaluate({
    required String expected,
    required String typed,
    required int durationSec,
    required int timeTakenSec,
    required int targetWpm,
    int errorAllowance = 5,
    double penaltyMultiplier = 5,
    bool useDurationForSpeed = false,
    bool keystrokeWordFormula = true,
  }) {
    final typedChars = typed.length;
    final alignment = alignWords(expected, typed);

    var full = 0;
    var half = 0;
    var correctChars = 0;
    for (final w in alignment) {
      switch (w.mark) {
        case WordMark.correct:
        case WordMark.pending:
          correctChars += w.typed!.length;
        case WordMark.half:
          half++;
          correctChars += max(0, w.typed!.length - 1);
        case WordMark.full:
        case WordMark.omitted:
        case WordMark.extra:
          full++;
      }
    }
    // Word separators count as correct keystrokes.
    final wordChars = _words(typed).fold<int>(0, (p, w) => p + w.length);
    correctChars = (correctChars + (typedChars - wordChars)).clamp(0, typedChars);
    final errors = typedChars - correctChars;

    final wordsTyped = keystrokeWordFormula
        ? typedChars / 5.0
        : _words(typed).length.toDouble();

    return _score(
      typedChars: typedChars,
      correctChars: correctChars,
      errors: errors,
      wordsTyped: wordsTyped,
      fullMistakes: full,
      halfMistakes: half,
      accuracy: typedChars == 0 ? 0.0 : correctChars / typedChars * 100.0,
      durationSec: durationSec,
      timeTakenSec: timeTakenSec,
      targetWpm: targetWpm,
      errorAllowance: errorAllowance,
      penaltyMultiplier: penaltyMultiplier,
      useDurationForSpeed: useDurationForSpeed,
      keystrokeWordFormula: keystrokeWordFormula,
    );
  }

  /// Recompute display metrics from a stored session when texts are missing.
  static ScoreBreakdown approximateFromSession({
    required int typedChars,
    required double storedWordsTyped,
    required int fullMistakes,
    required int halfMistakes,
    required int durationSec,
    required int timeTakenSec,
    required int targetWpm,
    required double accuracy,
    required int correctChars,
    required int errors,
    int errorAllowance = 5,
    double penaltyMultiplier = 5,
    bool useDurationForSpeed = false,
    bool keystrokeWordFormula = true,
  }) {
    // Rescale words for keystroke vs whitespace toggle when we only have keystroke-based stock.
    final wordsTyped = keystrokeWordFormula
        ? typedChars / 5.0
        : (storedWordsTyped > 0
            ? storedWordsTyped
            : typedChars / 5.0); // fallback if no whitespace count stored

    return _score(
      typedChars: typedChars,
      correctChars: correctChars,
      errors: errors,
      wordsTyped: wordsTyped,
      fullMistakes: fullMistakes,
      halfMistakes: halfMistakes,
      accuracy: accuracy,
      durationSec: durationSec,
      timeTakenSec: timeTakenSec,
      targetWpm: targetWpm,
      errorAllowance: errorAllowance,
      penaltyMultiplier: penaltyMultiplier,
      useDurationForSpeed: useDurationForSpeed,
      keystrokeWordFormula: keystrokeWordFormula,
    );
  }

  /// UPSSSC / AR Typing style:
  /// if E <= allowance → no penalty
  /// else NetWrong = excess + excess * penaltyMultiplier
  ///      NetCorrect = wordsTyped - NetWrong
  static ScoreBreakdown _score({
    required int typedChars,
    required int correctChars,
    required int errors,
    required double wordsTyped,
    required int fullMistakes,
    required int halfMistakes,
    required double accuracy,
    required int durationSec,
    required int timeTakenSec,
    required int targetWpm,
    required int errorAllowance,
    required double penaltyMultiplier,
    required bool useDurationForSpeed,
    required bool keystrokeWordFormula,
  }) {
    final rawSec = useDurationForSpeed ? durationSec : timeTakenSec;
    final minutes = max(rawSec / 60.0, 1 / 60.0);

    // TotalWrong = Full + 0.5 * Half (site-style transparency)
    final e = fullMistakes + halfMistakes * 0.5;
    final excess = max(0.0, e - errorAllowance);
    final netWrong = excess + excess * penaltyMultiplier;
    final netCorrect = max(0.0, wordsTyped - netWrong);
    final w = wordsTyped.toStringAsFixed(1);
    final es = e.toStringAsFixed(1);
    final pm = penaltyMultiplier.toStringAsFixed(0);
    final formula = e <= errorAllowance
        ? 'Net Correct Words = $w   [E = $es ≤ allowance $errorAllowance → no penalty]'
        : 'Net Correct Words = $w − (($es − $errorAllowance) + ($es − $errorAllowance) × $pm) = ${netCorrect.toStringAsFixed(1)}';

    final gross = wordsTyped / minutes;
    final net = netCorrect / minutes;

    return ScoreBreakdown(
      typedChars: typedChars,
      correctChars: correctChars,
      errors: errors,
      wordsTyped: wordsTyped,
      fullMistakes: fullMistakes,
      halfMistakes: halfMistakes,
      totalWrongWords: e,
      netWrongWords: netWrong,
      netCorrectWords: netCorrect,
      grossWpm: gross,
      netWpm: net,
      accuracy: accuracy.clamp(0.0, 100.0),
      qualified: net >= targetWpm,
      formulaNote: formula,
      errorAllowance: errorAllowance,
      penaltyMultiplier: penaltyMultiplier,
      useDurationForSpeed: useDurationForSpeed,
      keystrokeWordFormula: keystrokeWordFormula,
    );
  }

  static bool _oneEdit(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    if (a == b) return true;
    var i = 0, j = 0, hits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
      } else {
        hits++;
        if (hits > 1) return false;
        if (a.length > b.length) {
          i++;
        } else if (b.length > a.length) {
          j++;
        } else {
          i++;
          j++;
        }
      }
    }
    hits += (a.length - i) + (b.length - j);
    return hits <= 1;
  }
}
