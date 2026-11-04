import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/practice_session_model.dart';
import '../../../../shared/services/activity_reporter.dart';
import '../../../../shared/widgets/elapsed_timer.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../gamification/gamification_routes.dart';
import '../../data/practice_session_store.dart';
import '../../domain/practice_score.dart';
import 'practice_review_page.dart';

/// Practice results. Shows a **practice percentage only** — never an ORT
/// score (EXAM-03). Works without route `extra` (EXAM-15): falls back to the
/// last session kept in memory, or an empty state.
class QuizResultsPage extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final int totalTimeSeconds;

  const QuizResultsPage({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalTimeSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final store = PracticeSessionStore.instance;
    final session = store.matching(total: totalQuestions, correct: correctAnswers);
    final total = session?.total ?? totalQuestions;
    final correct = session?.correct ?? correctAnswers;
    final seconds = session?.elapsedSeconds ?? totalTimeSeconds;

    if (total <= 0) {
      return Scaffold(
        appBar: AppBar(title: Text(l.learnResultsTitle)),
        body: EmptyView(
          icon: Icons.assignment_outlined,
          message: l.learnResultsEmptyTitle,
          subtitle: l.learnResultsEmptyBody,
          action: FilledButton(
            onPressed: () => context.pushReplacement(RoutePaths.quickTest),
            child: Text(l.learnQuickPracticeTitle),
          ),
        ),
      );
    }

    final score = PracticeScore(correct: correct, total: total);
    final wrong = session?.wrong ?? (total - correct);
    final skipped = session?.skipped ?? 0;
    final answered = total - skipped;
    final theme = Theme.of(context);
    final t = context.tokens;
    final gutter = AppSpacing.gutter(context);
    final color = switch (score.band) {
      PracticeBand.excellent || PracticeBand.good => t.success,
      PracticeBand.fair => t.warning,
      _ => t.danger,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l.learnResultsTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => context.go(RoutePaths.home),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.xxxl),
          children: [
            // Score: a practice percentage, explicitly not an ORT score.
            Semantics(
              label: '${score.headline(l)}. ${score.summary(l)}',
              child: Column(
                children: [
                  SizedBox(
                    width: 148,
                    height: 148,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: score.percent / 100,
                          strokeWidth: 10,
                          backgroundColor: t.surfaceMuted,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                        Center(
                          child: Text(
                            '${score.percent}%',
                            style: theme.textTheme.displaySmall?.copyWith(color: color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(score.headline(l), style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xs),
                  Text(score.summary(l), style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    score.verdict(l),
                    style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Note(text: l.learnPracticeNotOrtNote),
            const SizedBox(height: AppSpacing.lg),
            _StatsGrid(items: [
              (Icons.check_circle_outline, l.learnStatCorrect, '$correct', t.success),
              (Icons.cancel_outlined, l.learnStatWrong, '$wrong', t.danger),
              (Icons.skip_next_outlined, l.learnStatSkipped, '$skipped', t.textSecondary),
              (Icons.schedule, l.learnStatTime, ElapsedTimer.format(Duration(seconds: seconds)), theme.colorScheme.primary),
            ]),
            if (answered > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.learnAvgPerQuestion((seconds / total).round()),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (session != null && answered > 0) _XpLine(future: store.lastXp),
            const SizedBox(height: AppSpacing.xl),
            if (session != null && session.answers.isNotEmpty)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => PracticeReviewPage(result: session)),
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(l.learnReviewAnswers),
              ),
            if (wrong > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => context.push(kMistakesPath),
                icon: const Icon(Icons.replay_outlined),
                label: Text(l.learnOpenMistakes),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _retry(context, session),
              icon: const Icon(Icons.refresh),
              label: Text(l.learnPracticeAgain),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.go(RoutePaths.home),
              child: Text(l.learnBackHome),
            ),
          ],
        ),
      ),
    );
  }

  void _retry(BuildContext context, PracticeSessionResult? s) {
    final subject = s?.subjectId;
    if (s != null && s.kind == PracticeKind.subject && subject != null && subject.isNotEmpty) {
      context.pushReplacement(RoutePaths.quizById(subject));
    } else {
      context.pushReplacement(RoutePaths.quickTest);
    }
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.surfaceMuted,
        borderRadius: AppRadii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: t.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<(IconData, String, String, Color)> items;
  const _StatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth < 340 ? 2 : 4;
      final w = (c.maxWidth - AppSpacing.sm * (perRow - 1)) / perRow;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final (icon, label, value, color) in items)
            Container(
              width: w,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                borderRadius: AppRadii.mdAll,
                border: Border.all(color: t.border),
              ),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: theme.textTheme.titleMedium, maxLines: 1),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

/// Server XP for the session, shown when the callable answers. Never blocks.
class _XpLine extends StatelessWidget {
  final Future<ActivityResult?>? future;
  const _XpLine({required this.future});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<ActivityResult?>(
      future: future,
      builder: (context, snap) {
        final String text;
        if (snap.connectionState != ConnectionState.done) {
          text = l.learnXpPending;
        } else if (snap.data == null) {
          text = l.learnXpQueued;
        } else if (snap.data!.xpAwarded > 0) {
          text = l.learnXpAwarded(snap.data!.xpAwarded);
        } else {
          text = l.learnXpNone;
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, color: t.xp, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Flexible(child: Text(text, style: style, textAlign: TextAlign.center)),
          ],
        );
      },
    );
  }
}
