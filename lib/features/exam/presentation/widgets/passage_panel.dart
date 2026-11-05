import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/exam_question.dart';
import 'exam_common.dart';
import 'rich_stem.dart';

/// Reading passage with a line number on every [lineEvery]-th source line
/// (as in the official ORT booklet).
class PassageText extends StatelessWidget {
  final ExamPassage passage;
  final int lineEvery;

  const PassageText({super.key, required this.passage, this.lineEvery = 5});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final lines = passage.lines;
    final numberStyle = theme.textTheme.labelSmall?.copyWith(
      color: tokens.textTertiary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final body = theme.textTheme.bodyLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (passage.title.isNotEmpty) ...[
          Text(passage.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (var i = 0; i < lines.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    lineEvery > 0 && (i + 1) % lineEvery == 0 ? '${i + 1}' : '',
                    style: numberStyle,
                  ),
                ),
              ),
              Expanded(
                child: lines[i].trim().isEmpty
                    ? const SizedBox(height: AppSpacing.sm)
                    : RichStem(lines[i], style: body),
              ),
            ],
          ),
      ],
    );
  }
}

/// Passage shown above the question on phones: collapsible, height-capped
/// and independently scrollable so the question stays reachable.
class CollapsiblePassagePanel extends StatefulWidget {
  final ExamPassage passage;
  final int lineEvery;
  final double maxHeight;

  const CollapsiblePassagePanel({
    super.key,
    required this.passage,
    required this.maxHeight,
    this.lineEvery = 5,
  });

  @override
  State<CollapsiblePassagePanel> createState() =>
      _CollapsiblePassagePanelState();
}

class _CollapsiblePassagePanelState extends State<CollapsiblePassagePanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(Icons.article_outlined, size: 18, color: tokens.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.passage.title.isEmpty
                            ? l.examPassage
                            : '${l.examPassage}: ${widget.passage.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Text(
                      _expanded ? l.examPassageHide : l.examPassageShow,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm, 0, AppSpacing.lg, AppSpacing.lg),
                  child: PassageText(
                      passage: widget.passage, lineEvery: widget.lineEvery),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
