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
}

class Scoring {
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
    final rawSec = useDurationForSpeed ? durationSec : timeTakenSec;
    final minutes = max(rawSec / 60.0, 1 / 60.0);
    final typedChars = typed.length;
    var correctChars = 0;
    var errors = 0;
    for (var i = 0; i < typed.length; i++) {
      if (i >= expected.length) {
        errors++;
      } else if (typed[i] == expected[i]) {
        correctChars++;
      } else {
        errors++;
      }
    }

    final expWords =
        expected.trim().isEmpty ? <String>[] : expected.trim().split(RegExp(r'\s+'));
    final gotWords =
        typed.trim().isEmpty ? <String>[] : typed.trim().split(RegExp(r'\s+'));
    var full = 0;
    var half = 0;
    final n = max(expWords.length, gotWords.length);
    for (var i = 0; i < n; i++) {
      if (i >= expWords.length || i >= gotWords.length) {
        full++;
        continue;
      }
      if (expWords[i] == gotWords[i]) continue;
      if (_oneEdit(expWords[i], gotWords[i])) {
        half++;
      } else {
        full++;
      }
    }

    final wordsTyped = keystrokeWordFormula
        ? typedChars / 5.0
        : (typed.trim().isEmpty ? 0.0 : gotWords.length.toDouble());

    // TotalWrong = Full + 0.5 * Half (site-style transparency)
    final totalWrong = full + half * 0.5;
    final e = totalWrong;

    // UPSSSC / AR Typing style:
    // if E <= allowance → no penalty
    // else NetWrong = excess + excess * penaltyMultiplier
    //      NetCorrect = wordsTyped - NetWrong
    late final double netWrong;
    late final double netCorrect;
    late final String formula;
    if (e <= errorAllowance) {
      netWrong = 0;
      netCorrect = wordsTyped;
      formula =
          'Net Correct Words = ${wordsTyped.toStringAsFixed(1)} − ((${e.toStringAsFixed(1)} − $errorAllowance) + (${e.toStringAsFixed(1)} − $errorAllowance) × ${penaltyMultiplier.toStringAsFixed(0)})   [no penalty: E ≤ allowance]';
    } else {
      final excess = e - errorAllowance;
      netWrong = excess + excess * penaltyMultiplier;
      netCorrect = max(0.0, wordsTyped - netWrong);
      formula =
          'Net Correct Words = ${wordsTyped.toStringAsFixed(1)} − ((${e.toStringAsFixed(1)} − $errorAllowance) + (${e.toStringAsFixed(1)} − $errorAllowance) × ${penaltyMultiplier.toStringAsFixed(0)})';
    }

    final gross = wordsTyped / minutes;
    final net = netCorrect / minutes;
    final acc = typedChars == 0 ? 0.0 : (correctChars / typedChars) * 100.0;

    return ScoreBreakdown(
      typedChars: typedChars,
      correctChars: correctChars,
      errors: errors,
      wordsTyped: wordsTyped,
      fullMistakes: full,
      halfMistakes: half,
      totalWrongWords: totalWrong,
      netWrongWords: netWrong,
      netCorrectWords: netCorrect,
      grossWpm: gross,
      netWpm: net,
      accuracy: acc.clamp(0, 100),
      qualified: net >= targetWpm,
      formulaNote: formula,
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
    final rawSec = useDurationForSpeed ? durationSec : timeTakenSec;
    final minutes = max(rawSec / 60.0, 1 / 60.0);
    // Rescale words for keystroke vs whitespace toggle when we only have keystroke-based stock.
    final wordsTyped = keystrokeWordFormula
        ? typedChars / 5.0
        : (storedWordsTyped > 0
            ? storedWordsTyped
            : typedChars / 5.0); // fallback if no whitespace count stored

    final totalWrong = fullMistakes + halfMistakes * 0.5;
    final e = totalWrong;
    late final double netWrong;
    late final double netCorrect;
    late final String formula;
    if (e <= errorAllowance) {
      netWrong = 0;
      netCorrect = wordsTyped;
      formula =
          'Net Correct Words = ${wordsTyped.toStringAsFixed(1)} − ((${e.toStringAsFixed(1)} − $errorAllowance) + (${e.toStringAsFixed(1)} − $errorAllowance) × ${penaltyMultiplier.toStringAsFixed(0)})   [no penalty: E ≤ allowance]';
    } else {
      final excess = e - errorAllowance;
      netWrong = excess + excess * penaltyMultiplier;
      netCorrect = max(0.0, wordsTyped - netWrong);
      formula =
          'Net Correct Words = ${wordsTyped.toStringAsFixed(1)} − ((${e.toStringAsFixed(1)} − $errorAllowance) + (${e.toStringAsFixed(1)} − $errorAllowance) × ${penaltyMultiplier.toStringAsFixed(0)})';
    }

    final gross = wordsTyped / minutes;
    final net = netCorrect / minutes;

    return ScoreBreakdown(
      typedChars: typedChars,
      correctChars: correctChars,
      errors: errors,
      wordsTyped: wordsTyped,
      fullMistakes: fullMistakes,
      halfMistakes: halfMistakes,
      totalWrongWords: totalWrong,
      netWrongWords: netWrong,
      netCorrectWords: netCorrect,
      grossWpm: gross,
      netWpm: net,
      accuracy: accuracy.clamp(0, 100),
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
