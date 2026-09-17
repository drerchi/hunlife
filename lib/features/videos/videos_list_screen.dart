import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/widgets/async_view.dart';
import '../../providers/service_providers.dart';
import '../../providers/session_provider.dart';
import '../../providers/video_providers.dart';
import '../admin/widgets/confirm_delete_dialog.dart';
import '../admin/widgets/transcript_import_dialog.dart';
import '../admin/widgets/video_form_dialog.dart';

class VideosListScreen extends ConsumerWidget {
  const VideosListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(videosProvider);
    final isAdmin = ref.watch(sessionProvider).valueOrNull?.profile?.isAdmin ?? false;

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await showVideoFormDialog(context);
                if (created == null) return;
                await ref.read(videoServiceProvider).createVideo(created);
                ref.invalidate(videosProvider);
              },
              icon: const Icon(Icons.add_link),
              label: const Text('Додати відео'),
            )
          : null,
      appBar: AppBar(
        title: const Text('Відео'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Мій словник',
            onPressed: () => context.push(AppRoutes.vocabulary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(videosProvider),
        child: AsyncView(
          value: videos,
          onRetry: () => ref.invalidate(videosProvider),
          data: (context, list) {
            if (list.isEmpty) {
              return const EmptyState(
                message: 'Відео поки немає.\nАдміністратор може додати їх у панелі адміністратора.',
                icon: Icons.smart_display_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final video = list[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.videoDetail(video.id)),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          height: 90,
                          child: Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.smart_display_outlined),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  video.titleUk,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (video.titleHu != null)
                                  Text(
                                    video.titleHu!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (video.level != null) ...[
                                  const SizedBox(height: 6),
                                  Chip(
                                    label: Text(video.level!),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (isAdmin)
                          PopupMenuButton<String>(
                            tooltip: 'Керувати відео',
                            onSelected: (value) async {
                              final videoService = ref.read(videoServiceProvider);
                              switch (value) {
                                case 'subtitles':
                                  final saved =
                                      await showTranscriptImportDialog(context, video);
                                  if (saved == true) {
                                    ref.invalidate(transcriptProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Субтитри збережено.')),
                                      );
                                    }
                                  }
                                  break;
                                case 'edit':
                                  final updated =
                                      await showVideoFormDialog(context, existing: video);
                                  if (updated == null) return;
                                  await videoService.updateVideo(video.id, updated);
                                  ref.invalidate(videosProvider);
                                  break;
                                case 'delete':
                                  if (!context.mounted) return;
                                  if (!await confirmDelete(context, video.titleUk)) return;
                                  await videoService.deleteVideo(video.id);
                                  ref.invalidate(videosProvider);
                                  break;
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'subtitles',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.subtitles_outlined),
                                  title: Text('Субтитри'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Редагувати'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                                  title: Text('Видалити'),
                                ),
                              ),
                            ],
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.chevron_right),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
