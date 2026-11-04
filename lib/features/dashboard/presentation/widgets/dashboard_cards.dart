import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../billing/domain/entitlements.dart';
import '../../../settings/data/reminder_settings.dart';
import '../../data/dashboard_providers.dart';
import '../../domain/dashboard_models.dart';

/// Flat bordered card used on the home screen.
class DashCard extends StatelessWidget {
  const DashCard({super.key, required this.child, this.color, this.padding});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );
  }
}

/// Placeholder while a card's data loads (no spinner storms).
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.surfaceMuted;
    Widget bar(double widthFactor) => FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: muted,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
        );
    return DashCard(
      child: Semantics(
        label: AppLocalizations.of(context)!.shellLoading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              bar(i == 0 ? 0.5 : (i.isEven ? 0.7 : 0.9)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardError extends StatelessWidget {
  const _CardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DashCard(
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: context.tokens.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.tokens.textSecondary),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l.shellRetry)),
        ],
      ),
    );
  }
}

/// Streak + today's XP goal from `user_stats/{uid}` (server data only).
class TodayCard extends ConsumerWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final stats = ref.watch(userStatsProvider);
    final goalMinutes = ref.watch(
      userModelProvider.select((v) => v.valueOrNull?.dailyGoalMinutes),
    );
    final now = ref.watch(dashboardClockProvider)();

    return stats.when(
      skipLoadingOnReload: true,
      loading: () => const _CardSkeleton(),
      error: (_, __) => _CardError(
        message: l.shellHomeStatsError,
        onRetry: () => ref.invalidate(userStatsProvider),
      ),
      data: (s) => (s == null || s.isEmpty)
          ? _TodayEmpty(goalMinutes: goalMinutes)
          : _TodayStats(stats: s, now: now, goalMinutes: goalMinutes),
    );
  }
}

class _TodayEmpty extends StatelessWidget {
  const _TodayEmpty({required this.goalMinutes});

  final int? goalMinutes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return DashCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department_outlined, color: tokens.streak, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.shellHomeEmptyStatsTitle, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.shellHomeEmptyStatsMessage,
                  style: text.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
                if (goalMinutes != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l.shellHomeGoalMinutes(goalMinutes!),
                    style: text.labelMedium?.copyWith(color: tokens.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({
    required this.stats,
    required this.now,
    required this.goalMinutes,
  });

  final UserStats stats;
  final DateTime now;
  final int? goalMinutes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final streak = stats.effectiveStreak(now);
    final todayXp = stats.effectiveTodayXp(now);
    final goalXp = stats.dailyGoalXp;
    final progress = goalXp > 0 ? (todayXp / goalXp).clamp(0.0, 1.0) : null;
    final goalReached = goalXp > 0 && todayXp >= goalXp;

    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                streak > 0
                    ? Icons.local_fire_department_rounded
                    : Icons.local_fire_department_outlined,
                color: tokens.streak,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  streak > 0 ? l.shellHomeStreakDays(streak) : l.shellHomeStreakNone,
                  style: text.titleMedium,
                ),
              ),
              if (stats.bestStreak > 0)
                Flexible(
                  child: Text(
                    l.shellHomeBestStreak(stats.bestStreak),
                    style: text.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            goalXp > 0
                ? l.shellHomeTodayXpOfGoal(todayXp, goalXp)
                : l.shellHomeTodayXp(todayXp),
            style: text.bodyMedium,
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: goalReached ? tokens.success : tokens.xp,
                backgroundColor: tokens.surfaceMuted,
                semanticsLabel: l.shellHomeDailyGoal,
              ),
            ),
          ],
          if (goalReached) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.shellHomeGoalReached,
              style: text.labelMedium?.copyWith(color: tokens.success),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            l.shellHomeLevelXp(stats.level, stats.xp),
            style: text.labelSmall,
          ),
          if (goalMinutes != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(l.shellHomeGoalMinutes(goalMinutes!), style: text.labelSmall),
          ],
        ],
      ),
    );
  }
}

/// Human name of a topic's area ('math.quadratic' → 'Математика').
String _areaName(
  String topicId,
  Map<String, Map<String, String>>? titles,
  String languageCode,
) {
  final area = topicArea(topicId);
  final byLang = titles?[area];
  final title = byLang?[languageCode] ?? byLang?['ru'];
  if (title != null && title.isNotEmpty) return title;
  return area.replaceAll('_', ' ');
}

/// Rule-based "Next step" recommendation.
class NextStepCard extends ConsumerWidget {
  const NextStepCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final step = ref.watch(nextStepProvider);
    return step.when(
      loading: () => const _CardSkeleton(lines: 2),
      error: (_, __) => _CardError(
        message: l.shellHomeNextStepError,
        onRetry: () {
          ref.invalidate(latestExamProvider);
          ref.invalidate(userStatsProvider);
        },
      ),
      data: (s) => _NextStepBody(step: s),
    );
  }
}

class _NextStepBody extends ConsumerWidget {
  const _NextStepBody({required this.step});

  final NextStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final String body;
    final String action;
    final VoidCallback onTap;
    switch (step.kind) {
      case NextStepKind.firstMock:
        final free = ref.watch(
          entitlementsProvider.select((v) => v.valueOrNull?.hasFreeExam ?? false),
        );
        body = free ? l.shellNextFirstMockFree : l.shellNextFirstMock;
        action = l.shellNextOpenExams;
        onTap = () => context.go(RoutePaths.exams);
      case NextStepKind.weakTopic:
        final titles = ref.watch(examAreaTitlesProvider).valueOrNull;
        final lang = ref.watch(localeProvider.select((x) => x.languageCode));
        body = l.shellNextWeakTopic(_areaName(step.topicId!, titles, lang));
        action = l.shellNextOpenLearn;
        onTap = () => context.go(RoutePaths.learn);
      case NextStepKind.practice:
        body = l.shellNextPractice;
        action = l.shellQuickTest;
        onTap = () => context.push(RoutePaths.quickTest);
    }

    return DashCard(
      color: scheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: scheme.onPrimaryContainer, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.shellNextStepTitle,
                  style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: text.bodyLarge?.copyWith(color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

/// Free test / credits status linking to the exams tab or the store.
class EntitlementChip extends ConsumerWidget {
  const EntitlementChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final ent = ref.watch(entitlementsProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget chip(IconData icon, String label, VoidCallback onTap) => Align(
          alignment: AlignmentDirectional.centerStart,
          child: ActionChip(
            avatar: Icon(icon, size: 18, color: scheme.primary),
            label: Text(label),
            onPressed: onTap,
          ),
        );

    return ent.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (_, __) => chip(
        Icons.refresh_rounded,
        l.shellHomeEntitlementError,
        () => ref.invalidate(entitlementsProvider),
      ),
      data: (e) {
        if (e.hasFreeExam) {
          return chip(Icons.card_giftcard_outlined, l.shellHomeFreeExam,
              () => context.go(RoutePaths.exams));
        }
        if (e.credits > 0) {
          return chip(Icons.confirmation_number_outlined,
              l.shellHomeCredits(e.credits), () => context.go(RoutePaths.exams));
        }
        return chip(Icons.shopping_bag_outlined, l.shellHomeBuyExam,
            () => context.push(RoutePaths.store));
      },
    );
  }
}

/// Offers the onboarding questionnaire to users who never filled it in.
class StudyProfilePromptCard extends ConsumerStatefulWidget {
  const StudyProfilePromptCard({super.key});

  @override
  ConsumerState<StudyProfilePromptCard> createState() =>
      _StudyProfilePromptCardState();
}

class _StudyProfilePromptCardState extends ConsumerState<StudyProfilePromptCard> {
  static const _dismissKey = 'home_study_profile_prompt_dismissed';
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _dismissed = ref.read(sharedPreferencesProvider).getBool(_dismissKey) ?? false;
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    ref.read(sharedPreferencesProvider).setBool(_dismissKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final needsSetup = ref.watch(userModelProvider.select(
      (v) => v.hasValue && v.value != null && !v.value!.hasStudyProfile,
    ));
    if (_dismissed || !needsSetup) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: _PromptCard(
        icon: Icons.tune_rounded,
        title: l.shellHomeSetupTitle,
        message: l.shellHomeSetupMessage,
        primaryLabel: l.shellHomeSetupAction,
        onPrimary: () => context.push(RoutePaths.onboarding),
        secondaryLabel: l.shellHide,
        onSecondary: _dismiss,
      ),
    );
  }
}

/// Asks for notification permission in context (GAM-13), not at start-up.
class ReminderPromptCard extends ConsumerStatefulWidget {
  const ReminderPromptCard({super.key});

  @override
  ConsumerState<ReminderPromptCard> createState() => _ReminderPromptCardState();
}

class _ReminderPromptCardState extends ConsumerState<ReminderPromptCard> {
  bool _hidden = false;
  bool _busy = false;

  Future<void> _enable() async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final result = await ref.read(reminderSettingsProvider).enable();
    if (!mounted) return;
    ref.invalidate(reminderEnabledProvider);
    setState(() {
      _busy = false;
      _hidden = result == ReminderEnableResult.enabled;
    });
    messenger.showSnackBar(SnackBar(content: Text(reminderResultText(l, result))));
  }

  Future<void> _later() async {
    setState(() => _hidden = true);
    await ref.read(reminderSettingsProvider).dismissPrompt();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(reminderSettingsProvider);
    if (_hidden || !settings.shouldPrompt) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: _PromptCard(
        icon: Icons.notifications_active_outlined,
        title: l.shellHomeReminderTitle,
        message: l.shellHomeReminderMessage,
        primaryLabel: l.shellHomeReminderEnable,
        onPrimary: _busy ? null : _enable,
        secondaryLabel: l.shellNotNow,
        onSecondary: _busy ? null : _later,
      ),
    );
  }
}

/// Localized feedback for turning reminders on.
String reminderResultText(AppLocalizations l, ReminderEnableResult result) {
  switch (result) {
    case ReminderEnableResult.enabled:
      return l.shellReminderEnabled;
    case ReminderEnableResult.permissionDenied:
      return l.shellReminderDenied;
    case ReminderEnableResult.unsupported:
      return l.shellReminderUnsupported;
    case ReminderEnableResult.failed:
      return l.shellReminderFailed;
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return DashCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.sm, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      message,
                      style: text.bodySmall?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
              TextButton(onPressed: onPrimary, child: Text(primaryLabel)),
            ],
          ),
        ],
      ),
    );
  }
}

/// One quick action on the home screen.
class QuickAction {
  const QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({super.key, required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: action.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: AppRadii.smAll,
                  ),
                  child: Icon(action.icon, size: 20, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  action.label,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
