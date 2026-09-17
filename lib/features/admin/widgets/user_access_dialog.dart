import 'package:flutter/material.dart';

import '../../../models/profile.dart';

class UserAccessResult {
  final bool isBlocked;
  final DateTime? accessUntil;
  final bool unlimited;

  const UserAccessResult({required this.isBlocked, required this.accessUntil, required this.unlimited});
}

/// Lets an admin block/unblock a user and set their access window: a
/// specific end date, or unlimited access.
Future<UserAccessResult?> showUserAccessDialog(BuildContext context, Profile profile) {
  return showDialog<UserAccessResult>(
    context: context,
    builder: (context) => _UserAccessDialog(profile: profile),
  );
}

class _UserAccessDialog extends StatefulWidget {
  const _UserAccessDialog({required this.profile});

  final Profile profile;

  @override
  State<_UserAccessDialog> createState() => _UserAccessDialogState();
}

class _UserAccessDialogState extends State<_UserAccessDialog> {
  late bool _isBlocked = widget.profile.isBlocked;
  late bool _unlimited = widget.profile.accessUntil == null;
  late DateTime? _accessUntil = widget.profile.accessUntil;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _accessUntil ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _accessUntil = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.profile.fullName ?? widget.profile.email),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.profile.email, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Заблокувати доступ'),
              subtitle: const Text('Користувач не зможе відкривати уроки/картки'),
              value: _isBlocked,
              onChanged: (v) => setState(() => _isBlocked = v),
            ),
            const Divider(),
            RadioGroup<bool>(
              groupValue: _unlimited,
              onChanged: (v) => setState(() => _unlimited = v ?? _unlimited),
              child: const Column(
                children: [
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Необмежений доступ'),
                    value: true,
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Доступ до конкретної дати'),
                    value: false,
                  ),
                ],
              ),
            ),
            if (!_unlimited)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_accessUntil == null
                      ? 'Обрати дату'
                      : '${_accessUntil!.day.toString().padLeft(2, '0')}.${_accessUntil!.month.toString().padLeft(2, '0')}.${_accessUntil!.year}'),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Скасувати')),
        FilledButton(
          onPressed: (!_unlimited && _accessUntil == null)
              ? null
              : () => Navigator.of(context).pop(
                    UserAccessResult(
                      isBlocked: _isBlocked,
                      accessUntil: _unlimited ? null : _accessUntil,
                      unlimited: _unlimited,
                    ),
                  ),
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}
