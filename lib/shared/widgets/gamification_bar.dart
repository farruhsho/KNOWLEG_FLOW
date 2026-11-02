import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../models/gamification_models.dart';

/// Level, XP inside the level, cosmetic coins and the live streak. Values
/// come from server-owned `user_stats` via [UserGamification.fromStats].
class GamificationBar extends StatelessWidget {
  final UserGamification gamification;
  final VoidCallback? onTap;

  const GamificationBar({
    super.key,
    required this.gamification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final g = gamification;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll, side: BorderSide(color: t.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                    child: Text('${g.level}', style: theme.textTheme.titleLarge?.copyWith(color: t.xp)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.learnLevelN(g.level), style: theme.textTheme.titleMedium),
                        Text(
                          l.learnXpToNextLevel((g.xpToNextLevel - g.xp).clamp(0, 1 << 30), g.level + 1),
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (g.streakDays > 0) ...[
                    Icon(Icons.local_fire_department, size: 18, color: t.streak),
                    const SizedBox(width: AppSpacing.xxs),
                    Text('${g.streakDays}', style: theme.textTheme.labelLarge),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Icon(Icons.toll_outlined, size: 18, color: t.xp),
                  const SizedBox(width: AppSpacing.xxs),
                  Text('${g.coins}', style: theme.textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: g.levelProgress.clamp(0.0, 1.0),
                  minHeight: 6,
                  color: t.xp,
                  backgroundColor: t.surfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact variant for app bars.
class CompactGamificationInfo extends StatelessWidget {
  final UserGamification gamification;
  final VoidCallback? onTap;

  const CompactGamificationInfo({
    super.key,
    required this.gamification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: t.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${gamification.level}', style: theme.textTheme.labelLarge?.copyWith(color: t.xp)),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.toll_outlined, size: 16, color: t.xp),
            const SizedBox(width: AppSpacing.xxs),
            Text('${gamification.coins}', style: theme.textTheme.labelLarge),
            if (gamification.streakDays > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.local_fire_department, size: 16, color: t.streak),
              const SizedBox(width: AppSpacing.xxs),
              Text('${gamification.streakDays}', style: theme.textTheme.labelLarge),
            ],
          ],
        ),
      ),
    );
  }
}
