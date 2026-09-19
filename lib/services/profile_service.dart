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

  /// The details the learner gives at the citizenship interview, which the
  /// app substitutes into the practice answers.
  Future<void> updatePersonalDetails({
    required String userId,
    required String firstName,
    required String lastName,
    DateTime? dateOfBirth,
    String? birthPlace,
    String? motherName,
    String? fatherName,
    String? residence,
    int? inHungarySince,
    DateTime? motherDateOfBirth,
  }) async {
    await _client.from('profiles').update({
      'first_name': firstName,
      'last_name': lastName,
      'full_name': '$lastName $firstName'.trim(),
      // A date column wants a plain date, not a full timestamp.
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'birth_place': birthPlace,
      'mother_name': motherName,
      'father_name': fatherName,
      'residence': residence,
      'in_hungary_since': inHungarySince,
      'mother_date_of_birth': motherDateOfBirth?.toIso8601String().split('T').first,
    }).eq('id', userId);
  }
}
