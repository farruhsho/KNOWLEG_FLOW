import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/utils/bishkek_time.dart';
import '../../l10n/app_localizations.dart';
import '../models/gamification_models.dart';

/// Localized quest title by type (stored titles are legacy Russian text).
String questTitle(AppLocalizations l, DailyQuest q) {
  switch (q.type) {
    case QuestType.answerQuestions:
      return l.learnQuestAnswer(q.targetValue);
    case QuestType.completeTest:
      return l.learnQuestCompleteSet;
    case QuestType.perfectAnswers:
      return l.learnQuestRun(q.targetValue);
    case QuestType.studyMinutes:
    case QuestType.specificTopic:
      return q.title;
  }
}

/// Today's cosmetic quests. Rewards are coins only; XP is server-owned.
class DailyQuestsWidget extends StatelessWidget {
  final List<DailyQuest> quests;
  final void Function(String questId)? onQuestTap;

  const DailyQuestsWidget({
    super.key,
    required this.quests,
    this.onQuestTap,
  });

  /// Time left until midnight in Bishkek (when quests reset).
  static Duration untilReset(DateTime now) {
    final w = BishkekTime.wallClock(now);
    final reset = DateTime.utc(w.year, w.month, w.day + 1).subtract(BishkekTime.offset);
    return reset.difference(now.toUtc());
  }

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final left = untilReset(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.learnQuestsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l.learnQuestsReset(left.inHours, left.inMinutes.remainder(60)),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final q in quests) _QuestTile(quest: q, onTap: onQuestTap),
          ],
        ),
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  final DailyQuest quest;
  final void Function(String questId)? onTap;
  const _QuestTile({required this.quest, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final done = quest.isCompleted;
    return InkWell(
      onTap: done || onTap == null ? null : () => onTap!(quest.id),
      borderRadius: AppRadii.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : _icon(quest.type), color: done ? t.success : theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(questTitle(l, quest), style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: LinearProgressIndicator(
                      value: quest.progress,
                      minHeight: 4,
                      color: done ? t.success : theme.colorScheme.primary,
                      backgroundColor: t.surfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('${quest.currentValue}/${quest.targetValue}', style: theme.textTheme.labelSmall),
            if (quest.coinsReward > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.toll_outlined, size: 14, color: t.xp),
              Text('${quest.coinsReward}', style: theme.textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _icon(QuestType type) {
    switch (type) {
      case QuestType.answerQuestions:
        return Icons.quiz_outlined;
      case QuestType.completeTest:
        return Icons.assignment_turned_in_outlined;
      case QuestType.studyMinutes:
        return Icons.schedule;
      case QuestType.perfectAnswers:
        return Icons.emoji_events_outlined;
      case QuestType.specificTopic:
        return Icons.subject;
    }
  }
}

/// Compact summary card for the home screen.
class CompactDailyQuests extends StatelessWidget {
  final List<DailyQuest> quests;
  final VoidCallback? onViewAll;

  const CompactDailyQuests({
    super.key,
    required this.quests,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final completed = quests.where((q) => q.isCompleted).length;
    final all = quests.isNotEmpty && completed == quests.length;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll, side: BorderSide(color: t.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onViewAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.learnQuestsTitle, style: theme.textTheme.titleSmall),
                    Text(l.learnQuestsDone(completed, quests.length), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(all ? Icons.check_circle : Icons.chevron_right, color: all ? t.success : t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
