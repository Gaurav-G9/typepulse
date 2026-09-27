class TypingSession {
  final String id;
  final DateTime startedAt;
  final int durationSec;
  final int timeTakenSec;
  final String language;
  final String mode;
  final String examTitle;
  final String passageTitle;
  final int keystrokesGiven;
  final int typedChars;
  final int correctChars;
  final int errors;
  final double wordsTyped;
  final int fullMistakes;
  final int halfMistakes;
  final int totalWrongWords;
  final double netWrongWords;
  final int backspaceCount;
  final double wpm;
  final double netWpm;
  final double accuracy;
  final bool qualified;
  final String formulaNote;
  final int? liveRank;
  final int? liveField;

  const TypingSession({
    required this.id,
    required this.startedAt,
    required this.durationSec,
    required this.timeTakenSec,
    required this.language,
    required this.mode,
    required this.examTitle,
    required this.passageTitle,
    required this.keystrokesGiven,
    required this.typedChars,
    required this.correctChars,
    required this.errors,
    required this.wordsTyped,
    required this.fullMistakes,
    required this.halfMistakes,
    required this.totalWrongWords,
    required this.netWrongWords,
    required this.backspaceCount,
    required this.wpm,
    required this.netWpm,
    required this.accuracy,
    required this.qualified,
    required this.formulaNote,
    this.liveRank,
    this.liveField,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'durationSec': durationSec,
        'timeTakenSec': timeTakenSec,
        'language': language,
        'mode': mode,
        'examTitle': examTitle,
        'passageTitle': passageTitle,
        'keystrokesGiven': keystrokesGiven,
        'typedChars': typedChars,
        'correctChars': correctChars,
        'errors': errors,
        'wordsTyped': wordsTyped,
        'fullMistakes': fullMistakes,
        'halfMistakes': halfMistakes,
        'totalWrongWords': totalWrongWords,
        'netWrongWords': netWrongWords,
        'backspaceCount': backspaceCount,
        'wpm': wpm,
        'netWpm': netWpm,
        'accuracy': accuracy,
        'qualified': qualified,
        'formulaNote': formulaNote,
        'liveRank': liveRank,
        'liveField': liveField,
      };

  factory TypingSession.fromJson(Map<String, dynamic> j) => TypingSession(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        durationSec: j['durationSec'] as int? ?? 60,
        timeTakenSec: j['timeTakenSec'] as int? ?? j['durationSec'] as int? ?? 60,
        language: j['language'] as String,
        mode: j['mode'] as String,
        examTitle: j['examTitle'] as String? ?? 'Practice',
        passageTitle: j['passageTitle'] as String,
        keystrokesGiven: j['keystrokesGiven'] as int? ?? 0,
        typedChars: j['typedChars'] as int,
        correctChars: j['correctChars'] as int,
        errors: j['errors'] as int,
        wordsTyped: (j['wordsTyped'] as num?)?.toDouble() ??
            ((j['typedChars'] as num).toDouble() / 5.0),
        fullMistakes: j['fullMistakes'] as int? ?? 0,
        halfMistakes: j['halfMistakes'] as int? ?? 0,
        totalWrongWords: j['totalWrongWords'] as int? ?? j['errors'] as int? ?? 0,
        netWrongWords: (j['netWrongWords'] as num?)?.toDouble() ?? 0,
        backspaceCount: j['backspaceCount'] as int? ?? 0,
        wpm: (j['wpm'] as num).toDouble(),
        netWpm: (j['netWpm'] as num).toDouble(),
        accuracy: (j['accuracy'] as num).toDouble(),
        qualified: j['qualified'] as bool? ?? false,
        formulaNote: j['formulaNote'] as String? ?? '',
        liveRank: j['liveRank'] as int?,
        liveField: j['liveField'] as int?,
      );
}
