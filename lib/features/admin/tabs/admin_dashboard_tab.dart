import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_view.dart';
import '../../../providers/admin_providers.dart';

class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminStatsProvider),
      child: AsyncView(
        value: stats,
        onRetry: () => ref.invalidate(adminStatsProvider),
        data: (context, s) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _StatCard(label: 'Усього користувачів', value: s.totalUsers, icon: Icons.people, color: Colors.blue),
                  _StatCard(label: 'Активні', value: s.activeUsers, icon: Icons.check_circle, color: Colors.green),
                  _StatCard(label: 'Заблоковані', value: s.blockedUsers, icon: Icons.block, color: Colors.redAccent),
                  _StatCard(label: 'Термін минув', value: s.expiredUsers, icon: Icons.timer_off, color: Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Адміністраторів'),
                  trailing: Text('${s.adminUsers}', style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
          ],
        ),
      ),
    );
  }
}
