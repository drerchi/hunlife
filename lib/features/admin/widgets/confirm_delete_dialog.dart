import 'package:flutter/material.dart';

Future<bool> confirmDelete(BuildContext context, String itemLabel) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Видалити?'),
      content: Text('Ви впевнені, що хочете видалити "$itemLabel"? Цю дію не можна скасувати.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Скасувати')),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Видалити'),
        ),
      ],
    ),
  );
  return result ?? false;
}
