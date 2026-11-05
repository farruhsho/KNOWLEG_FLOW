import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/user_stats_model.dart';
import '../../../../shared/services/gamification_service.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../data/achievement_config_provider.dart';
import '../../domain/achievement_catalog.dart';
import '../../domain/achievement_config.dart';
import '../widgets/stats_header.dart';

/// Achievements that can actually be earned: the server's achievement ids,
/// locked/unlocked from `user_stats.achievements` (GAM-18). Titles and
/// descriptions come from `config/achievements` when an admin edited them
/// (built-in strings otherwise); disabled ids are hidden (ARCHITECTURE §9.4).
class AchievementsPage extends ConsumerStatefulWidget {
  const AchievementsPage({super.key});

  @override
  ConsumerState<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends ConsumerState<AchievementsPage> {
  Stream<UserStats>? _stats;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _stats = uid == null ? null : GamificationService().watchStats(uid);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final stream = _stats;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.learnAchievementsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: l.learnLeaderboardTitle,
            onPressed: () => context.push(RoutePaths.leaderboard),
          ),
        ],
      ),
      body: stream == null
          ? EmptyView(
              icon: Icons.lock_outline,
              message: l.learnSignInToSave,
              action: FilledButton(onPressed: () => context.go(RoutePaths.login), child: Text(l.learnSignIn)),
            )
          : StreamBuilder<UserStats>(
              key: ValueKey(_attempt),
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ErrorView.forError(context, snap.error, onRetry: () {
                    setState(() {
                      _attempt++;
                      _subscribe();
                    });
                  });
                }
                if (!snap.hasData) return LoadingView(message: l.loading);
                return _content(context, l, snap.data!);
              },
            ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l, UserStats stats) {
    final gutter = AppSpacing.gutter(context);
    final config = ref.watch(achievementConfigProvider).valueOrNull ?? AchievementConfig.empty;
    final shown = config.visible(AchievementCatalog.all);
    final unlocked = shown.where((a) => stats.hasAchievement(a.id)).length;
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.xxxl),
      children: [
        StatsHeader(stats: stats),
        const SizedBox(height: AppSpacing.xl),
        Text(
          l.learnAchievementsUnlocked(unlocked, shown.length),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l.learnAchievementsServerNote, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        for (final a in shown) ...[
          _AchievementTile(def: a, stats: stats, config: config),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementDef def;
  final UserStats stats;
  final AchievementConfig config;
  const _AchievementTile({required this.def, required this.stats, required this.config});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = context.tokens;
    final done = stats.hasAchievement(def.id);
    final at = stats.achievements[def.id];
    final progress = done ? 1.0 : def.progress?.call(stats);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final lang = Localizations.localeOf(context).languageCode;
    final title = config.title(def, l, lang);
    final description = config.description(def, l, lang);
    return Semantics(
      label: '$title. ${done ? l.learnAchievementUnlocked : l.learnAchievementLocked}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadii.mdAll,
          border: Border.all(color: done ? t.xp : t.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? t.xpContainer : t.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(done ? def.icon : Icons.lock_outline, color: done ? t.xp : t.textTertiary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(description, style: theme.textTheme.bodySmall),
                  if (done && at != null)
                    Text(
                      l.learnAchievementUnlockedOn(DateFormat.yMMMd(locale).format(at.toLocal())),
                      style: theme.textTheme.labelSmall?.copyWith(color: t.xp),
                    )
                  else if (!done && progress != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: theme.colorScheme.primary,
                        backgroundColor: t.surfaceMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
