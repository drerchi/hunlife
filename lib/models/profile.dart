enum AccessStatus { active, blocked, expired }

class Profile {
  final String id;
  final String email;
  final String? fullName;
  final String role;
  final bool isBlocked;
  final DateTime? accessUntil;
  final DateTime createdAt;

  /// Details the learner gives at the citizenship interview. Kept in Latin
  /// script so the Hungarian answers stay pronounceable.
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? birthPlace;
  final String? motherName;
  final String? fatherName;

  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isBlocked,
    required this.accessUntil,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.birthPlace,
    this.motherName,
    this.fatherName,
  });

  /// Hungarian puts the family name first: "Kovács Péter".
  String? get hungarianName {
    final parts = [lastName, firstName].where((p) => p != null && p.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// Whether there's enough detail to personalise the interview answers.
  bool get hasInterviewDetails =>
      (firstName?.trim().isNotEmpty ?? false) &&
      (lastName?.trim().isNotEmpty ?? false) &&
      dateOfBirth != null;

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
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.parse(json['date_of_birth'] as String),
      birthPlace: json['birth_place'] as String?,
      motherName: json['mother_name'] as String?,
      fatherName: json['father_name'] as String?,
    );
  }
}
