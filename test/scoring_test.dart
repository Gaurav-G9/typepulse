import 'package:flutter_test/flutter_test.dart';
import 'package:typepulse/data/scoring.dart';

ScoreBreakdown score(String expected, String typed,
        {int timeTakenSec = 60, int targetWpm = 30}) =>
    Scoring.evaluate(
      expected: expected,
      typed: typed,
      durationSec: 300,
      timeTakenSec: timeTakenSec,
      targetWpm: targetWpm,
    );

void main() {
  const passage = 'the quick brown fox jumps over the lazy dog again and again';

  test('untyped remainder of the passage is not penalised', () {
    final b = score(passage, 'the quick brown fox ');
    expect(b.fullMistakes, 0);
    expect(b.halfMistakes, 0);
    expect(b.accuracy, 100);
    expect(b.netWpm, closeTo(b.grossWpm, 1e-9));
    expect(b.netWpm, greaterThan(0));
  });

  test('a realistic timed test does not collapse to 0 net', () {
    final long = List.filled(300, 'word').join(' ');
    final typed = List.filled(150, 'word').join(' ');
    final b = score(long, typed, timeTakenSec: 300);
    expect(b.fullMistakes, 0);
    expect(b.netWpm, closeTo(typed.length / 5 / 5, 1e-9));
  });

  test('a skipped word costs one full mistake, not a cascade', () {
    final b = score(passage, 'the quick fox jumps over the lazy dog');
    expect(b.fullMistakes, 1);
    expect(b.halfMistakes, 0);
  });

  test('an extra word costs one full mistake', () {
    final b = score(passage, 'the very quick brown fox jumps');
    expect(b.fullMistakes, 1);
  });

  test('one-character slip is a half mistake', () {
    final b = score(passage, 'the quikc brown fox');
    // transposition = 2 edits → full; single substitution → half.
    expect(b.fullMistakes, 1);
    final c = score(passage, 'the quack brown fox');
    expect(c.halfMistakes, 1);
    expect(c.fullMistakes, 0);
    expect(c.totalWrongWords, 0.5);
  });

  test('last word cut off mid-typing is not a mistake', () {
    final b = score(passage, 'the quick bro');
    expect(b.fullMistakes, 0);
    expect(b.halfMistakes, 0);
    final aligned = Scoring.alignWords(passage, 'the quick bro');
    expect(aligned.last.mark, WordMark.pending);
    // ...but a finished (space-terminated) short word is.
    expect(score(passage, 'the quick bro ').fullMistakes, 1);
  });

  test('penalty applies only beyond the error allowance', () {
    // 6 wrong words, allowance 5 → excess 1 → net wrong 1 + 1×5 = 6.
    final exp = List.generate(20, (i) => 'alpha$i').join(' ');
    final typed =
        List.generate(20, (i) => i < 6 ? 'zzzzzz$i' : 'alpha$i').join(' ');
    final b = score(exp, typed);
    expect(b.fullMistakes, 6);
    expect(b.netWrongWords, 6);
    expect(b.netCorrectWords, closeTo(b.wordsTyped - 6, 1e-9));
    expect(b.formulaNote, contains('−'));
  });

  test('empty input scores zero without errors', () {
    final b = score(passage, '');
    expect(b.fullMistakes, 0);
    expect(b.accuracy, 0);
    expect(b.netWpm, 0);
    expect(b.qualified, isFalse);
  });

  test('approximateFromSession keeps stored mistake counts', () {
    final b = Scoring.approximateFromSession(
      typedChars: 1000,
      storedWordsTyped: 200,
      fullMistakes: 2,
      halfMistakes: 2,
      durationSec: 300,
      timeTakenSec: 300,
      targetWpm: 30,
      accuracy: 99,
      correctChars: 990,
      errors: 10,
    );
    expect(b.totalWrongWords, 3);
    expect(b.netWpm, closeTo(40, 1e-9));
    expect(b.qualified, isTrue);
  });
}
