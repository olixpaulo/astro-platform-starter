class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.preferredSourceLang,
    required this.preferredTargetLang,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String preferredSourceLang;
  final String preferredTargetLang;

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: (json['full_name'] as String?) ?? '',
        role: (json['role'] as String?) ?? 'user',
        preferredSourceLang: (json['preferred_source_lang'] as String?) ?? 'auto',
        preferredTargetLang: (json['preferred_target_lang'] as String?) ?? 'en',
      );
}
