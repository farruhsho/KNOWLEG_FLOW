import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../providers/exam_providers.dart';
import 'exam_common.dart';
import 'exam_countdown.dart';

/// Compact "continue your unfinished test" card. Renders nothing when there
/// is no attempt in progress (local Hive copy or Firestore).
class ExamResumeBanner extends ConsumerWidget {
  const ExamResumeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(activeAttemptProvider);
    if (info == null) return const SizedBox.shrink();
    final l = context.l10n;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;
    final clock = ref.watch(examClockProvider);
    var title = context.tr(info.blueprintTitle);
    if (title.isEmpty) {
      final bp = ref.watch(examBlueprintProvider(info.blueprintId)).valueOrNull;
      title = bp == null ? l.examResumeTitle : context.tr(bp.title);
    }
    final deadline = info.deadline;
    final expired = deadline != null && !deadline.isAfter(clock());
    final subtitle = <String>[
      if (info.sectionCount > 0)
        l.examSectionLabel(info.sectionIndex + 1, info.sectionCount),
      if (info.awaitingSubmit) l.examResumeAwaitingSubmit,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: ExamCard(
        color: scheme.primaryContainer,
        borderColor: scheme.primary.withValues(alpha: 0.35),
        onTap: () => context.push(RoutePaths.examRunFor(info.attemptId)),
        child: Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: scheme.primary, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.examResumeTitle,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xxs),
                  if (deadline != null)
                    expired
                        ? Text(l.examResumeTimeUp,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: tokens.danger))
                        : ExamCountdown(
                            deadline: deadline,
                            clock: clock,
                            style: theme.textTheme.labelLarge,
                          ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: () => context.push(RoutePaths.examRunFor(info.attemptId)),
              child: Text(l.examContinue),
            ),
          ],
        ),
      ),
    );
  }
}
