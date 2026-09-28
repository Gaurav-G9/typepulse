/// One row of the AR Typing member-area **Typing History**
/// (`GET /learning/typedPassages/`).
///
/// Only values the website provides are exposed; anything the site shows as
/// "NA" / "See In Detail" is `null` here and is never invented.
class ArResult {
  /// The website shows "See In Detail" instead of speeds for results typed
  /// before this date when the server stored 0.
  static final legacyCutoff = DateTime.utc(2025, 3, 13);

  final Map<String, dynamic> raw;
  final String id;
  final DateTime date;
  final bool dateOnly;
  final String examTitle;
  final String passageTitle;
  final String? examSlug;
  final int? durationSec; // allotted time (time_duration)
  final int? timeTakenSec; // time used (time_taken, minutes on the API)
  final int? keystrokesGiven;
  final int? keystrokesTyped;
  final int? keystrokesError;
  final int? targetWpm; // null when the site shows NA (0)
  final double? grossWpm; // null when the site shows "See In Detail"
  final double? netWpm; // null when the site shows "See In Detail"
  final bool? qualified;
  final int? backspaces;
  final double? totalWrongWords;
  final String? passageText;
  final String? typedText;
  final String language; // en | hi

  const ArResult._({
    required this.raw,
    required this.id,
    required this.date,
    required this.dateOnly,
    required this.examTitle,
    required this.passageTitle,
    required this.examSlug,
    required this.durationSec,
    required this.timeTakenSec,
    required this.keystrokesGiven,
    required this.keystrokesTyped,
    required this.keystrokesError,
    required this.targetWpm,
    required this.grossWpm,
    required this.netWpm,
    required this.qualified,
    required this.backspaces,
    required this.totalWrongWords,
    required this.passageText,
    required this.typedText,
    required this.language,
  });

  /// Accuracy from keystrokes, only when the site sent `key_strokes_error`.
  double? get accuracy {
    final typed = keystrokesTyped, err = keystrokesError;
    if (typed == null || err == null || typed <= 0) return null;
    return ((typed - err) / typed * 100).clamp(0.0, 100.0);
  }

  bool get hasTexts =>
      (passageText?.trim().isNotEmpty ?? false) &&
      (typedText?.trim().isNotEmpty ?? false);

  /// Parses one API row. [order] breaks ties for rows that only carry a
  /// calendar date (higher = newer, i.e. earlier in the API's list).
  factory ArResult.fromRow(Map<String, dynamic> e, {int order = 0}) {
    final exam = _str(e['exam_title']) ?? _str(e['exam_name']) ?? 'Typing test';
    final passage = _str(e['passage_title']) ?? 'Passage';
    final rawDate = e['typing_date'] ?? e['created_at'];
    final dateOnly = rawDate is String && !rawDate.contains(':');
    var date = _parseDate(rawDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (dateOnly) date = date.add(Duration(milliseconds: order));

    final timeTakenMin = _num(e['time_taken']);
    final typed = _num(e['key_strokes_typed'])?.round();
    final targetRaw = _num(e['target_speed'])?.round();
    final legacy = date.toUtc().isBefore(legacyCutoff);

    // Same display rules as the member-area Typing History table: a 0 speed
    // on a pre-cutoff result is shown as "See In Detail" (not available).
    var gross = _num(e['gross_speed']);
    if (gross == 0 && legacy) gross = null;
    var net = _num(e['net_speed']);
    if (net == 0 && legacy) net = null;

    final idRaw = e['id'] ?? e['typing_id'] ?? e['pk'];
    final id = idRaw != null
        ? 'ar-$idRaw'
        // Rows without an id: fingerprint + position counted from the oldest
        // result, which stays the same as newer results are added.
        : 'ar-${rawDate ?? ''}|$exam|$passage|$typed|${e['time_taken']}|'
            '${e['gross_speed']}|${e['net_speed']}#$order';

    final passageText = _str(e['passage_text']);
    return ArResult._(
      raw: e,
      id: id,
      date: date,
      dateOnly: dateOnly,
      examTitle: exam,
      passageTitle: passage,
      examSlug: _str(e['exam_slug']),
      durationSec: _durationSec(e['time_duration']),
      timeTakenSec: timeTakenMin == null ? null : (timeTakenMin * 60).round(),
      keystrokesGiven: _num(e['key_strokes_given'])?.round(),
      keystrokesTyped: typed,
      keystrokesError: _num(e['key_strokes_error'])?.round(),
      targetWpm: targetRaw == null || targetRaw == 0 ? null : targetRaw,
      grossWpm: gross,
      netWpm: net,
      qualified: _bool(e['qualified']),
      backspaces: _num(e['back_space_count'])?.round(),
      totalWrongWords: _num(e['total_wrong_words']),
      passageText: passageText,
      typedText: _str(e['typed_passage_text']),
      language: _lang(exam, e['language_id'] ?? e['language'], passageText),
    );
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.trim().isEmpty ? null : s;
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  static bool? _bool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (const {'true', '1', 'yes', 'qualified'}.contains(s)) return true;
      if (const {'false', '0', 'no', 'not qualified'}.contains(s)) return false;
    }
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// `HH:mm:ss` / `mm:ss` (optionally fractional) or a bare number of
  /// seconds — the two forms the website accepts.
  static int? _durationSec(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.round();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final n = double.tryParse(s);
    if (n != null) return n.round();
    final parts = s.split(':').map((p) => double.tryParse(p.trim())).toList();
    if (parts.any((p) => p == null)) return null;
    if (parts.length == 3) {
      return (parts[0]! * 3600 + parts[1]! * 60 + parts[2]!).round();
    }
    if (parts.length == 2) return (parts[0]! * 60 + parts[1]!).round();
    return null;
  }

  static final _devanagari = RegExp('[ऀ-ॿ]');

  static String _lang(String exam, dynamic language, String? text) {
    final lower = exam.toLowerCase();
    if (lower.contains('hindi') ||
        lower.contains('mangal') ||
        lower.contains('krutidev')) {
      return 'hi';
    }
    if (text != null && _devanagari.hasMatch(text)) return 'hi';
    if (language is Map) {
      final name = '${language['name'] ?? language['title'] ?? ''}';
      if (name.toLowerCase().contains('hindi')) return 'hi';
      language = language['id'];
    }
    if (language == 2 || language == '2') return 'hi';
    return 'en';
  }
}

/// `mm:ss` for a number of seconds.
String mmss(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
