import 'package:flutter/material.dart';

import '../../../models/flashcard.dart';
import '../../../models/topic.dart';

Future<Flashcard?> showFlashcardFormDialog(
  BuildContext context, {
  required List<Topic> topics,
  required String defaultTopicId,
  Flashcard? existing,
}) {
  return showDialog<Flashcard>(
    context: context,
    builder: (context) => _FlashcardFormDialog(topics: topics, defaultTopicId: defaultTopicId, existing: existing),
  );
}

class _FlashcardFormDialog extends StatefulWidget {
  const _FlashcardFormDialog({required this.topics, required this.defaultTopicId, this.existing});

  final List<Topic> topics;
  final String defaultTopicId;
  final Flashcard? existing;

  @override
  State<_FlashcardFormDialog> createState() => _FlashcardFormDialogState();
}

class _FlashcardFormDialogState extends State<_FlashcardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _topicId = widget.existing?.topicId ?? widget.defaultTopicId;
  late final _frontHu = TextEditingController(text: widget.existing?.frontHu ?? '');
  late final _backUk = TextEditingController(text: widget.existing?.backUk ?? '');
  late final _exampleHu = TextEditingController(text: widget.existing?.exampleHu ?? '');
  late final _exampleUk = TextEditingController(text: widget.existing?.exampleUk ?? '');
  late final _order = TextEditingController(text: (widget.existing?.orderIndex ?? 0).toString());

  @override
  void dispose() {
    _frontHu.dispose();
    _backUk.dispose();
    _exampleHu.dispose();
    _exampleUk.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Нова картка' : 'Редагувати картку'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: widget.topics.any((t) => t.id == _topicId) ? _topicId : null,
                  decoration: const InputDecoration(labelText: 'Тема'),
                  items: widget.topics
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.titleUk)))
                      .toList(),
                  onChanged: (v) => setState(() => _topicId = v ?? _topicId),
                  validator: (v) => (v == null || v.isEmpty) ? 'Оберіть тему' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _frontHu,
                  decoration: const InputDecoration(labelText: 'Слово/фраза угорською'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _backUk,
                  decoration: const InputDecoration(labelText: 'Переклад українською'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _exampleHu,
                  decoration: const InputDecoration(labelText: 'Приклад угорською (необов\'язково)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _exampleUk,
                  decoration: const InputDecoration(labelText: 'Приклад українською (необов\'язково)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _order,
                  decoration: const InputDecoration(labelText: 'Порядок (число)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Скасувати')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(Flashcard(
              id: widget.existing?.id ?? '',
              topicId: _topicId,
              lessonId: widget.existing?.lessonId,
              frontHu: _frontHu.text.trim(),
              backUk: _backUk.text.trim(),
              exampleHu: _exampleHu.text.trim().isEmpty ? null : _exampleHu.text.trim(),
              exampleUk: _exampleUk.text.trim().isEmpty ? null : _exampleUk.text.trim(),
              orderIndex: int.tryParse(_order.text.trim()) ?? 0,
            ));
          },
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}
