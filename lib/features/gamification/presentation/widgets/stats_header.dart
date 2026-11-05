import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/user_stats_model.dart';

/// Level, XP-in-level and live streak from server stats.
class StatsHeader extends StatelessWidget {
  final UserStats stats;
  const StatsHeader({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final p = stats.levelProgress;
    final streak = stats.liveStreak(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.xpContainer, borderRadius: AppRadii.smAll),
                child: Text('${stats.level}', style: theme.textTheme.titleLarge?.copyWith(color: t.xp)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.learnLevelN(stats.level), style: theme.textTheme.titleMedium),
                    Text(l.learnXpTotal(stats.xp), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.local_fire_department, color: streak > 0 ? t.streak : t.textTertiary, size: 20),
              const SizedBox(width: AppSpacing.xxs),
              Text(l.learnStreakDays(streak), style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: p.levelSize == 0 ? 0 : p.inLevel / p.levelSize,
              minHeight: 6,
              color: t.xp,
              backgroundColor: t.surfaceMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.learnXpToNextLevel(p.levelSize - p.inLevel, stats.level + 1),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
