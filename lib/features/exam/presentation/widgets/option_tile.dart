import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import 'exam_common.dart';
import 'rich_stem.dart';

/// Visual state of an answer option.
enum OptionMark {
  none,
  selected,

  /// Review: the correct option.
  correct,

  /// Review: the user's wrong choice.
  wrong,
}

/// Large tappable answer tile: letter badge + option text (LaTeX allowed).
class ExamOptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final OptionMark mark;
  final VoidCallback? onTap;

  const ExamOptionTile({
    super.key,
    required this.letter,
    required this.text,
    this.mark = OptionMark.none,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final (Color bg, Color border, Color badgeBg, Color badgeFg, IconData? icon) =
        switch (mark) {
      OptionMark.selected => (
          scheme.primaryContainer,
          scheme.primary,
          scheme.primary,
          scheme.onPrimary,
          null,
        ),
      OptionMark.correct => (
          tokens.successContainer,
          tokens.success,
          tokens.success,
          scheme.surface,
          Icons.check_rounded,
        ),
      OptionMark.wrong => (
          tokens.dangerContainer,
          tokens.danger,
          tokens.danger,
          scheme.surface,
          Icons.close_rounded,
        ),
      OptionMark.none => (
          scheme.surface,
          tokens.border,
          tokens.surfaceMuted,
          scheme.onSurface,
          null,
        ),
    };
    final emphasized = mark != OptionMark.none;
    return Semantics(
      button: onTap != null,
      selected: mark == OptionMark.selected,
      label: context.l10n.examOptionSemantics(letter),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mdAll,
          side: BorderSide(color: border, width: emphasized ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: AppSpacing.minTouch + 8),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                    child: icon != null
                        ? Icon(icon, size: 18, color: badgeFg)
                        : Text(
                            letter,
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: badgeFg),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: RichStem(text, style: theme.textTheme.bodyLarge),
                  ),
                  if (mark == OptionMark.selected) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.check_circle_rounded,
                        size: 22, color: scheme.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
