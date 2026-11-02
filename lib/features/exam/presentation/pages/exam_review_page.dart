import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../domain/exam_payload.dart';
import '../providers/exam_providers.dart';
import '../widgets/exam_common.dart';
import '../widgets/option_tile.dart';
import '../widgets/passage_panel.dart';
import '../widgets/rich_stem.dart';

enum _ReviewFilter { all, wrong, flagged }

/// Per-question review of a completed attempt (RoutePaths.examReview).
class ExamReviewPage extends ConsumerStatefulWidget {
  final String attemptId;

  const ExamReviewPage({super.key, required this.attemptId});

  @override
  ConsumerState<ExamReviewPage> createState() => _ExamReviewPageState();
}

class _ExamReviewPageState extends ConsumerState<ExamReviewPage> {
  _ReviewFilter _filter = _ReviewFilter.all;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(examReviewProvider(widget.attemptId));
    final localFlags =
        ref.watch(examLocalFlagsProvider(widget.attemptId)).valueOrNull ?? const {};
    return Scaffold(
      appBar: AppBar(title: Text(l.examReviewTitle)),
      body: async.when(
        loading: () => const ExamLoadingView(),
        error: (e, _) => ExamMessageView.error(
          context,
          error: e,
          onRetry: () => ref.invalidate(examReviewProvider(widget.attemptId)),
        ),
        data: (items) {
          bool flagged(ReviewItem i) => i.flagged ?? localFlags.contains(i.questionId);
          final indexed = [for (var i = 0; i < items.length; i++) (i + 1, items[i])];
          final visible = indexed.where((e) => switch (_filter) {
                _ReviewFilter.all => true,
                _ReviewFilter.wrong => e.$2.isWrong,
                _ReviewFilter.flagged => flagged(e.$2),
              }).toList();
          final gutter = AppSpacing.gutter(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.sm),
                child: Row(
                  children: [
                    for (final f in _ReviewFilter.values) ...[
                      ChoiceChip(
                        label: Text(switch (f) {
                          _ReviewFilter.all => '${l.examReviewFilterAll} · ${items.length}',
                          _ReviewFilter.wrong =>
                            '${l.examReviewFilterWrong} · ${items.where((i) => i.isWrong).length}',
                          _ReviewFilter.flagged =>
                            '${l.examReviewFilterFlagged} · ${items.where(flagged).length}',
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? ExamMessageView(
                        icon: Icons.filter_alt_off_outlined,
                        message: l.examReviewEmpty,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                            gutter, AppSpacing.sm, gutter, AppSpacing.huge),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) => _ReviewCard(
                          number: visible[i].$1,
                          item: visible[i].$2,
                          flagged: flagged(visible[i].$2),
                          attemptId: widget.attemptId,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final int number;
  final ReviewItem item;
  final bool flagged;
  final String attemptId;

  const _ReviewCard({
    required this.number,
    required this.item,
    required this.flagged,
    required this.attemptId,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final (IconData icon, Color color) = item.isCorrect
        ? (Icons.check_circle_rounded, tokens.success)
        : item.isSkipped
            ? (Icons.remove_circle_outline_rounded, tokens.textTertiary)
            : (Icons.cancel_rounded, tokens.danger);
    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l.examReviewQuestionNumber(number),
                    style: theme.textTheme.titleSmall),
              ),
              if (flagged) Icon(Icons.flag_rounded, size: 18, color: tokens.warning),
            ],
          ),
          if (item.passage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                leading: const Icon(Icons.article_outlined),
                title: Text(
                  item.passage!.title.isEmpty
                      ? l.examPassage
                      : '${l.examPassage}: ${item.passage!.title}',
                  style: theme.textTheme.labelLarge,
                ),
                children: [PassageText(passage: item.passage!)],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (item.stem.isNotEmpty) RichStem(item.stem, style: theme.textTheme.bodyLarge),
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ExamImage(url: item.imageUrl!),
          ],
          if (item.table != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ExamTable.fromQuestion(item.table!),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final o in item.options) ...[
            ExamOptionTile(
              letter: o.id,
              text: o.text,
              mark: o.id == item.correct
                  ? OptionMark.correct
                  : o.id == item.userAnswer
                      ? OptionMark.wrong
                      : OptionMark.none,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            l.examReviewYourAnswer(item.userAnswer ?? l.examReviewNoAnswer),
            style: theme.textTheme.bodyMedium,
          ),
          if (item.correct != null)
            Text(l.examReviewCorrectAnswer(item.correct!),
                style: theme.textTheme.bodyMedium?.copyWith(color: tokens.success)),
          if (item.explanation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l.examReviewExplanation, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            RichStem(item.explanation, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => context.push(
                RoutePaths.tutor,
                extra: {'questionId': item.questionId, 'attemptId': attemptId},
              ),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(l.examReviewAskTutor),
            ),
          ),
        ],
      ),
    );
  }
}
