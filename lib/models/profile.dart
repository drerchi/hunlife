enum AccessStatus { active, blocked, expired }

class Profile {
  final String id;
  final String email;
  final String? fullName;
  final String role;
  final bool isBlocked;
  final DateTime? accessUntil;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isBlocked,
    required this.accessUntil,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  AccessStatus get accessStatus {
    if (isBlocked) return AccessStatus.blocked;
    if (accessUntil != null && accessUntil!.isBefore(DateTime.now())) {
      return AccessStatus.expired;
    }
    return AccessStatus.active;
  }

  bool get hasActiveAccess => isAdmin || accessStatus == AccessStatus.active;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      role: json['role'] as String? ?? 'user',
      isBlocked: json['is_blocked'] as bool? ?? false,
      accessUntil: json['access_until'] == null
          ? null
          : DateTime.parse(json['access_until'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
