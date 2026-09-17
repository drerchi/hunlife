import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/video.dart';
import '../../../providers/service_providers.dart';

Future<Video?> showVideoFormDialog(BuildContext context, {Video? existing}) {
  return showDialog<Video>(
    context: context,
    builder: (context) => _VideoFormDialog(existing: existing),
  );
}

/// Accepts a full YouTube URL or a bare id and stores just the id.
String? extractYoutubeId(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;

  // Bare 11-character id.
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value)) return value;

  final patterns = [
    RegExp(r'[?&]v=([A-Za-z0-9_-]{11})'),
    RegExp(r'youtu\.be/([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/shorts/([A-Za-z0-9_-]{11})'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(value);
    if (m != null) return m.group(1);
  }
  return null;
}

class _VideoFormDialog extends ConsumerStatefulWidget {
  const _VideoFormDialog({this.existing});

  final Video? existing;

  @override
  ConsumerState<_VideoFormDialog> createState() => _VideoFormDialogState();
}

class _VideoFormDialogState extends ConsumerState<_VideoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _lookingUp = false;
  String? _lookupNote;
  late final _youtube = TextEditingController(text: widget.existing?.youtubeId ?? '');
  late final _titleUk = TextEditingController(text: widget.existing?.titleUk ?? '');
  late final _titleHu = TextEditingController(text: widget.existing?.titleHu ?? '');
  late final _description = TextEditingController(text: widget.existing?.descriptionUk ?? '');
  late final _level = TextEditingController(text: widget.existing?.level ?? '');
  late final _order = TextEditingController(text: (widget.existing?.orderIndex ?? 0).toString());

  String? _lastLookedUpId;

  /// Fills the title automatically as soon as a valid link is pasted, so
  /// adding a video is just paste-and-save.
  void _autoLookup() {
    final id = extractYoutubeId(_youtube.text);
    if (id == null || id == _lastLookedUpId) return;
    _lastLookedUpId = id;
    if (_titleUk.text.trim().isEmpty) _lookupTitle();
  }

  Future<void> _lookupTitle() async {
    final id = extractYoutubeId(_youtube.text);
    if (id == null) {
      setState(() => _lookupNote = 'Спочатку вставте коректне посилання.');
      return;
    }

    setState(() {
      _lookingUp = true;
      _lookupNote = null;
    });

    final title = await ref.read(videoServiceProvider).fetchYoutubeTitle(id);
    if (!mounted) return;

    setState(() {
      _lookingUp = false;
      if (title == null || title.isEmpty) {
        _lookupNote = 'Не вдалося отримати назву — введіть її вручну.';
      } else {
        if (_titleHu.text.trim().isEmpty) _titleHu.text = title;
        if (_titleUk.text.trim().isEmpty) _titleUk.text = title;
        _lookupNote = 'Назву отримано з YouTube.';
      }
    });
  }

  @override
  void dispose() {
    _youtube.dispose();
    _titleUk.dispose();
    _titleHu.dispose();
    _description.dispose();
    _level.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Нове відео' : 'Редагувати відео'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _youtube,
                  decoration: InputDecoration(
                    labelText: 'Посилання на YouTube або ID',
                    hintText: 'https://www.youtube.com/watch?v=...',
                    helperText: 'Вставте будь-яке відео — серіал, мультфільм, урок',
                    suffixIcon: _lookingUp
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download_outlined),
                            tooltip: 'Отримати назву з YouTube',
                            onPressed: _lookupTitle,
                          ),
                  ),
                  onChanged: (_) => _autoLookup(),
                  validator: (v) =>
                      extractYoutubeId(v ?? '') == null ? 'Некоректне посилання YouTube' : null,
                ),
                if (_lookupNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_lookupNote!, style: Theme.of(context).textTheme.bodySmall),
                  ),
                const SizedBox(height: 12),
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
                  controller: _level,
                  decoration: const InputDecoration(labelText: 'Рівень (A1, A2, B1...)'),
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
            Navigator.of(context).pop(Video(
              id: widget.existing?.id ?? '',
              youtubeId: extractYoutubeId(_youtube.text)!,
              titleUk: _titleUk.text.trim(),
              titleHu: _titleHu.text.trim().isEmpty ? null : _titleHu.text.trim(),
              descriptionUk: _description.text.trim().isEmpty ? null : _description.text.trim(),
              level: _level.text.trim().isEmpty ? null : _level.text.trim(),
              orderIndex: int.tryParse(_order.text.trim()) ?? 0,
            ));
          },
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}
