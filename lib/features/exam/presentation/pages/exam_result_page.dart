import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../domain/exam_blueprint.dart';
import '../../domain/exam_payload.dart';
import '../providers/exam_providers.dart';
import '../widgets/exam_common.dart';

/// Human label for a topic id. Prefers a title the server sent; otherwise
/// maps the id prefix to the blueprint's section / part title.
String examTopicLabel(String topicId, ExamResult result, ExamBlueprint? bp, String lang) {
  final t = result.topic(topicId);
  if (t != null && !t.title.isEmpty) return t.title.resolve(lang);
  final segments = topicId.split('.');
  String? area;
  if (bp != null) {
    for (final s in bp.sections) {
      if (s.id == segments.first || s.subjectArea == segments.first) {
        area = s.title.resolve(lang);
      }
      for (final p in s.parts) {
        if (p.id == segments.first) area = p.title.resolve(lang);
      }
    }
  }
  final rest = segments.length > 1
      ? segments.sublist(1).join(' · ').replaceAll('_', ' ')
      : '';
  if (area == null) return topicId.replaceAll('_', ' ');
  return rest.isEmpty ? area : '$area · $rest';
}

/// Result of a completed attempt (RoutePaths.examResult). Shows only the
/// server-computed raw result and percentage, never an "ORT score".
class ExamResultPage extends ConsumerWidget {
  final String attemptId;

  const ExamResultPage({super.key, required this.attemptId});

  void _toExams(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.exams);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(examResultProvider(attemptId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.examResultTitle),
        leading: IconButton(
          tooltip: l.examResultToExams,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _toExams(context),
        ),
      ),
      body: async.when(
        loading: () => const ExamLoadingView(),
        error: (e, _) => e is ExamResultPendingException
            ? ExamMessageView(
                icon: Icons.hourglass_top_rounded,
                message: l.examResultPending,
                actionLabel: l.examRetry,
                onAction: () => ref.invalidate(examResultProvider(attemptId)),
              )
            : ExamMessageView.error(
                context,
                error: e,
                onRetry: () => ref.invalidate(examResultProvider(attemptId)),
              ),
        data: (data) => _ResultBody(data: data, onToExams: () => _toExams(context)),
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  final ExamResultData data;
  final VoidCallback onToExams;

  const _ResultBody({required this.data, required this.onToExams});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    final r = data.result;
    final bp = data.blueprint;
    final ui = context.uiLang;
    final gutter = AppSpacing.gutter(context);
    final percent = formatExamPercent(r.percent, ui);
    final skipped = data.skipped;
    final incorrect = data.incorrect;
    final disclaimer =
        bp?.scoring.disclaimer.resolve(ui, fallback: l.examDisclaimerFallback) ??
            l.examDisclaimerFallback;
    final isLevelBased =
        bp?.kind == BlueprintKind.stateLanguage || (bp?.scoring.isLevelBased ?? false);

    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.huge),
      children: [
        if (bp != null)
          Text(bp.title.resolve(ui),
              style: theme.textTheme.titleMedium?.copyWith(color: tokens.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        ExamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$percent%',
                  style: theme.textTheme.displayMedium?.copyWith(color: scheme.primary)),
              Text(l.examResultScore(r.correct, r.total), style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: l.examResultCorrect,
                      value: '${r.correct}',
                      color: tokens.success,
                    ),
                  ),
                  if (incorrect != null && skipped != null) ...[
                    Expanded(
                      child: _Stat(
                        label: l.examResultIncorrect,
                        value: '$incorrect',
                        color: tokens.danger,
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: l.examResultSkipped,
                        value: '$skipped',
                        color: tokens.textSecondary,
                      ),
                    ),
                  ] else
                    Expanded(
                      flex: 2,
                      child: _Stat(
                        label: l.examResultWrongOrSkipped,
                        value: '${(r.total - r.correct).clamp(0, r.total)}',
                        color: tokens.danger,
                      ),
                    ),
                ],
              ),
              if (r.xpAwarded > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                ExamPill(
                  label: l.examResultXp(r.xpAwarded),
                  background: tokens.xpContainer,
                  foreground: tokens.xp,
                  icon: Icons.bolt_rounded,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Always shown: this is a practice result, not an official ORT score.
        _Note(icon: Icons.info_outline_rounded, text: disclaimer),
        if (!r.leaderboardEligible) ...[
          const SizedBox(height: AppSpacing.sm),
          _Note(icon: Icons.schedule_rounded, text: l.examResultNotEligible),
        ],
        if (isLevelBased) ...[
          const SizedBox(height: AppSpacing.lg),
          ExamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.examResultLevelsTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(l.examResultLevelsBody, style: theme.textTheme.bodyMedium),
                if (bp != null && bp.scoring.levels.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  for (final lv in bp.scoring.levels)
                    Text('${lv.level} — ${lv.title.resolve(ui)}',
                        style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
        if (r.sections.length > 1 || (r.sections.isNotEmpty && bp != null && bp.sections.length > 1)) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(l.examResultBySection, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ExamCard(
            child: Column(
              children: [
                for (final s in r.sections)
                  _SectionBar(
                    title: bp?.sectionById(s.sectionId)?.title.resolve(ui) ?? s.sectionId,
                    score: s,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(l.examResultWeak, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (r.weakTopics.isEmpty)
          Text(l.examResultNoWeak, style: theme.textTheme.bodyMedium)
        else
          for (final t in r.weakTopics.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TopicCard(
                label: examTopicLabel(t, r, bp, ui),
                score: r.topic(t),
              ),
            ),
        if (r.strongTopics.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l.examResultStrong, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final t in r.strongTopics.take(8))
                ExamPill(
                  label: examTopicLabel(t, r, bp, ui),
                  background: tokens.successContainer,
                  foreground: tokens.success,
                  icon: Icons.star_rounded,
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        FilledButton.icon(
          onPressed: () => context.push(RoutePaths.examReviewFor(data.attemptId)),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(l.examResultReview),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: onToExams, child: Text(l.examResultToExams)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tokens.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  final String title;
  final SectionScore score;
  const _SectionBar({required this.title, required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final value = (score.percent / 100).clamp(0.0, 1.0);
    final color = score.percent >= 70
        ? tokens.success
        : score.percent >= 40
            ? tokens.warning
            : tokens.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${score.correct}/${score.total} · ${formatExamPercent(score.percent, context.uiLang)}%',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: color,
              backgroundColor: tokens.surfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final String label;
  final TopicScore? score;
  const _TopicCard({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return ExamCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.replay_rounded, size: 20, color: tokens.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                    if (score != null && score!.total > 0)
                      Text(l.examResultTopicScore(score!.correct, score!.total),
                          style: theme.textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(l.examResultRecommendation(label), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
