import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../models/gamification_models.dart';

/// Виджет отображения ежедневных квестов
class DailyQuestsWidget extends StatelessWidget {
  final List<DailyQuest> quests;
  final Function(String questId)? onQuestTap;

  const DailyQuestsWidget({
    super.key,
    required this.quests,
    this.onQuestTap,
  });

  @override
  Widget build(BuildContext context) {
    if (quests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_turned_in, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Ежедневные задания',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Обновление через ${_getTimeUntilMidnight()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            ...quests.map((quest) => _buildQuestTile(context, quest)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestTile(BuildContext context, DailyQuest quest) {
    final isCompleted = quest.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isCompleted ? null : () => onQuestTap?.call(quest.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isCompleted ? AppColors.success : AppColors.grey300,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isCompleted
                ? AppColors.success.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : _getIconForQuestType(quest.type),
                      color: isCompleted ? AppColors.success : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quest.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quest.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Rewards
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 16, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(
                            '+${quest.xpReward}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '+${quest.coinsReward}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Прогресс: ${quest.currentValue}/${quest.targetValue}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${(quest.progress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? AppColors.success : AppColors.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: quest.progress,
                      backgroundColor: AppColors.grey200,
                      valueColor: AlwaysStoppedAnimation(
                        isCompleted ? AppColors.success : AppColors.primary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForQuestType(QuestType type) {
    switch (type) {
      case QuestType.answerQuestions:
        return Icons.quiz;
      case QuestType.completeTest:
        return Icons.assignment_turned_in;
      case QuestType.studyMinutes:
        return Icons.schedule;
      case QuestType.perfectAnswers:
        return Icons.emoji_events;
      case QuestType.specificTopic:
        return Icons.subject;
    }
  }

  String _getTimeUntilMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final difference = tomorrow.difference(now);

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    if (hours > 0) {
      return '$hours ч $minutes мин';
    } else {
      return '$minutes мин';
    }
  }
}

/// Компактный виджет квестов для показа на главной
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
    final completedCount = quests.where((q) => q.isCompleted).length;

    return InkWell(
      onTap: onViewAll,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.info.withOpacity(0.1),
              AppColors.info.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.info.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.info,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.assignment_turned_in,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ежедневные задания',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Выполнено: $completedCount/${quests.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              completedCount == quests.length
                  ? Icons.check_circle
                  : Icons.arrow_forward_ios,
              color: completedCount == quests.length
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
