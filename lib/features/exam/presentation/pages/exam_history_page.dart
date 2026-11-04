import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../domain/exam_attempt.dart';
import '../../domain/exam_blueprint.dart';
import '../providers/exam_providers.dart';
import '../widgets/exam_common.dart';

/// Completed attempts, newest first, with best / last per direction
/// (RoutePaths.examHistory).
class ExamHistoryPage extends ConsumerWidget {
  const ExamHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(examHistoryProvider);
    final blueprints = ref.watch(examBlueprintsProvider).valueOrNull ?? const [];
    final byId = {for (final b in blueprints) b.id: b};
    final Widget body;
    if (state.isInitialLoading) {
      body = const ExamLoadingView();
    } else if (state.items.isEmpty && state.failure != null) {
      body = ExamMessageView.error(
        context,
        error: state.failure,
        onRetry: () => ref.invalidate(examHistoryProvider),
      );
    } else if (state.items.isEmpty) {
      body = ExamMessageView(icon: Icons.history_rounded, message: l.examHistoryEmpty);
    } else {
      final trends = BlueprintTrend.fromAttempts(state.items);
      final gutter = AppSpacing.gutter(context);
      final extra = state.hasMore || state.failure != null ? 1 : 0;
      body = RefreshIndicator(
        onRefresh: () async => ref.invalidate(examHistoryProvider),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.huge),
          itemCount: 1 + state.items.length + extra,
          itemBuilder: (context, i) {
            if (i == 0) return _TrendSummary(trends: trends, blueprints: byId);
            final idx = i - 1;
            if (idx < state.items.length) {
              return _AttemptRow(attempt: state.items[idx], blueprint: byId[state.items[idx].blueprintId]);
            }
            if (state.failure != null) {
              return TextButton.icon(
                onPressed: () => ref.read(examHistoryProvider.notifier).loadMore(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.examRetry),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: state.loading
                  ? const Center(
                      child: SizedBox.square(
                          dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                  : TextButton(
                      onPressed: () => ref.read(examHistoryProvider.notifier).loadMore(),
                      child: Text(l.examShowMore),
                    ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.examHistoryTitle)),
      body: body,
    );
  }
}

class _TrendSummary extends StatelessWidget {
  final List<BlueprintTrend> trends;
  final Map<String, ExamBlueprint> blueprints;

  const _TrendSummary({required this.trends, required this.blueprints});

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final ui = context.uiLang;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        children: [
          for (final t in trends)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ExamCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(blueprints[t.blueprintId]?.title.resolve(ui) ?? t.blueprintId,
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Text(l.examHistoryLast(formatExamPercent(t.last, ui)),
                            style: theme.textTheme.bodyMedium),
                        Text(l.examVariantBest(formatExamPercent(t.best, ui)),
                            style: theme.textTheme.bodyMedium),
                        Text(l.examHistoryAttempts(t.attempts),
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                    if (t.delta != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _Trend(delta: t.delta!, color: t.delta! > 0.05
                          ? tokens.success
                          : t.delta! < -0.05
                              ? tokens.danger
                              : tokens.textSecondary),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  final double delta;
  final Color color;
  const _Trend({required this.delta, required this.color});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ui = context.uiLang;
    final abs = formatExamPercent(delta.abs(), ui);
    final (IconData icon, String text) = delta > 0.05
        ? (Icons.trending_up_rounded, l.examHistoryTrendUp(abs))
        : delta < -0.05
            ? (Icons.trending_down_rounded, l.examHistoryTrendDown(abs))
            : (Icons.trending_flat_rounded, l.examHistoryTrendSame);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
        ),
      ],
    );
  }
}

class _AttemptRow extends StatelessWidget {
  final AttemptSummary attempt;
  final ExamBlueprint? blueprint;

  const _AttemptRow({required this.attempt, required this.blueprint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final ui = context.uiLang;
    final r = attempt.result;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ExamCard(
        onTap: () => context.push(RoutePaths.examResultFor(attempt.id)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(blueprint?.title.resolve(ui) ?? attempt.blueprintId,
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      formatExamDate(attempt.completedAtMs, ui),
                      examLanguageName(context.l10n, attempt.language),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (r != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${formatExamPercent(r.percent, ui)}%',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.primary)),
                  Text('${r.correct}/${r.total}', style: theme.textTheme.labelSmall),
                ],
              ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }
}
