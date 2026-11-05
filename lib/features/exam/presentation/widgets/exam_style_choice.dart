import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/exam_start.dart';
import 'exam_common.dart';

/// «Тренировка» / «Как на ОРТ» picker on the rules screen (§10.2), with a
/// short, honest explanation of each style.
class ExamStyleChoice extends StatelessWidget {
  final ExamStyle value;
  final ValueChanged<ExamStyle>? onChanged;

  const ExamStyleChoice({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StyleOption(
          key: const ValueKey('exam_style_standard'),
          icon: Icons.fitness_center_rounded,
          title: l.examStyleStandard,
          body: l.examStyleStandardBody,
          selected: value == ExamStyle.standard,
          onTap: onChanged == null ? null : () => onChanged!(ExamStyle.standard),
        ),
        const SizedBox(height: AppSpacing.sm),
        _StyleOption(
          key: const ValueKey('exam_style_strict'),
          icon: Icons.assignment_turned_in_outlined,
          title: l.examStyleStrict,
          body: l.examStyleStrictBody,
          footnote: l.examStyleStrictSource,
          selected: value == ExamStyle.strict,
          onTap: onChanged == null ? null : () => onChanged!(ExamStyle.strict),
        ),
      ],
    );
  }
}

class _StyleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? footnote;
  final bool selected;
  final VoidCallback? onTap;

  const _StyleOption({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    this.footnote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    return Semantics(
      button: onTap != null,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.lgAll,
          side: BorderSide(
            color: selected ? scheme.primary : tokens.border,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? scheme.primary : tokens.textTertiary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 18, color: tokens.textSecondary),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(title, style: theme.textTheme.titleSmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(body, style: theme.textTheme.bodyMedium),
                      if (footnote != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          footnote!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One rule line (icon + text) used on the rules and instruction screens.
class ExamRuleLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const ExamRuleLine(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.tokens.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// The strict-style rules (§10.2) as rule lines.
List<Widget> strictRuleLines(BuildContext context, {bool includeInstruction = true}) {
  final l = context.l10n;
  return [
    ExamRuleLine(Icons.hourglass_bottom_rounded, l.examStrictRuleNoEarlyFinish),
    ExamRuleLine(Icons.edit_off_outlined, l.examStrictRuleOneCorrection),
    ExamRuleLine(Icons.outlined_flag_rounded, l.examStrictRuleNoFlags),
    if (includeInstruction)
      ExamRuleLine(Icons.menu_book_outlined, l.examStrictRuleInstruction),
  ];
}
