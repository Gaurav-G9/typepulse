class LeaderboardEntry {
  final String userId;
  final String name;
  final String handle;
  final double bestNetWpm;
  final double accuracy;
  final int sessions;
  final int streak;
  final bool isYou;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.handle,
    required this.bestNetWpm,
    required this.accuracy,
    required this.sessions,
    required this.streak,
    this.isYou = false,
  });
}

class LiveRacer {
  final String id;
  final String name;
  final bool isYou;
  double progress;
  double wpm;
  double accuracy;
  bool finished;

  LiveRacer({
    required this.id,
    required this.name,
    this.isYou = false,
    this.progress = 0,
    this.wpm = 0,
    this.accuracy = 100,
    this.finished = false,
  });
}
