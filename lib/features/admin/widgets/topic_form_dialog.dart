import 'package:flutter/material.dart';

import '../../../models/topic.dart';

Future<Topic?> showTopicFormDialog(BuildContext context, {Topic? existing}) {
  return showDialog<Topic>(
    context: context,
    builder: (context) => _TopicFormDialog(existing: existing),
  );
}

class _TopicFormDialog extends StatefulWidget {
  const _TopicFormDialog({this.existing});

  final Topic? existing;

  @override
  State<_TopicFormDialog> createState() => _TopicFormDialogState();
}

class _TopicFormDialogState extends State<_TopicFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleUk = TextEditingController(text: widget.existing?.titleUk ?? '');
  late final _titleHu = TextEditingController(text: widget.existing?.titleHu ?? '');
  late final _description = TextEditingController(text: widget.existing?.descriptionUk ?? '');
  late final _order =
      TextEditingController(text: (widget.existing?.orderIndex ?? 0).toString());

  @override
  void dispose() {
    _titleUk.dispose();
    _titleHu.dispose();
    _description.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Нова тема' : 'Редагувати тему'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleUk,
                decoration: const InputDecoration(labelText: 'Назва (українською)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleHu,
                decoration: const InputDecoration(labelText: 'Назва (угорською)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Опис (українською)'),
                maxLines: 2,
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
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Скасувати')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(Topic(
              id: widget.existing?.id ?? '',
              titleUk: _titleUk.text.trim(),
              titleHu: _titleHu.text.trim().isEmpty ? null : _titleHu.text.trim(),
              descriptionUk: _description.text.trim().isEmpty ? null : _description.text.trim(),
              icon: widget.existing?.icon,
              orderIndex: int.tryParse(_order.text.trim()) ?? 0,
            ));
          },
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}
