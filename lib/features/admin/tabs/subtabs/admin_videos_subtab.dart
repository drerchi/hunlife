import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_view.dart';
import '../../../../providers/service_providers.dart';
import '../../../../providers/video_providers.dart';
import '../../widgets/confirm_delete_dialog.dart';
import '../../widgets/transcript_import_dialog.dart';
import '../../widgets/video_form_dialog.dart';

class AdminVideosSubtab extends ConsumerWidget {
  const AdminVideosSubtab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(videosProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showVideoFormDialog(context);
          if (created == null) return;
          await ref.read(videoServiceProvider).createVideo(created);
          ref.invalidate(videosProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Відео'),
      ),
      body: AsyncView(
        value: videos,
        onRetry: () => ref.invalidate(videosProvider),
        data: (context, list) {
          if (list.isEmpty) {
            return const EmptyState(message: 'Відео ще немає. Додайте перше.');
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final video = list[index];
              return Card(
                child: ListTile(
                  leading: SizedBox(
                    width: 72,
                    height: 48,
                    child: Image.network(
                      video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.smart_display_outlined),
                    ),
                  ),
                  title: Text(video.titleUk),
                  subtitle: Text([
                    video.youtubeId,
                    if (video.level != null) video.level!,
                  ].join(' · ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.subtitles_outlined),
                        tooltip: 'Субтитри',
                        onPressed: () async {
                          final saved = await showTranscriptImportDialog(context, video);
                          if (saved == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Субтитри збережено.')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          final updated = await showVideoFormDialog(context, existing: video);
                          if (updated == null) return;
                          await ref.read(videoServiceProvider).updateVideo(video.id, updated);
                          ref.invalidate(videosProvider);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (!await confirmDelete(context, video.titleUk)) return;
                          await ref.read(videoServiceProvider).deleteVideo(video.id);
                          ref.invalidate(videosProvider);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
