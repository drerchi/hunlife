import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_view.dart';
import '../../../models/profile.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/session_provider.dart';
import '../widgets/user_access_dialog.dart';

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    final myId = ref.watch(sessionProvider).valueOrNull?.profile?.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Пошук за email або іменем...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => ref.read(adminUserSearchProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminUsersProvider),
            child: AsyncView(
              value: users,
              onRetry: () => ref.invalidate(adminUsersProvider),
              data: (context, list) {
                if (list.isEmpty) {
                  return const EmptyState(message: 'Користувачів не знайдено.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = list[index];
                    return _UserTile(user: user, isSelf: user.id == myId);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user, required this.isSelf});

  final Profile user;
  final bool isSelf;

  Color _statusColor(BuildContext context) {
    switch (user.accessStatus) {
      case AccessStatus.active:
        return Colors.green;
      case AccessStatus.blocked:
        return Colors.redAccent;
      case AccessStatus.expired:
        return Colors.orange;
    }
  }

  String _statusText() {
    switch (user.accessStatus) {
      case AccessStatus.active:
        return user.accessUntil == null
            ? 'Активний · необмежено'
            : 'Активний до ${DateFormat('dd.MM.yyyy').format(user.accessUntil!.toLocal())}';
      case AccessStatus.blocked:
        return 'Заблоковано';
      case AccessStatus.expired:
        return 'Термін минув ${DateFormat('dd.MM.yyyy').format(user.accessUntil!.toLocal())}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text((user.fullName?.isNotEmpty == true ? user.fullName![0] : user.email[0]).toUpperCase()),
        ),
        title: Text(user.fullName?.isNotEmpty == true ? user.fullName! : user.email),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${user.email}\n'),
              TextSpan(text: _statusText(), style: TextStyle(color: _statusColor(context))),
            ],
          ),
          style: const TextStyle(height: 1.4),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            final admin = ref.read(adminServiceProvider);
            switch (value) {
              case 'access':
                final result = await showUserAccessDialog(context, user);
                if (result == null) return;
                await admin.setBlocked(userId: user.id, isBlocked: result.isBlocked);
                await admin.setAccessUntil(userId: user.id, accessUntil: result.accessUntil);
                ref.invalidate(adminUsersProvider);
                ref.invalidate(adminStatsProvider);
                break;
              case 'make_admin':
                await admin.setRole(userId: user.id, role: 'admin');
                ref.invalidate(adminUsersProvider);
                ref.invalidate(adminStatsProvider);
                break;
              case 'remove_admin':
                await admin.setRole(userId: user.id, role: 'user');
                ref.invalidate(adminUsersProvider);
                ref.invalidate(adminStatsProvider);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'access', child: Text('Керувати доступом')),
            if (!isSelf)
              user.isAdmin
                  ? const PopupMenuItem(value: 'remove_admin', child: Text('Прибрати права адміна'))
                  : const PopupMenuItem(value: 'make_admin', child: Text('Зробити адміном')),
          ],
        ),
      ),
    );
  }
}
