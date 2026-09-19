import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/util/hungarian_date.dart';
import '../../providers/service_providers.dart';
import '../../providers/session_provider.dart';

/// Collects the details the citizenship interview asks about, so practice
/// answers use the learner's own name and date of birth instead of an example.
class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  ConsumerState<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends ConsumerState<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _birthPlace = TextEditingController();
  final _motherName = TextEditingController();
  final _fatherName = TextEditingController();
  final _residence = TextEditingController();
  DateTime? _dateOfBirth;
  DateTime? _motherDateOfBirth;

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _birthPlace.dispose();
    _motherName.dispose();
    _fatherName.dispose();
    _residence.dispose();
    super.dispose();
  }

  void _loadFrom(profile) {
    if (_loaded || profile == null) return;
    _loaded = true;
    _firstName.text = profile.firstName ?? '';
    _lastName.text = profile.lastName ?? '';
    _birthPlace.text = profile.birthPlace ?? '';
    _motherName.text = profile.motherName ?? '';
    _fatherName.text = profile.fatherName ?? '';
    _residence.text = profile.residence ?? '';
    _dateOfBirth = profile.dateOfBirth;
    _motherDateOfBirth = profile.motherDateOfBirth;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Оберіть дату народження',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(sessionProvider).valueOrNull?.profile;
    if (profile == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(profileServiceProvider).updatePersonalDetails(
            userId: profile.id,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            dateOfBirth: _dateOfBirth,
            birthPlace: _birthPlace.text.trim().isEmpty ? null : _birthPlace.text.trim(),
            motherName: _motherName.text.trim().isEmpty ? null : _motherName.text.trim(),
            fatherName: _fatherName.text.trim().isEmpty ? null : _fatherName.text.trim(),
            residence: _residence.text.trim().isEmpty ? null : _residence.text.trim(),
            motherDateOfBirth: _motherDateOfBirth,
          );
      ref.invalidate(sessionProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дані збережено. Відповіді оновлено.')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося зберегти: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider).valueOrNull?.profile;
    _loadFrom(profile);

    return Scaffold(
      appBar: AppBar(title: const Text('Мої дані для співбесіди')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Ці дані підставляються у відповіді на співбесіді, '
                        'щоб ви тренувалися саме зі своїм іменем і датою народження.\n\n'
                        'Пишіть ім\'я латиницею — так, як його вимовляють угорською.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(
                      labelText: 'Прізвище (латиницею)',
                      hintText: 'Kovács',
                      helperText: 'В угорській прізвище стоїть першим',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(
                      labelText: 'Ім\'я (латиницею)',
                      hintText: 'Péter',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
                  ),
                  const SizedBox(height: 20),
                  Text('Дата народження', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _dateOfBirth == null
                          ? 'Обрати дату'
                          : DateFormat('dd.MM.yyyy').format(_dateOfBirth!),
                    ),
                  ),
                  if (_dateOfBirth != null) ...[
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Як це звучить угорською:',
                                style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 4),
                            Text(
                              HungarianDate.spell(_dateOfBirth!),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _birthPlace,
                    decoration: const InputDecoration(
                      labelText: 'Місце народження (необов\'язково)',
                      hintText: 'Ungváron',
                      helperText: 'Так, як скажете в реченні: «... Ungváron születtem»',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _motherName,
                    decoration: const InputDecoration(
                      labelText: 'Дівоче прізвище матері (необов\'язково)',
                      hintText: 'Szabó Mária',
                      helperText: 'Латиницею — про це питають на співбесіді',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fatherName,
                    decoration: const InputDecoration(
                      labelText: 'Ім\'я батька (необов\'язково)',
                      hintText: 'Kovács István',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _motherDateOfBirth ?? DateTime(1970, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        helpText: 'Дата народження матері',
                      );
                      if (picked != null) setState(() => _motherDateOfBirth = picked);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_motherDateOfBirth == null
                        ? 'Дата народження матері (необов\'язково)'
                        : 'Мати: ${DateFormat('dd.MM.yyyy').format(_motherDateOfBirth!)}'),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _residence,
                    decoration: const InputDecoration(
                      labelText: 'Де ви живете зараз',
                      hintText: 'Budapesten',
                      helperText: 'Так, як скажете в реченні: «Jelenleg ... lakom»',
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Збереження...' : 'Зберегти'),
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
