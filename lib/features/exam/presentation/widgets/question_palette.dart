import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/exam_session.dart';
import 'exam_common.dart';

/// A group of consecutive questions (one blueprint part) in the palette.
@immutable
class PaletteGroup {
  final String title;
  final int start;
  final int count;

  const PaletteGroup({required this.title, required this.start, required this.count});
}

/// Grid of question numbers for in-section navigation, coloured by state
/// (answered / marked / not answered) with a legend.
class QuestionPalette extends StatelessWidget {
  final List<QuestionCellState> cells;
  final List<PaletteGroup> groups;
  final ValueChanged<int> onSelect;

  const QuestionPalette({
    super.key,
    required this.cells,
    required this.onSelect,
    this.groups = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final answered = cells.where((c) => c.answered).length;
    final flagged = cells.where((c) => c.flagged).length;
    final effectiveGroups = groups.isEmpty
        ? [PaletteGroup(title: '', start: 0, count: cells.length)]
        : groups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            _Legend(kind: _CellKind.answered, label: '${l.examPaletteAnswered} · $answered'),
            _Legend(kind: _CellKind.flagged, label: '${l.examPaletteFlagged} · $flagged'),
            _Legend(
                kind: _CellKind.empty,
                label: '${l.examPaletteUnanswered} · ${cells.length - answered}'),
          ],
        ),
        for (final g in effectiveGroups) ...[
          const SizedBox(height: AppSpacing.lg),
          if (g.title.isNotEmpty) ...[
            Text(g.title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = g.start;
                  i < g.start + g.count && i < cells.length;
                  i++)
                PaletteCell(
                  key: ValueKey('palette_cell_$i'),
                  number: i + 1,
                  state: cells[i],
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

enum _CellKind { answered, flagged, empty }

class PaletteCell extends StatelessWidget {
  final int number;
  final QuestionCellState state;
  final VoidCallback onTap;

  const PaletteCell({
    super.key,
    required this.number,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final l = context.l10n;
    final kind = state.flagged
        ? _CellKind.flagged
        : state.answered
            ? _CellKind.answered
            : _CellKind.empty;
    final (bg, fg, border) = _colors(context, kind, answered: state.answered);
    final status = [
      state.answered ? l.examPaletteAnswered : l.examPaletteUnanswered,
      if (state.flagged) l.examPaletteFlagged,
      if (state.current) l.examPaletteCurrent,
    ].join(', ');
    return Semantics(
      button: true,
      label: '${l.examReviewQuestionNumber(number)}. $status',
      excludeSemantics: true,
      child: SizedBox(
        width: AppSpacing.minTouch,
        height: AppSpacing.minTouch,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.smAll,
            side: BorderSide(
              color: state.current ? scheme.primary : border,
              width: state.current ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$number',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: fg),
                  ),
                ),
                if (state.flagged)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(Icons.flag_rounded, size: 12, color: tokens.warning),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (Color, Color, Color) _colors(BuildContext context, _CellKind kind,
      {required bool answered}) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    return switch (kind) {
      _CellKind.answered => (scheme.primary, scheme.onPrimary, scheme.primary),
      _CellKind.flagged => (
          tokens.warningContainer,
          answered ? scheme.primary : scheme.onSurface,
          tokens.warning,
        ),
      _CellKind.empty => (scheme.surface, scheme.onSurface, tokens.borderStrong),
    };
  }
}

class _Legend extends StatelessWidget {
  final _CellKind kind;
  final String label;

  const _Legend({required this.kind, required this.label});

  @override
  Widget build(BuildContext context) {
    final (bg, _, border) = PaletteCell._colors(context, kind, answered: false);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.xs - 2),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
