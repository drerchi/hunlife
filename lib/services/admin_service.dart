import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int blockedUsers;
  final int expiredUsers;
  final int adminUsers;

  const AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.blockedUsers,
    required this.expiredUsers,
    required this.adminUsers,
  });
}

/// Admin-only operations on user profiles. All of these rely on the
/// "profiles_update_own_or_admin" RLS policy, which only allows writes when
/// the caller's own profile has role = 'admin'.
class AdminService {
  AdminService(this._client);

  final SupabaseClient _client;

  Future<List<Profile>> fetchAllProfiles({String? searchQuery}) async {
    var query = _client.from('profiles').select();
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      query = query.or('email.ilike.%$q%,full_name.ilike.%$q%');
    }
    final rows = await query.order('created_at', ascending: false);
    return rows.map((e) => Profile.fromJson(e)).toList();
  }

  Future<AdminStats> fetchStats() async {
    final profiles = await fetchAllProfiles();
    int active = 0, blocked = 0, expired = 0, admins = 0;
    for (final p in profiles) {
      if (p.isAdmin) admins++;
      switch (p.accessStatus) {
        case AccessStatus.active:
          active++;
          break;
        case AccessStatus.blocked:
          blocked++;
          break;
        case AccessStatus.expired:
          expired++;
          break;
      }
    }
    return AdminStats(
      totalUsers: profiles.length,
      activeUsers: active,
      blockedUsers: blocked,
      expiredUsers: expired,
      adminUsers: admins,
    );
  }

  Future<void> setBlocked({required String userId, required bool isBlocked}) async {
    await _client.from('profiles').update({'is_blocked': isBlocked}).eq('id', userId);
  }

  /// [accessUntil] = null means unlimited access.
  Future<void> setAccessUntil({required String userId, required DateTime? accessUntil}) async {
    await _client
        .from('profiles')
        .update({'access_until': accessUntil?.toIso8601String()}).eq('id', userId);
  }

  Future<void> setRole({required String userId, required String role}) async {
    await _client.from('profiles').update({'role': role}).eq('id', userId);
  }

  /// Creates a learner account directly, with access already granted.
  ///
  /// Goes through an edge function because creating a user needs the
  /// service_role key, which must never be shipped in the app. The function
  /// re-checks that the caller is an admin before doing anything.
  Future<void> createUser({
    required String email,
    required String password,
    String? fullName,
    DateTime? accessUntil,
  }) async {
    final response = await _client.functions.invoke('admin-create-user', body: {
      'email': email.trim(),
      'password': password,
      if (fullName != null && fullName.trim().isNotEmpty) 'fullName': fullName.trim(),
      'accessUntil': accessUntil?.toIso8601String(),
    });

    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}
