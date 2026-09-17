import 'package:flutter/material.dart';

import '../../../models/citizenship_question.dart';

Future<CitizenshipQuestion?> showCitizenshipFormDialog(BuildContext context,
    {CitizenshipQuestion? existing}) {
  return showDialog<CitizenshipQuestion>(
    context: context,
    builder: (context) => _CitizenshipFormDialog(existing: existing),
  );
}

class _CitizenshipFormDialog extends StatefulWidget {
  const _CitizenshipFormDialog({this.existing});

  final CitizenshipQuestion? existing;

  @override
  State<_CitizenshipFormDialog> createState() => _CitizenshipFormDialogState();
}

class _CitizenshipFormDialogState extends State<_CitizenshipFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _category = TextEditingController(text: widget.existing?.category ?? 'Загальне');
  late final _questionHu = TextEditingController(text: widget.existing?.questionHu ?? '');
  late final _questionUk = TextEditingController(text: widget.existing?.questionUk ?? '');
  late final _answerHu = TextEditingController(text: widget.existing?.answerHu ?? '');
  late final _answerUk = TextEditingController(text: widget.existing?.answerUk ?? '');
  late final _order = TextEditingController(text: (widget.existing?.orderIndex ?? 0).toString());

  @override
  void dispose() {
    _category.dispose();
    _questionHu.dispose();
    _questionUk.dispose();
    _answerHu.dispose();
    _answerUk.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Нове питання' : 'Редагувати питання'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Категорія'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _questionHu,
                  decoration: const InputDecoration(labelText: 'Питання угорською'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _questionUk,
                  decoration: const InputDecoration(labelText: 'Питання українською'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _answerHu,
                  decoration: const InputDecoration(labelText: 'Відповідь угорською'),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обов\'язкове поле' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _answerUk,
                  decoration: const InputDecoration(labelText: 'Відповідь українською'),
                  maxLines: 3,
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
            Navigator.of(context).pop(CitizenshipQuestion(
              id: widget.existing?.id ?? '',
              category: _category.text.trim(),
              questionHu: _questionHu.text.trim(),
              questionUk: _questionUk.text.trim(),
              answerHu: _answerHu.text.trim(),
              answerUk: _answerUk.text.trim(),
              orderIndex: int.tryParse(_order.text.trim()) ?? 0,
            ));
          },
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}
