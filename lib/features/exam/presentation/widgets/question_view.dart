import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/exam_blueprint.dart';
import '../../domain/exam_question.dart';
import 'exam_common.dart';
import 'option_tile.dart';
import 'passage_panel.dart';
import 'rich_stem.dart';

/// Column A | Column B cards of a quantitative-comparison item.
class ComparisonColumns extends StatelessWidget {
  final String columnA;
  final String columnB;

  const ComparisonColumns({super.key, required this.columnA, required this.columnB});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget card(String label, String content) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.tokens.surfaceMuted,
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: context.tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: context.tokens.textSecondary,
                        )),
                const SizedBox(height: AppSpacing.sm),
                Center(child: RichStem(content)),
              ],
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card(l.examColumnA, columnA),
          const SizedBox(width: AppSpacing.sm),
          card(l.examColumnB, columnB),
        ],
      ),
    );
  }
}

/// Stem, media, comparison columns and options of one question. Stateless:
/// the runner passes the current answer and callbacks.
class QuestionBody extends StatelessWidget {
  final ExamQuestion question;
  final ExamPart part;
  final List<QuestionOption> options;
  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final VoidCallback? onClear;

  const QuestionBody({
    super.key,
    required this.question,
    required this.part,
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showColumns = part.itemType == ExamItemType.quantitativeComparison &&
        question.hasComparisonColumns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (question.stem.trim().isNotEmpty)
          RichStem(question.stem, style: theme.textTheme.bodyLarge),
        if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ExamImage(url: question.imageUrl!),
        ],
        if (question.table != null) ...[
          const SizedBox(height: AppSpacing.md),
          ExamTable.fromQuestion(question.table!),
        ],
        if (showColumns) ...[
          const SizedBox(height: AppSpacing.md),
          ComparisonColumns(
            columnA: question.columnA ?? '',
            columnB: question.columnB ?? '',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final o in options) ...[
          ExamOptionTile(
            key: ValueKey('option_${question.id}_${o.id}'),
            letter: o.id,
            text: o.text,
            mark: o.id == selected ? OptionMark.selected : OptionMark.none,
            onTap: enabled ? () => onSelect(o.id) : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (selected != null && enabled && onClear != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: Text(context.l10n.examClearAnswer),
            ),
          ),
      ],
    );
  }
}

/// Lays out a question with its passage: side by side on wide screens,
/// collapsible panel above the question on phones.
class QuestionWithPassage extends StatelessWidget {
  final ExamPassage? passage;
  final int lineEvery;
  final Widget question;
  final ScrollController? controller;

  const QuestionWithPassage({
    super.key,
    required this.passage,
    required this.question,
    this.lineEvery = 5,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.gutter(context);
    final scrollable = SingleChildScrollView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: question,
        ),
      ),
    );
    final p = passage;
    if (p == null) return scrollable;
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 840) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.sm, AppSpacing.lg, gutter, AppSpacing.xxl),
                  child: PassageText(passage: p, lineEvery: lineEvery),
                ),
              ),
            ),
            VerticalDivider(width: 1, color: context.tokens.border),
            Expanded(child: scrollable),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollapsiblePassagePanel(
            key: ValueKey('passage_${p.id}'),
            passage: p,
            lineEvery: lineEvery,
            maxHeight: constraints.maxHeight * 0.42,
          ),
          Expanded(child: scrollable),
        ],
      );
    });
  }
}
