import 'package:flutter/material.dart';
import '../models/achievement_model.dart';
import '../../core/theme/app_colors.dart';

/// Achievement card widget for displaying individual achievements
class AchievementCard extends StatelessWidget {
  final AchievementModel achievement;

  const AchievementCard({
    super.key,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: achievement.isUnlocked ? 4 : 1,
        color: achievement.isUnlocked ? AppColors.white : AppColors.grey100,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: achievement.isUnlocked
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.grey200,
                ),
                child: Center(
                  child: Text(
                    achievement.icon,
                    style: TextStyle(
                      fontSize: 32,
                      color: achievement.isUnlocked ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                achievement.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: achievement.isUnlocked ? null : Colors.grey,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Description
              Text(
                achievement.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: achievement.isUnlocked
                          ? AppColors.grey600
                          : Colors.grey,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Progress bar (if not unlocked)
              if (!achievement.isUnlocked) ...[
                LinearProgressIndicator(
                  value: achievement.progressPercentage,
                  backgroundColor: AppColors.grey200,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 4,
                ),
                const SizedBox(height: 4),
                Text(
                  '${achievement.currentProgress}/${achievement.requiredValue}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey600,
                      ),
                ),
              ],

              // Unlocked badge
              if (achievement.isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Получено',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
