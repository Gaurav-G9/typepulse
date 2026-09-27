class UserProfile {
  final String id;
  final String name;
  final String handle;
  final String languagePref;
  final int dailyGoalMinutes;
  final int targetWpm;
  final bool seededFromArHistory;
  final bool darkMode;

  const UserProfile({
    required this.id,
    required this.name,
    required this.handle,
    this.languagePref = 'en',
    this.dailyGoalMinutes = 25,
    this.targetWpm = 30,
    this.seededFromArHistory = false,
    this.darkMode = false,
  });

  UserProfile copyWith({
    String? name,
    String? handle,
    String? languagePref,
    int? dailyGoalMinutes,
    int? targetWpm,
    bool? seededFromArHistory,
    bool? darkMode,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        handle: handle ?? this.handle,
        languagePref: languagePref ?? this.languagePref,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        targetWpm: targetWpm ?? this.targetWpm,
        seededFromArHistory: seededFromArHistory ?? this.seededFromArHistory,
        darkMode: darkMode ?? this.darkMode,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'handle': handle,
        'languagePref': languagePref,
        'dailyGoalMinutes': dailyGoalMinutes,
        'targetWpm': targetWpm,
        'seededFromArHistory': seededFromArHistory,
        'darkMode': darkMode,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        handle: j['handle'] as String,
        languagePref: j['languagePref'] as String? ?? 'en',
        dailyGoalMinutes: j['dailyGoalMinutes'] as int? ?? 25,
        targetWpm: j['targetWpm'] as int? ?? 30,
        seededFromArHistory: j['seededFromArHistory'] as bool? ?? false,
        darkMode: j['darkMode'] as bool? ?? false,
      );

  static const guest = UserProfile(
    id: 'local-user',
    name: 'Gaurav',
    handle: '@gaurav',
    dailyGoalMinutes: 25,
    targetWpm: 30,
  );
}
