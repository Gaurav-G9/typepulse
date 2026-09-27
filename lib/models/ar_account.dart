/// One AR Typing login stored on this device.
class ArAccount {
  final String id;
  final String email;
  final String displayName;

  const ArAccount({
    required this.id,
    required this.email,
    required this.displayName,
  });

  ArAccount copyWith({String? displayName}) => ArAccount(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
      };

  factory ArAccount.fromJson(Map<String, dynamic> j) => ArAccount(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: j['displayName'] as String? ?? j['email'] as String,
      );

  static String idFromEmail(String email) => email.trim().toLowerCase();
}
