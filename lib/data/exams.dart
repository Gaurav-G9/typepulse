class ExamSpec {
  final String id;
  final String title;
  final int durationSec;
  final int targetWpm;
  final int keystrokesGiven;
  final int errorAllowance;
  final String language;

  const ExamSpec({
    required this.id,
    required this.title,
    required this.durationSec,
    required this.targetWpm,
    required this.keystrokesGiven,
    required this.errorAllowance,
    required this.language,
  });
}

class Exams {
  static const upssscEnglish = ExamSpec(
    id: 'upsssc_en',
    title: 'UPSSSC Assistants English Typing Test',
    durationSec: 300,
    targetWpm: 30,
    keystrokesGiven: 1500,
    errorAllowance: 5,
    language: 'en',
  );

  static const upssscHindi = ExamSpec(
    id: 'upsssc_hi',
    title: 'UPSSSC Assistants Hindi Typing Test',
    durationSec: 300,
    targetWpm: 25,
    keystrokesGiven: 1250,
    errorAllowance: 5,
    language: 'hi',
  );

  static const List<ExamSpec> all = [upssscEnglish, upssscHindi];

  static ExamSpec byId(String id) =>
      all.firstWhere((e) => e.id == id, orElse: () => upssscEnglish);
}
