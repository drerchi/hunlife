import 'package:flutter/material.dart';

/// Shown when the app was launched without Supabase --dart-define values,
/// so a blank/crashing app never ships silently.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_outlined, size: 56, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text('Потрібне налаштування Supabase', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  const Text(
                    'Запустіть застосунок з SUPABASE_URL і SUPABASE_ANON_KEY, наприклад:\n\n'
                    'flutter run -d chrome --dart-define-from-file=env.json\n\n'
                    'Файл env.json (у корені проєкту, не в git) має містити:\n'
                    '{"SUPABASE_URL": "...", "SUPABASE_ANON_KEY": "..."}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
