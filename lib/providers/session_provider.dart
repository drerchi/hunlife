import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import 'service_providers.dart';

class SessionState {
  final bool isAuthenticated;
  final Profile? profile;

  const SessionState.unauthenticated()
      : isAuthenticated = false,
        profile = null;

  const SessionState.authenticated(Profile this.profile) : isAuthenticated = true;
}

/// The app's derived session: for every Supabase auth event (sign in, sign
/// out, initial session on app start, token refresh) this re-fetches the
/// matching profile row so the app knows both "who is logged in" and
/// "are they allowed in" (role, blocked flag, access window).
///
/// supabase_flutter emits an initial event synchronously on first listen, so
/// this correctly reflects the already-logged-in state on app startup too.
final sessionProvider = StreamProvider<SessionState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final profileService = ref.watch(profileServiceProvider);

  return authService.onAuthStateChange.asyncMap((event) async {
    final user = event.session?.user ?? authService.currentUser;
    if (user == null) return const SessionState.unauthenticated();
    final profile = await profileService.fetchProfile(user.id);
    return SessionState.authenticated(profile);
  });
});
