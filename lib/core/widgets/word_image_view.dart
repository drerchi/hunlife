import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/content_providers.dart';

/// Shows a picture for a word, with the credit its Creative Commons licence
/// requires. Renders nothing at all when no suitable image exists — an
/// irrelevant picture is worse for learning than none.
class WordImageView extends ConsumerWidget {
  const WordImageView({
    super.key,
    required this.wordHu,
    this.ukrainian,
    this.size = 160,
  });

  final String wordHu;
  final String? ukrainian;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(wordImageProvider((word: wordHu, ukrainian: ukrainian)));

    return image.when(
      loading: () => SizedBox(
        height: size,
        width: size,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
      error: (_, __) => _FallbackTile(word: wordHu, size: size),
      data: (picture) {
        // CC0/public-domain images carry no attribution requirement, so the
        // picture stands on its own. Words with no photo get a letter tile
        // rather than an empty gap.
        if (picture == null) return _FallbackTile(word: wordHu, size: size);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                picture.displayUrl,
                height: size,
                width: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _FallbackTile(word: wordHu, size: size),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    height: size,
                    width: size,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shown when a word has no suitable photo — an initial on a tinted tile,
/// so cards keep a consistent shape instead of jumping around.
class _FallbackTile extends StatelessWidget {
  const _FallbackTile({required this.word, required this.size});

  final String word;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter = word.trim().isEmpty ? '?' : word.trim()[0].toUpperCase();

    // Stable per word, so the same word always gets the same colour.
    final palette = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
    final background = palette[word.hashCode.abs() % palette.length];

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w300,
          color: scheme.onSecondaryContainer.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
