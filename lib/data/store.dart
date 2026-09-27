import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/leaderboard_entry.dart';
import '../models/session.dart';
import '../models/user_profile.dart';
import 'scoring.dart';

class AppStore extends ChangeNotifier {
  static const _kProfile = 'tp_profile';
  static const _kSessions = 'tp_sessions';

  UserProfile profile = UserProfile.guest;
  List<TypingSession> sessions = [];
  bool loaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString(_kProfile);
    if (p != null) {
      profile = UserProfile.fromJson(jsonDecode(p) as Map<String, dynamic>);
    }
    final s = prefs.getString(_kSessions);
    if (s != null) {
      final list = jsonDecode(s) as List<dynamic>;
      sessions = list
          .map((e) => TypingSession.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    }
    if (sessions.isEmpty) {
      sessions = [_sampleDashboardSession()];
      await _persist();
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfile, jsonEncode(profile.toJson()));
    await prefs.setString(
      _kSessions,
      jsonEncode(sessions.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> updateProfile(UserProfile next) async {
    profile = next;
    await _persist();
    notifyListeners();
  }

  Future<void> addSession(TypingSession session) async {
    sessions = [session, ...sessions];
    await _persist();
    notifyListeners();
  }

  List<TypingSession> get today {
    final now = DateTime.now();
    return sessions
        .where((s) =>
            s.startedAt.year == now.year &&
            s.startedAt.month == now.month &&
            s.startedAt.day == now.day)
        .toList();
  }

  int get streak {
    if (sessions.isEmpty) return 0;
    final days = sessions
        .map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    var count = 0;
    var cursor = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (final d in days) {
      if (d == cursor) {
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (d.isBefore(cursor)) {
        break;
      }
    }
    return count;
  }

  double get bestNetWpm {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.netWpm).reduce(max);
  }

  double get avgAccuracy {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.accuracy).reduce((a, b) => a + b) / sessions.length;
  }

  double get avgGross {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.wpm).reduce((a, b) => a + b) / sessions.length;
  }

  double get avgNet {
    if (sessions.isEmpty) return 0;
    return sessions.map((s) => s.netWpm).reduce((a, b) => a + b) / sessions.length;
  }

  int get qualifiedCount => sessions.where((s) => s.qualified).length;

  int get todayMinutes =>
      today.fold<int>(0, (p, s) => p + (s.durationSec / 60).ceil());

  List<double> last7NetWpm() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      final daySessions = sessions.where((s) =>
          s.startedAt.year == day.year &&
          s.startedAt.month == day.month &&
          s.startedAt.day == day.day);
      if (daySessions.isEmpty) return 0;
      return daySessions.map((s) => s.netWpm).reduce(max);
    });
  }

  List<LeaderboardEntry> weeklyBoard() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final mine = sessions.where((s) => s.startedAt.isAfter(weekAgo)).toList();
    final myBest = mine.isEmpty ? 0.0 : mine.map((s) => s.netWpm).reduce(max);
    final myAcc = mine.isEmpty
        ? 0.0
        : mine.map((s) => s.accuracy).reduce((a, b) => a + b) / mine.length;

    final rng = Random(42);
    final names = [
      ['Aarav Mishra', '@aarav'],
      ['Isha Verma', '@isha'],
      ['Rohan Gupta', '@rohan'],
      ['Neha Singh', '@neha'],
      ['Kabir Joshi', '@kabir'],
      ['Ananya Rao', '@ananya'],
      ['Vikram Yadav', '@vikram'],
      ['Meera Shah', '@meera'],
      ['Dev Patel', '@dev'],
      ['Sara Khan', '@sara'],
    ];

    final list = <LeaderboardEntry>[
      LeaderboardEntry(
        userId: profile.id,
        name: profile.name,
        handle: profile.handle,
        bestNetWpm: myBest,
        accuracy: myAcc,
        sessions: mine.length,
        streak: streak,
        isYou: true,
      ),
      ...List.generate(names.length, (i) {
        final base = 28 + rng.nextInt(28) + rng.nextDouble();
        return LeaderboardEntry(
          userId: 'bot-$i',
          name: names[i][0],
          handle: names[i][1],
          bestNetWpm: base,
          accuracy: 92 + rng.nextDouble() * 7,
          sessions: 4 + rng.nextInt(18),
          streak: rng.nextInt(14),
        );
      }),
    ]..sort((a, b) => b.bestNetWpm.compareTo(a.bestNetWpm));
    return list;
  }

  static TypingSession buildSession({
    required int allottedSec,
    required int timeTakenSec,
    required String language,
    required String mode,
    required String examTitle,
    required String passageTitle,
    required String expected,
    required String typed,
    required int backspaceCount,
    required int targetWpm,
    int? liveRank,
    int? liveField,
  }) {
    final score = Scoring.evaluate(
      expected: expected,
      typed: typed,
      timeTakenSec: timeTakenSec,
      targetWpm: targetWpm,
    );
    return TypingSession(
      id: const Uuid().v4(),
      startedAt: DateTime.now(),
      durationSec: allottedSec,
      timeTakenSec: timeTakenSec,
      language: language,
      mode: mode,
      examTitle: examTitle,
      passageTitle: passageTitle,
      keystrokesGiven: expected.length,
      typedChars: score.typedChars,
      correctChars: score.correctChars,
      errors: score.errors,
      wordsTyped: score.wordsTyped,
      fullMistakes: score.fullMistakes,
      halfMistakes: score.halfMistakes,
      totalWrongWords: score.totalWrongWords,
      netWrongWords: score.netWrongWords,
      backspaceCount: backspaceCount,
      wpm: score.grossWpm,
      netWpm: max(score.netWpm, 0),
      accuracy: score.accuracy,
      qualified: score.qualified,
      formulaNote: score.formulaNote,
      liveRank: liveRank,
      liveField: liveField,
    );
  }

  static TypingSession _sampleDashboardSession() {
    return TypingSession(
      id: 'sample-upsssc',
      startedAt: DateTime(2026, 9, 27, 18, 40),
      durationSec: 300,
      timeTakenSec: 299,
      language: 'en',
      mode: 'practice',
      examTitle: 'UPSSSC Assistants English Typing Test',
      passageTitle: 'India From Impementor to Innovator – Startup Root',
      keystrokesGiven: 1500,
      typedChars: 947,
      correctChars: 938,
      errors: 9,
      wordsTyped: 189.4,
      fullMistakes: 2,
      halfMistakes: 2,
      totalWrongWords: 3,
      netWrongWords: 0,
      backspaceCount: 26,
      wpm: 37.88,
      netWpm: 37.88,
      accuracy: 99,
      qualified: true,
      formulaNote:
          'Net Correct Words = 189.4 − ((3 − 5) + (3 − 5) × 5)   [floor at 0]',
    );
  }
}
