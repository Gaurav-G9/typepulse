class UserProfile {
  final String id;
  final String name;
  final String handle;
  final String languagePref;
  final int dailyGoalMinutes;
  final int targetWpm;

  const UserProfile({
    required this.id,
    required this.name,
    required this.handle,
    this.languagePref = 'en',
    this.dailyGoalMinutes = 20,
    this.targetWpm = 40,
  });

  UserProfile copyWith({
    String? name,
    String? handle,
    String? languagePref,
    int? dailyGoalMinutes,
    int? targetWpm,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        handle: handle ?? this.handle,
        languagePref: languagePref ?? this.languagePref,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        targetWpm: targetWpm ?? this.targetWpm,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'handle': handle,
        'languagePref': languagePref,
        'dailyGoalMinutes': dailyGoalMinutes,
        'targetWpm': targetWpm,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        handle: j['handle'] as String,
        languagePref: j['languagePref'] as String? ?? 'en',
        dailyGoalMinutes: j['dailyGoalMinutes'] as int? ?? 20,
        targetWpm: j['targetWpm'] as int? ?? 40,
      );

  static const guest = UserProfile(
    id: 'local-user',
    name: 'Gaurav',
    handle: '@gaurav',
  );
}
