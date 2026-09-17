import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/video.dart';
import '../../../providers/service_providers.dart';
import '../../../services/transcript_parser.dart';

Future<bool?> showTranscriptImportDialog(BuildContext context, Video video) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _TranscriptImportDialog(video: video),
  );
}

class _TranscriptImportDialog extends ConsumerStatefulWidget {
  const _TranscriptImportDialog({required this.video});

  final Video video;

  @override
  ConsumerState<_TranscriptImportDialog> createState() => _TranscriptImportDialogState();
}

class _TranscriptImportDialogState extends ConsumerState<_TranscriptImportDialog> {
  final _controller = TextEditingController();
  List<TranscriptCue> _preview = [];
  bool _saving = false;
  bool _fetching = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final existing = await ref.read(videoServiceProvider).fetchCachedTranscript(widget.video.id);
    if (existing != null && existing.isNotEmpty && mounted) {
      setState(() {
        _preview = existing;
        _controller.text = existing
            .map((c) => '${_fmt(c.start)}\n${c.text}')
            .join('\n');
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _fmt(double seconds) {
    final d = Duration(seconds: seconds.floor());
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void _parse() {
    setState(() {
      _preview = TranscriptParser.parse(_controller.text);
      _message = _preview.isEmpty ? 'Не вдалося розпізнати субтитри.' : null;
    });
  }

  /// Load an .srt/.vtt/.txt subtitle file straight from disk.
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['srt', 'vtt', 'txt', 'sbv'],
        withData: true, // needed on web, where there is no file path
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _message = 'Не вдалося прочитати файл.');
        return;
      }

      // Subtitle files are usually UTF-8; fall back to Latin-1 so a
      // mis-encoded file still loads instead of throwing.
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }

      _controller.text = text;
      _parse();
      if (!mounted) return;
      setState(() {
        _message = _preview.isEmpty
            ? 'Файл "${file.name}" завантажено, але субтитри не розпізнано.'
            : 'Файл "${file.name}": розпізнано ${_preview.length} рядків.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Помилка читання файлу: $e');
    }
  }

  Future<void> _tryAutoFetch() async {
    setState(() {
      _fetching = true;
      _message = null;
    });
    try {
      final cues = await ref.read(videoServiceProvider).fetchTranscriptFromYoutube(
            youtubeId: widget.video.youtubeId,
            videoId: widget.video.id,
          );
      if (!mounted) return;
      setState(() {
        _preview = cues;
        _controller.text = cues.map((c) => '${_fmt(c.start)}\n${c.text}').join('\n');
        _fetching = false;
        _message = 'Завантажено автоматично: ${cues.length} рядків.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _message = 'Автозавантаження не вдалося (YouTube блокує запити з сервера). '
            'Вставте субтитри вручну нижче.';
      });
    }
  }

  Future<void> _save() async {
    if (_preview.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(videoServiceProvider)
          .saveTranscript(videoId: widget.video.id, cues: _preview);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Не вдалося зберегти: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Субтитри: ${widget.video.titleUk}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Як отримати субтитри:\n'
                    '1. Відкрийте відео на YouTube → «...» → «Показати текст відео».\n'
                    '2. Виділіть і скопіюйте весь текст разом із часом.\n'
                    '3. Вставте сюди. Формати .srt і .vtt теж підтримуються.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _fetching ? null : _tryAutoFetch,
                    icon: _fetching
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_download_outlined),
                    label: const Text('Спробувати автоматично'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Завантажити файл'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _parse,
                    icon: const Icon(Icons.check),
                    label: const Text('Перевірити текст'),
                  ),
                ],
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: 12,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Текст субтитрів',
                  alignLabelWithHint: true,
                  hintText: '0:05\nSziasztok, hogy vagytok?\n0:09\nMa a családról beszélünk.',
                ),
                onChanged: (_) => _parse(),
              ),
              const SizedBox(height: 12),
              if (_preview.isNotEmpty) ...[
                Text('Розпізнано рядків: ${_preview.length}',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _preview
                        .take(20)
                        .map((c) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: Text('${_fmt(c.start)}  ${c.text}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Скасувати')),
        FilledButton(
          onPressed: (_preview.isEmpty || _saving) ? null : _save,
          child: Text(_saving ? 'Збереження...' : 'Зберегти субтитри'),
        ),
      ],
    );
  }
}
