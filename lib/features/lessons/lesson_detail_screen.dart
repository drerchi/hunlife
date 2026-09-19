import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_view.dart';
import '../../core/widgets/speak_button.dart';
import '../../core/widgets/word_image_view.dart';
import '../../models/lesson.dart';
import '../../models/lesson_step.dart';
import '../../providers/content_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/session_provider.dart';

/// Walks the learner through a lesson one step at a time — a phrase, a short
/// note, or a quick check — instead of showing one long block of text.
/// Lessons that have no steps yet fall back to their plain text content.
class LessonDetailScreen extends ConsumerStatefulWidget {
  const LessonDetailScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  int _index = 0;
  int? _selectedOption;
  bool _answered = false;
  int _correctCount = 0;
  bool _finished = false;

  // Tracks which step index has already been read aloud, so entering a step
  // — including the very first one — speaks its word immediately instead of
  // waiting for the learner to tap "Прослухати" themselves, but re-entering
  // the same step from a rebuild doesn't restart the audio mid-listen.
  int? _lastSpokenIndex;

  void _next(int total) {
    setState(() {
      _selectedOption = null;
      _answered = false;
      if (_index < total - 1) {
        _index++;
      } else {
        _finished = true;
      }
    });
  }

  void _back() {
    setState(() {
      _selectedOption = null;
      _answered = false;
      if (_index > 0) _index--;
    });
  }

  void _autoSpeak(List<LessonStep> steps, int index) {
    if (index < 0 || index >= steps.length) return;
    if (_lastSpokenIndex == index) return;
    _lastSpokenIndex = index;

    final step = steps[index];
    // The prompt to pronounce, not a translation or a quiz question — quiz
    // options are speakable on demand but shouldn't blurt the term before
    // the learner has had a chance to answer.
    final text = step.kind == LessonStepKind.quiz ? null : step.textHu;
    if (text == null || text.trim().isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(ttsServiceProvider).speak(text);
    });
  }

  Future<void> _complete() async {
    final profile = ref.read(sessionProvider).valueOrNull?.profile;
    if (profile == null) return;
    await ref.read(contentServiceProvider).markLessonComplete(profile.id, widget.lessonId);
    ref.invalidate(completedLessonIdsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final lesson = ref.watch(lessonProvider(widget.lessonId));
    final steps = ref.watch(lessonStepsProvider(widget.lessonId));

    return Scaffold(
      appBar: AppBar(title: const Text('Урок')),
      body: AsyncView(
        value: lesson,
        onRetry: () => ref.invalidate(lessonProvider(widget.lessonId)),
        data: (context, l) {
          return AsyncView(
            value: steps,
            onRetry: () => ref.invalidate(lessonStepsProvider(widget.lessonId)),
            data: (context, stepList) {
              if (stepList.isEmpty) return _PlainLessonView(lesson: l, onComplete: _complete);
              if (_finished) {
                return _LessonSummary(
                  lesson: l,
                  total: stepList.where((s) => s.kind == LessonStepKind.quiz).length,
                  correct: _correctCount,
                  onRestart: () => setState(() {
                    _index = 0;
                    _finished = false;
                    _correctCount = 0;
                    _lastSpokenIndex = null;
                  }),
                  onComplete: _complete,
                );
              }
              _autoSpeak(stepList, _index);
              return _StepView(
                lesson: l,
                steps: stepList,
                index: _index,
                selectedOption: _selectedOption,
                answered: _answered,
                onSelectOption: (i, correct) {
                  setState(() {
                    _selectedOption = i;
                    _answered = true;
                    if (correct) _correctCount++;
                  });
                },
                onNext: () => _next(stepList.length),
                onBack: _back,
              );
            },
          );
        },
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({
    required this.lesson,
    required this.steps,
    required this.index,
    required this.selectedOption,
    required this.answered,
    required this.onSelectOption,
    required this.onNext,
    required this.onBack,
  });

  final Lesson lesson;
  final List<LessonStep> steps;
  final int index;
  final int? selectedOption;
  final bool answered;
  final void Function(int index, bool correct) onSelectOption;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final step = steps[index];
    final theme = Theme.of(context);
    final isLast = index == steps.length - 1;
    final canAdvance = step.kind != LessonStepKind.quiz || answered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: (index + 1) / steps.length),
              const SizedBox(height: 6),
              Text('Крок ${index + 1} з ${steps.length}  ·  ${lesson.titleUk}',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              // Keep a comfortable reading width; full-bleed text and
              // edge-to-edge answer buttons look broken on a desktop window.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: switch (step.kind) {
                  LessonStepKind.phrase => _PhraseStep(step: step),
                  LessonStepKind.note => _NoteStep(step: step),
                  LessonStepKind.quiz => _QuizStep(
                      step: step,
                      selectedOption: selectedOption,
                      answered: answered,
                      onSelect: onSelectOption,
                    ),
                },
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                if (index > 0)
                  OutlinedButton(onPressed: onBack, child: const Text('Назад')),
                const Spacer(),
                FilledButton(
                  onPressed: canAdvance ? onNext : null,
                  child: Text(isLast ? 'Завершити' : 'Далі'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhraseStep extends StatelessWidget {
  const _PhraseStep({required this.step});

  final LessonStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Card(
          // A plain surface, not a bold colour fill: with a picture and the
          // word itself already carrying the content, a saturated background
          // just added visual weight without adding information.
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                WordImageView(
                  wordHu: step.textHu ?? '',
                  ukrainian: step.textUk,
                  size: 140,
                ),
                const SizedBox(height: 12),
                Text(
                  step.textHu ?? '',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                SpeakFab(text: step.textHu ?? ''),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Shown immediately rather than behind a reveal tap: this is a new
        // word's first appearance, not a review, so there is nothing yet to
        // test recall of — hiding the translation only added a click with no
        // learning benefit. Flashcard study still uses tap-to-flip, where
        // recall is the point.
        Text(step.textUk ?? '', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        if (step.exampleHu != null) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(step.exampleHu!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
              ),
              SpeakButton(text: step.exampleHu!, size: 20),
            ],
          ),
          if (step.exampleUk != null)
            Text(step.exampleUk!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _NoteStep extends StatelessWidget {
  const _NoteStep({required this.step});

  final LessonStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Пояснення', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(step.textUk ?? '', style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
            if (step.textHu != null && step.textHu!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Text(step.textHu!,
                        style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
                  ),
                  SpeakButton(text: step.textHu!, size: 20),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizStep extends StatelessWidget {
  const _QuizStep({
    required this.step,
    required this.selectedOption,
    required this.answered,
    required this.onSelect,
  });

  final LessonStep step;
  final int? selectedOption;
  final bool answered;
  final void Function(int index, bool correct) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.quiz_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Перевірка', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        Text(step.questionUk ?? '', style: theme.textTheme.titleLarge),
        if (step.textHu != null && step.textHu!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(step.textHu!,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
              SpeakButton(text: step.textHu!),
            ],
          ),
        ],
        const SizedBox(height: 20),
        for (int i = 0; i < step.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionTile(
              label: step.options[i],
              state: !answered
                  ? _OptionState.idle
                  : i == step.correctOption
                      ? _OptionState.correct
                      : (i == selectedOption ? _OptionState.wrong : _OptionState.idle),
              onTap: answered ? null : () => onSelect(i, i == step.correctOption),
            ),
          ),
        if (answered) ...[
          const SizedBox(height: 8),
          Text(
            selectedOption == step.correctOption ? 'Правильно!' : 'Правильна відповідь виділена.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: selectedOption == step.correctOption ? Colors.green : theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.state, required this.onTap});

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color border, Color? fill, IconData? icon) = switch (state) {
      _OptionState.correct => (Colors.green, Colors.green.withValues(alpha: 0.12), Icons.check_circle),
      _OptionState.wrong => (scheme.error, scheme.error.withValues(alpha: 0.10), Icons.cancel),
      _OptionState.idle => (scheme.outlineVariant, null, null),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: state == _OptionState.idle ? 1 : 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            if (icon != null) Icon(icon, color: border),
          ],
        ),
      ),
    );
  }
}

class _LessonSummary extends StatelessWidget {
  const _LessonSummary({
    required this.lesson,
    required this.total,
    required this.correct,
    required this.onRestart,
    required this.onComplete,
  });

  final Lesson lesson;
  final int total;
  final int correct;
  final VoidCallback onRestart;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text('Урок пройдено!', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(lesson.titleUk, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            if (total > 0) ...[
              const SizedBox(height: 16),
              Text('Правильних відповідей: $correct з $total',
                  style: theme.textTheme.titleMedium),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () async {
                await onComplete();
                if (context.mounted) Navigator.of(context).maybePop();
              },
              icon: const Icon(Icons.check),
              label: const Text('Позначити як завершений'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.replay),
              label: const Text('Пройти ще раз'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback for lessons that still only have free-text content.
class _PlainLessonView extends ConsumerWidget {
  const _PlainLessonView({required this.lesson, required this.onComplete});

  final Lesson lesson;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(completedLessonIdsProvider).valueOrNull ?? <String>{};
    final isCompleted = completed.contains(lesson.id);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(lesson.titleUk, style: Theme.of(context).textTheme.headlineSmall),
        if (lesson.titleHu != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(lesson.titleHu!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.primary,
                        )),
              ),
              SpeakButton(text: lesson.titleHu!, size: 20),
            ],
          ),
        ],
        const SizedBox(height: 20),
        SelectableText(lesson.contentUk,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: isCompleted ? null : () => onComplete(),
          icon: Icon(isCompleted ? Icons.check_circle : Icons.check_circle_outline),
          label: Text(isCompleted ? 'Урок завершено' : 'Позначити як завершений'),
        ),
      ],
    );
  }
}
