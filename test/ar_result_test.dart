import 'package:flutter_test/flutter_test.dart';
import 'package:typepulse/data/text_compare.dart';
import 'package:typepulse/models/ar_result.dart';

void main() {
  group('ArResult.fromRow (member-area Typing History row)', () {
    final row = {
      'exam_title': 'UPSSSC Assistant English',
      'exam_slug': 'upsssc-assistant',
      'passage_title': 'Chronic Stress',
      'typing_date': '2026-09-20T15:04:05Z',
      'time_duration': '00:05:00',
      'time_taken': 4.95,
      'key_strokes_given': 1500,
      'key_strokes_typed': 1000,
      'key_strokes_error': 20,
      'target_speed': 30,
      'gross_speed': '40.40',
      'net_speed': 39.6,
      'qualified': true,
      'back_space_count': 12,
      'total_wrong_words': 2,
      'passage_text': 'the quick brown fox',
      'typed_passage_text': 'the quick brwn fox',
    };

    test('maps every field the website shows', () {
      final r = ArResult.fromRow(row);
      expect(r.date, DateTime.utc(2026, 9, 20, 15, 4, 5).toLocal());
      expect(r.examTitle, 'UPSSSC Assistant English');
      expect(r.passageTitle, 'Chronic Stress');
      expect(r.durationSec, 300);
      expect(r.timeTakenSec, 297);
      expect(r.keystrokesGiven, 1500);
      expect(r.keystrokesTyped, 1000);
      expect(r.targetWpm, 30);
      expect(r.grossWpm, 40.4);
      expect(r.netWpm, 39.6);
      expect(r.qualified, isTrue);
      expect(r.accuracy, closeTo(98, 1e-9));
      expect(r.totalWrongWords, 2);
      expect(r.hasTexts, isTrue);
      expect(ArResult.fromRow(row).id, r.id, reason: 'stable across syncs');
    });

    test('missing values stay missing (no invented data)', () {
      final r = ArResult.fromRow({
        'exam_title': 'X',
        'typing_date': '2026-09-20',
        'target_speed': 0,
        'gross_speed': 20,
        'net_speed': 18,
      });
      expect(r.targetWpm, isNull, reason: 'site shows NA for target 0');
      expect(r.accuracy, isNull, reason: 'no key_strokes_error');
      expect(r.qualified, isNull);
      expect(r.timeTakenSec, isNull);
      expect(r.hasTexts, isFalse);
    });

    test('pre-13-Mar-2025 zero speeds are NA, like "See In Detail"', () {
      final r = ArResult.fromRow({
        'typing_date': '2025-01-10',
        'gross_speed': 0,
        'net_speed': 0,
      });
      expect(r.grossWpm, isNull);
      expect(r.netWpm, isNull);
    });

    test('bare-number duration is seconds', () {
      expect(ArResult.fromRow({'time_duration': '600'}).durationSec, 600);
      expect(ArResult.fromRow({'time_duration': 300}).durationSec, 300);
    });

    test('date-only rows keep the API order', () {
      final newer = ArResult.fromRow({'typing_date': '2026-09-20'}, order: 2);
      final older = ArResult.fromRow({'typing_date': '2026-09-20'}, order: 1);
      expect(newer.date.isAfter(older.date), isTrue);
      expect(newer.id, isNot(older.id));
    });

    test('Devanagari passage → Hindi', () {
      expect(ArResult.fromRow({'passage_text': 'सुशासन तभी टिकता है'}).language,
          'hi');
    });
  });

  group('TextCompare', () {
    const passage = 'the quick brown fox jumps over the lazy dog';

    test('untyped rest of the passage is ignored', () {
      final a = TextCompare.align(passage, 'the quick brown ');
      expect(a.every((w) => w.mark == WordMark.correct), isTrue);
      expect(a.length, 3);
    });

    test('a skipped word is one "missed", not a cascade', () {
      final a = TextCompare.align(passage, 'the quick fox jumps over');
      expect(a.where((w) => w.isError).map((w) => w.mark), [WordMark.missed]);
    });

    test('wrong and extra words', () {
      final a = TextCompare.align(passage, 'the quikc very brown');
      expect(a.map((w) => w.mark), [
        WordMark.correct,
        WordMark.wrong,
        WordMark.extra,
        WordMark.correct,
      ]);
    });

    test('last word cut off by the timer is unfinished, not wrong', () {
      expect(
          TextCompare.align(passage, 'the qui').last.mark, WordMark.unfinished);
    });
  });
}
