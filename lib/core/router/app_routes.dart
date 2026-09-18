class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const blocked = '/blocked';

  static const home = '/';
  static const topics = '/topics';
  static const videos = '/videos';
  static const citizenship = '/citizenship';
  static const account = '/account';

  static const admin = '/admin';
  static const vocabulary = '/vocabulary';
  static const vocabularyStudy = '/vocabulary/study';
  static const personalDetails = '/personal-details';

  static String topicDetail(String topicId) => '/topics/$topicId';
  static String topicFlashcards(String topicId) => '/topics/$topicId/flashcards';
  static String lessonDetail(String lessonId) => '/lessons/$lessonId';
  static String videoDetail(String videoId) => '/videos/$videoId';
}
