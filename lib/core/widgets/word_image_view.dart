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
      error: (_, __) => const SizedBox.shrink(),
      data: (picture) {
        if (picture == null) return const SizedBox.shrink();

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
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
            if (picture.creditLine != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  picture.creditLine!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 10,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );
      },
    );
  }
}
