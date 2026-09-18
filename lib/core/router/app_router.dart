import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_screen.dart';
import '../../features/account/personal_details_screen.dart';
import '../../features/admin/admin_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/blocked/blocked_screen.dart';
import '../../features/citizenship/citizenship_screen.dart';
import '../../features/flashcards/flashcard_study_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/lessons/lesson_detail_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/topics/topic_detail_screen.dart';
import '../../features/topics/topics_list_screen.dart';
import '../../features/videos/video_detail_screen.dart';
import '../../features/videos/videos_list_screen.dart';
import '../../features/vocabulary/vocabulary_screen.dart';
import '../../features/vocabulary/vocabulary_study_screen.dart';
import 'package:flutter/foundation.dart';

import '../../providers/session_provider.dart';
import 'app_routes.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  // Bumping this notifies go_router to re-run `redirect` whenever the
  // session (auth state + profile) changes, without go_router needing to
  // know about Riverpod directly.
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refreshNotifier.value++);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final session = ref.read(sessionProvider);

      final publicLocations = {
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      };

      // Auth state not resolved yet (app just started) -> show splash.
      if (session.isLoading || (session.hasError && !session.hasValue)) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final value = session.value ?? const SessionState.unauthenticated();

      if (!value.isAuthenticated) {
        if (publicLocations.contains(location)) return null;
        return AppRoutes.login;
      }

      // Authenticated from here on.
      if (location == AppRoutes.splash || publicLocations.contains(location)) {
        return AppRoutes.home;
      }

      final profile = value.profile!;

      if (location == AppRoutes.admin && !profile.isAdmin) {
        return AppRoutes.home;
      }

      if (!profile.hasActiveAccess && location != AppRoutes.blocked && location != AppRoutes.account) {
        return AppRoutes.blocked;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.blocked,
        builder: (context, state) {
          final session = ref.read(sessionProvider).value;
          return BlockedScreen(profile: session!.profile!);
        },
      ),
      GoRoute(path: AppRoutes.admin, builder: (context, state) => const AdminScreen()),
      GoRoute(
        path: AppRoutes.personalDetails,
        builder: (context, state) => const PersonalDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.vocabulary,
        builder: (context, state) => const VocabularyScreen(),
        routes: [
          GoRoute(path: 'study', builder: (context, state) => const VocabularyStudyScreen()),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.topics,
              builder: (context, state) => const TopicsListScreen(),
              routes: [
                GoRoute(
                  path: ':topicId',
                  builder: (context, state) =>
                      TopicDetailScreen(topicId: state.pathParameters['topicId']!),
                  routes: [
                    GoRoute(
                      path: 'flashcards',
                      builder: (context, state) =>
                          FlashcardStudyScreen(topicId: state.pathParameters['topicId']!),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/lessons/:lessonId',
              builder: (context, state) =>
                  LessonDetailScreen(lessonId: state.pathParameters['lessonId']!),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.videos,
              builder: (context, state) => const VideosListScreen(),
              routes: [
                GoRoute(
                  path: ':videoId',
                  builder: (context, state) =>
                      VideoDetailScreen(videoId: state.pathParameters['videoId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.citizenship, builder: (context, state) => const CitizenshipScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.account, builder: (context, state) => const AccountScreen()),
          ]),
        ],
      ),
    ],
  );
});
