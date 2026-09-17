import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/service_providers.dart';

/// Normally plays real Hungarian audio from the server. Only if that can't be
/// reached do we fall back to the device voice — and if that voice isn't
/// Hungarian, say so once rather than quietly teaching English pronunciation.
Future<void> _speak(BuildContext context, WidgetRef ref, String text) async {
  final tts = ref.read(ttsServiceProvider);
  await tts.speak(text);

  if (!context.mounted) return;
  if (!tts.usedFallback || tts.hasHungarianVoice || tts.warnedAboutMissingVoice) return;
  tts.warnedAboutMissingVoice = true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 8),
      content: const Text(
        'На цьому пристрої немає угорського голосу, тому вимова буде неточною. '
        'Додайте угорську мову в налаштуваннях системи.',
      ),
      action: SnackBarAction(
        label: 'Зрозуміло',
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}

/// Taps to read [text] aloud in Hungarian using the device's speech engine.
class SpeakButton extends ConsumerWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.size = 22,
    this.tooltip = 'Прослухати вимову',
  });

  final String text;
  final double size;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.volume_up_outlined, size: size),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: () => _speak(context, ref, text),
    );
  }
}

/// Larger, more prominent variant for flashcards and lesson steps.
class SpeakFab extends ConsumerWidget {
  const SpeakFab({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.tonalIcon(
      onPressed: () => _speak(context, ref, text),
      icon: const Icon(Icons.volume_up),
      label: const Text('Прослухати'),
    );
  }
}
