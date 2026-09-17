import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/profile.dart';
import '../../providers/service_providers.dart';

/// Shown instead of the app content when the signed-in user's profile is
/// blocked or their access window has expired. They can still see this
/// status page and sign out, but not reach lessons/flashcards.
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = profile.accessStatus == AccessStatus.blocked;
    final title = isBlocked ? 'Доступ заблоковано' : 'Термін доступу закінчився';
    final message = isBlocked
        ? 'Ваш акаунт було заблоковано адміністратором. Зверніться до підтримки, щоб відновити доступ.'
        : 'Ваш доступ до уроків закінчився ${profile.accessUntil != null ? DateFormat('dd.MM.yyyy').format(profile.accessUntil!.toLocal()) : ''}. Зверніться до адміністратора, щоб продовжити.';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock_outlined, size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text(profile.email, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Вийти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
