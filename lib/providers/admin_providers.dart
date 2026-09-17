import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../services/admin_service.dart';
import 'service_providers.dart';

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  return ref.watch(adminServiceProvider).fetchStats();
});

final adminUserSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final adminUsersProvider = FutureProvider.autoDispose<List<Profile>>((ref) async {
  final query = ref.watch(adminUserSearchProvider);
  return ref.watch(adminServiceProvider).fetchAllProfiles(searchQuery: query);
});
