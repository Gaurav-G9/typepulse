/// Member-area "Typing Insight" (`/learning/typing-progress/?days=N`).
class TypingInsight {
  final int days;
  final int passageCount;
  final int minAchievedCount;
  final double avgGross;
  final double avgNet;
  final BestSpeed? bestGross;
  final BestSpeed? bestNet;
  final List<double> dailyBestGross;
  final List<double> dailyBestNet;
  final List<double> dailyMinAchieved;
  final List<ExamAttempt> exams;
  final List<WordStat> misspelled;
  final List<WordStat> added;
  final List<WordStat> deleted;

  const TypingInsight({
    required this.days,
    required this.passageCount,
    required this.minAchievedCount,
    required this.avgGross,
    required this.avgNet,
    this.bestGross,
    this.bestNet,
    this.dailyBestGross = const [],
    this.dailyBestNet = const [],
    this.dailyMinAchieved = const [],
    this.exams = const [],
    this.misspelled = const [],
    this.added = const [],
    this.deleted = const [],
  });

  factory TypingInsight.fromJson(int days, Map<String, dynamic> j) {
    final titles = _csv(j['exam_title']);
    final targets = _csv(j['target_speed']);
    final durations = _csv(j['time_duration']);
    var dates = _csv(j['typing_dates']);
    // The site repeats a single date across all exams.
    if (dates.length == 1 && titles.length > 1) {
      dates = List.filled(titles.length, dates.first);
    }
    final n = [titles.length, targets.length, durations.length, dates.length]
        .reduce((a, b) => a < b ? a : b);
    final exams = <ExamAttempt>[
      for (var i = 0; i < n; i++)
        ExamAttempt(
          title: titles[i],
          date: DateTime.tryParse(dates[i]),
          targetWpm: _num(targets[i]),
          duration: durations[i],
        ),
    ];

    return TypingInsight(
      days: days,
      passageCount: _num(j['passage_count'])?.round() ?? 0,
      minAchievedCount: _num(j['min_achieved_count'])?.round() ?? 0,
      avgGross: _num(j['avg_gross_speed']) ?? 0,
      avgNet: _num(j['avg_net_speed']) ?? 0,
      bestGross: BestSpeed.fromJson(j['best_gross_speed_data'],
          speedKey: 'gross_speed', otherKey: 'corresponding_net_speed'),
      bestNet: BestSpeed.fromJson(j['best_net_speed_data'],
          speedKey: 'net_speed', otherKey: 'corresponding_gross_speed'),
      dailyBestGross: _numList(j['best_gross_speed_list']),
      dailyBestNet: _numList(j['best_net_speed_list']),
      dailyMinAchieved: _numList(j['min_achieved_count_list']),
      exams: exams,
      misspelled: WordStat.listFrom(j['most_misspelled_words']),
      added: WordStat.listFrom(j['most_added_words']),
      deleted: WordStat.listFrom(j['most_deleted_words']),
    );
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  static List<double> _numList(dynamic v) {
    if (v is! List) return const [];
    final out = <double>[];
    for (final e in v) {
      // Entries may be plain numbers or {value: n} style objects.
      final n = _num(e is Map ? (e['value'] ?? e['speed'] ?? e['count']) : e);
      if (n != null) out.add(n);
    }
    return out;
  }

  static List<String> _csv(dynamic v) {
    if (v == null) return const [];
    if (v is List) return v.map((e) => '$e'.trim()).toList();
    final s = v.toString().trim();
    if (s.isEmpty) return const [];
    return s.split(',').map((e) => e.trim()).toList();
  }
}

class BestSpeed {
  final double speed;
  final double other; // net for best gross, gross for best net
  final double timeTakenMin;
  final int keystrokes;

  const BestSpeed({
    required this.speed,
    required this.other,
    required this.timeTakenMin,
    required this.keystrokes,
  });

  static BestSpeed? fromJson(dynamic j,
      {required String speedKey, required String otherKey}) {
    if (j is! Map) return null;
    final speed = TypingInsight._num(j[speedKey]) ?? 0;
    if (speed <= 0) return null;
    return BestSpeed(
      speed: speed,
      other: TypingInsight._num(j[otherKey]) ?? 0,
      timeTakenMin: TypingInsight._num(j['time_taken']) ?? 0,
      keystrokes: TypingInsight._num(j['keystrokes_typed'])?.round() ?? 0,
    );
  }
}

class ExamAttempt {
  final String title;
  final DateTime? date;
  final double? targetWpm;
  final String duration;
  const ExamAttempt({
    required this.title,
    required this.date,
    required this.targetWpm,
    required this.duration,
  });
}

/// One row of "Most misspelled / added / deleted words".
class WordStat {
  final String word;
  final int count;
  final String? correct; // misspelled → intended word

  const WordStat(this.word, this.count, [this.correct]);

  /// Accepts `{word: count}`, `{word: {correct, count}}` or a list of maps.
  static List<WordStat> listFrom(dynamic v) {
    final out = <WordStat>[];
    if (v is Map) {
      v.forEach((k, val) {
        if (val is Map) {
          out.add(WordStat('$k', TypingInsight._num(val['count'])?.round() ?? 1,
              val['correct']?.toString()));
        } else {
          out.add(WordStat('$k', TypingInsight._num(val)?.round() ?? 1));
        }
      });
    } else if (v is List) {
      for (final e in v) {
        if (e is Map) {
          out.add(WordStat(
            '${e['word'] ?? e['typed'] ?? ''}',
            TypingInsight._num(e['count'])?.round() ?? 1,
            e['correct']?.toString(),
          ));
        } else if (e != null) {
          out.add(WordStat('$e', 1));
        }
      }
    }
    out.removeWhere((w) => w.word.isEmpty);
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }
}
