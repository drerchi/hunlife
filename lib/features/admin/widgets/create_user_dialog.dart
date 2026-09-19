import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/service_providers.dart';

/// Lets an admin add a learner directly, with their access period already set,
/// instead of waiting for them to register and then granting access.
Future<bool?> showCreateUserDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _CreateUserDialog(),
  );
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog();

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();

  DateTime? _accessUntil;
  bool _unlimited = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _accessUntil ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      helpText: 'Доступ діє до',
    );
    if (picked != null) setState(() => _accessUntil = picked);
  }

  /// Offers a few common periods so the usual case is one tap.
  void _setMonths(int months) {
    final now = DateTime.now();
    setState(() {
      _unlimited = false;
      _accessUntil = DateTime(now.year, now.month + months, now.day);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_unlimited && _accessUntil == null) {
      setState(() => _error = 'Оберіть дату або необмежений доступ.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(adminServiceProvider).createUser(
            email: _email.text,
            password: _password.text,
            fullName: _fullName.text,
            accessUntil: _unlimited ? null : _accessUntil,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Створити користувача'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Введіть коректний email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    helperText: 'Передайте його користувачеві — він зможе змінити пароль',
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Мінімум 6 символів' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(labelText: 'Ім\'я (необов\'язково)'),
                ),
                const SizedBox(height: 20),
                Text('Доступ', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(label: const Text('1 місяць'), onPressed: () => _setMonths(1)),
                    ActionChip(label: const Text('3 місяці'), onPressed: () => _setMonths(3)),
                    ActionChip(label: const Text('6 місяців'), onPressed: () => _setMonths(6)),
                    ActionChip(label: const Text('1 рік'), onPressed: () => _setMonths(12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _unlimited
                            ? 'Необмежений'
                            : _accessUntil == null
                                ? 'Обрати дату'
                                : DateFormat('dd.MM.yyyy').format(_accessUntil!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Без обмежень'),
                      selected: _unlimited,
                      onSelected: (v) => setState(() {
                        _unlimited = v;
                        if (v) _accessUntil = null;
                      }),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Створення...' : 'Створити'),
        ),
      ],
    );
  }
}
