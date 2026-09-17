import 'package:flutter/material.dart';

import '../../../models/lesson.dart';
import '../../../models/topic.dart';

Future<Lesson?> showLessonFormDialog(
  BuildContext context, {
  required List<Topic> topics,
  required String defaultTopicId,
  Lesson? existing,
}) {
  return showDialog<Lesson>(
    context: context,
    builder: (context) => _LessonFormDialog(topics: topics, defaultTopicId: defaultTopicId, existing: existing),
  );
}

class _LessonFormDialog extends StatefulWidget {
  const _LessonFormDialog({required this.topics, required this.defaultTopicId, this.existing});

  final List<Topic> topics;
  final String defaultTopicId;
  final Lesson? existing;

  @override
  State<_LessonFormDialog> createState() => _LessonFormDialogState();
}

class _LessonFormDialogState extends State<_LessonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _topicId = widget.existing?.topicId ?? widget.defaultTopicId;
  late final _titleUk = TextEditingController(text: widget.existing?.titleUk ?? '');
  late final _titleHu = TextEditingController(text: widget.existing?.titleHu ?? '');
  late final _content = TextEditingController(text: widget.existing?.contentUk ?? '');
  late final _order = TextEditingController(text: (widget.existing?.orderIndex ?? 0).toString());

  @override
  void dispose() {
    _titleUk.dispose();
    _titleHu.dispose();
    _content.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Новий урок' : 'Редагувати урок'),
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
                  controller: _titleUk,
                  decoration: const InputDecoration(labelText: 'Назва уроку (українською)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleHu,
                  decoration: const InputDecoration(labelText: 'Назва уроку (угорською)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _content,
                  decoration: const InputDecoration(
                    labelText: 'Зміст уроку',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
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
            Navigator.of(context).pop(Lesson(
              id: widget.existing?.id ?? '',
              topicId: _topicId,
              titleUk: _titleUk.text.trim(),
              titleHu: _titleHu.text.trim().isEmpty ? null : _titleHu.text.trim(),
              contentUk: _content.text.trim(),
              orderIndex: int.tryParse(_order.text.trim()) ?? 0,
            ));
          },
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}
