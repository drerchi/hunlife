import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  Future<Profile> fetchProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(row);
  }

  Future<void> updateOwnName({required String userId, required String fullName}) async {
    await _client.from('profiles').update({'full_name': fullName}).eq('id', userId);
  }
}
