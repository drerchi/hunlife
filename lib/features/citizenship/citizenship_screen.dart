import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/util/answer_personaliser.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/speak_button.dart';
import '../../models/citizenship_question.dart';
import '../../providers/content_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/session_provider.dart';
import '../../providers/video_providers.dart';

/// Interview-prep screen: every question a candidate could plausibly be
/// asked at the Hungarian citizenship interview, grouped by category, with
/// both the Hungarian phrasing and a Ukrainian translation for question and
/// suggested answer.
class CitizenshipScreen extends ConsumerWidget {
  const CitizenshipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(citizenshipQuestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Підготовка до співбесіди'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(citizenshipQuestionsProvider),
        child: AsyncView(
          value: questions,
          onRetry: () => ref.invalidate(citizenshipQuestionsProvider),
          data: (context, list) {
            if (list.isEmpty) {
              return const EmptyState(
                message: 'Питань поки немає. Перевірте пізніше.',
                icon: Icons.flag_outlined,
              );
            }
            final grouped = <String, List<CitizenshipQuestion>>{};
            for (final q in list) {
              grouped.putIfAbsent(q.category, () => []).add(q);
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Ці запитання й відповіді допоможуть підготуватися до співбесіди на угорське громадянство. '
                      'Вивчіть угорські формулювання — саме їх, ймовірно, використає інтерв\'юер.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                if (!(ref.watch(sessionProvider).valueOrNull?.profile?.hasInterviewDetails ??
                    false)) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.badge_outlined, color: Theme.of(context).colorScheme.primary),
                      title: const Text('Додайте свої дані'),
                      subtitle: const Text(
                        'Щоб у відповідях були ваше ім\'я та дата народження',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.personalDetails),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 8),
                    child: Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ...entry.value.map((q) => _QuestionTile(question: q)),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuestionTile extends ConsumerStatefulWidget {
  const _QuestionTile({required this.question});

  final CitizenshipQuestion question;

  @override
  ConsumerState<_QuestionTile> createState() => _QuestionTileState();
}

class _QuestionTileState extends ConsumerState<_QuestionTile> {
  bool _saving = false;

  Future<void> _save(String? userId, String answerHu) async {
    if (userId == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(vocabularyServiceProvider).save(
            userId: userId,
            wordHu: widget.question.questionHu,
            translationUk: widget.question.questionUk,
            contextHu: answerHu,
          );
      ref.invalidate(savedWordsProvider);
      ref.invalidate(vocabularyProvider);
      // Hearing both the question and the rehearsed answer right away is the
      // point of saving it — read as one utterance so the answer isn't cut
      // off by a second call restarting the player mid-question.
      unawaited(
        ref.read(ttsServiceProvider).speak('${widget.question.questionHu} $answerHu'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося зберегти питання.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    // Answers are stored with tokens; fill in this learner's own details so
    // they rehearse the answer they will actually give.
    final profile = ref.watch(sessionProvider).valueOrNull?.profile;
    final answerHu = AnswerPersonaliser.apply(question.answerHu, profile);
    final answerUk = AnswerPersonaliser.apply(question.answerUk, profile);

    final savedWords = ref.watch(savedWordsProvider).valueOrNull ?? const <String>{};
    final isSaved = savedWords.contains(question.questionHu);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(question.questionHu,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            SpeakButton(text: question.questionHu, size: 20),
          ],
        ),
        subtitle: Text(question.questionUk),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Row(
            children: [
              Text('Відповідь угорською:', style: Theme.of(context).textTheme.labelMedium),
              SpeakButton(text: answerHu, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(answerHu, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Text('Переклад українською:', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(answerUk, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: (isSaved || _saving || profile == null)
                  ? null
                  : () => _save(profile.id, answerHu),
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(isSaved ? Icons.bookmark_added : Icons.bookmark_add_outlined),
              label: Text(isSaved ? 'У словнику' : 'Зберегти у словник'),
            ),
          ),
        ],
      ),
    );
  }
}
