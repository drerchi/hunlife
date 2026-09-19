import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Hungarian flag red/green as brand accents, kept subtle.
  static const Color hungarianRed = Color(0xFFCE2939);
  static const Color hungarianGreen = Color(0xFF477050);
  static const Color seed = Color(0xFF2E5EAA);

  /// Accents used to tell the app's sections apart at a glance. A single blue
  /// everywhere made every card look the same.
  // Muted rather than vivid: a full-strength amber/red banner glared against
  // the dark theme and pulled attention away from the content below it.
  static const Color flameStart = Color(0xFFC98A3C); // warm ochre
  static const Color flameEnd = Color(0xFF9E4436); // deep terracotta
  static const Color progressGreen = Color(0xFF2E9E5B);
  static const Color vocabularyPurple = Color(0xFF7B4FBF);
  static const Color videoRed = Color(0xFFD93025);
  static const Color citizenshipGreen = Color(0xFF1E8E3E);
  static const Color learnBlue = Color(0xFF1A73E8);

  /// Warm flame gradient for streak-style highlights.
  static const LinearGradient flameGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [flameStart, flameEnd],
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: _navigationBarTheme(scheme),
    );
  }

  /// Five destinations leave roughly a fifth of a phone's width each, so the
  /// default label size clips the longer Ukrainian words. A slightly smaller
  /// label keeps every tab readable without truncation.
  static NavigationBarThemeData _navigationBarTheme(ColorScheme scheme) {
    return NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: _navigationBarTheme(scheme),
    );
  }
}
