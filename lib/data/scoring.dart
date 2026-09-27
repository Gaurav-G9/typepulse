import 'dart:math';

class ScoreBreakdown {
  final int typedChars;
  final int correctChars;
  final int errors;
  final double wordsTyped;
  final int fullMistakes;
  final int halfMistakes;
  final int totalWrongWords;
  final double netWrongWords;
  final double grossWpm;
  final double netWpm;
  final double accuracy;
  final bool qualified;
  final String formulaNote;

  const ScoreBreakdown({
    required this.typedChars,
    required this.correctChars,
    required this.errors,
    required this.wordsTyped,
    required this.fullMistakes,
    required this.halfMistakes,
    required this.totalWrongWords,
    required this.netWrongWords,
    required this.grossWpm,
    required this.netWpm,
    required this.accuracy,
    required this.qualified,
    required this.formulaNote,
  });
}

class Scoring {
  static const allowedWrong = 5;

  static ScoreBreakdown evaluate({
    required String expected,
    required String typed,
    required int timeTakenSec,
    required int targetWpm,
  }) {
    final minutes = max(timeTakenSec / 60.0, 1 / 60.0);
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

    final expWords = expected.trim().isEmpty ? <String>[] : expected.trim().split(RegExp(r'\s+'));
    final gotWords = typed.trim().isEmpty ? <String>[] : typed.trim().split(RegExp(r'\s+'));
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

    final wordsTyped = typedChars / 5.0;
    final totalWrong = full + ((half + 1) ~/ 2);
    final netWrong = max(0, totalWrong - allowedWrong).toDouble();
    final gross = wordsTyped / minutes;
    final netCorrect = max(0, wordsTyped - netWrong);
    final net = netCorrect / minutes;
    final acc = typedChars == 0 ? 0.0 : (correctChars / typedChars) * 100.0;
    final formula =
        'Net Correct Words = ${wordsTyped.toStringAsFixed(1)} - max(0, $totalWrong - $allowedWrong)';

    return ScoreBreakdown(
      typedChars: typedChars,
      correctChars: correctChars,
      errors: errors,
      wordsTyped: wordsTyped,
      fullMistakes: full,
      halfMistakes: half,
      totalWrongWords: totalWrong,
      netWrongWords: netWrong,
      grossWpm: gross,
      netWpm: net,
      accuracy: acc.clamp(0, 100),
      qualified: net >= targetWpm,
      formulaNote: formula,
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
