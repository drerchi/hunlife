import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../models/profile.dart';
import '../../providers/service_providers.dart';
import '../../providers/session_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final profile = session.valueOrNull?.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Профіль')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                CircleAvatar(
                  radius: 36,
                  child: Text(
                    (profile.fullName?.isNotEmpty == true ? profile.fullName![0] : profile.email[0])
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(profile.fullName ?? profile.email, style: Theme.of(context).textTheme.titleLarge),
                ),
                Center(
                  child: Text(profile.email, style: Theme.of(context).textTheme.bodyMedium),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _statusIcon(profile.accessStatus),
                            const SizedBox(width: 8),
                            Text('Статус доступу', style: Theme.of(context).textTheme.titleSmall),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_statusLabel(profile)),
                        if (profile.role == 'admin') ...[
                          const SizedBox(height: 8),
                          const Chip(label: Text('Адміністратор'), avatar: Icon(Icons.shield, size: 18)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Мої дані для співбесіди'),
                    subtitle: Text(
                      profile.hasInterviewDetails
                          ? '${profile.hungarianName}'
                          : 'Додайте ім\'я та дату народження',
                    ),
                    trailing: profile.hasInterviewDetails
                        ? const Icon(Icons.chevron_right)
                        : Icon(Icons.error_outline,
                            color: Theme.of(context).colorScheme.error),
                    onTap: () => context.push(AppRoutes.personalDetails),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: const Text('Мій словник'),
                    subtitle: const Text('Слова, збережені з відео'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.vocabulary),
                  ),
                ),
                const SizedBox(height: 8),
                if (profile.isAdmin)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Панель адміністратора'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.admin),
                    ),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Вийти'),
                ),
              ],
            ),
    );
  }

  Widget _statusIcon(AccessStatus status) {
    switch (status) {
      case AccessStatus.active:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case AccessStatus.blocked:
        return const Icon(Icons.block, color: Colors.redAccent, size: 20);
      case AccessStatus.expired:
        return const Icon(Icons.timer_off, color: Colors.orange, size: 20);
    }
  }

  String _statusLabel(Profile profile) {
    switch (profile.accessStatus) {
      case AccessStatus.active:
        if (profile.accessUntil == null) return 'Активний · необмежений доступ';
        return 'Активний до ${DateFormat('dd.MM.yyyy').format(profile.accessUntil!.toLocal())}';
      case AccessStatus.blocked:
        return 'Заблоковано адміністратором';
      case AccessStatus.expired:
        return 'Доступ закінчився ${DateFormat('dd.MM.yyyy').format(profile.accessUntil!.toLocal())}';
    }
  }
}
