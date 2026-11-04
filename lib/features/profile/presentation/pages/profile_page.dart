import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/widgets/email_verification_banner.dart';
import '../../../dashboard/data/dashboard_providers.dart';
import '../../../dashboard/domain/dashboard_models.dart';
import '../../../onboarding/presentation/pages/onboarding_page.dart'
    show gradeLabel;
import '../widgets/profile_edit_sheet.dart';

/// Profile tab: real profile data, editing, account links and sign-out.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final profile = ref.watch(userModelProvider);
    final gutter = AppSpacing.gutter(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.shellNavProfile),
        actions: [
          IconButton(
            tooltip: l.shellSettingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(RoutePaths.settings),
          ),
        ],
      ),
      body: profile.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ProfileError(
          onRetry: () => ref.invalidate(userModelProvider),
        ),
        data: (user) => ListView(
          padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.xxxl),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: AppSpacing.md),
            const EmailVerificationBanner(),
            const SizedBox(height: AppSpacing.md),
            const _StatsRow(),
            const SizedBox(height: AppSpacing.md),
            _GoalCard(user: user),
            const SizedBox(height: AppSpacing.xl),
            const _AccountLinks(),
          ],
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.gutter(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: context.tokens.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(l.shellProfileLoadError, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: Text(l.shellRetry)),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : (authUser?.displayName ?? '');
    final email = (user?.email.isNotEmpty ?? false) ? user!.email : (authUser?.email ?? '');

    final facts = <String>[
      if (user != null) gradeLabel(l, user!.grade),
      if (user?.region != null) user!.region!.oblast,
      if (user?.school != null && user!.school!.trim().isNotEmpty) user!.school!.trim(),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: text.headlineSmall?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? l.shellProfileNoName : name,
                        style: text.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (facts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final f in facts)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(f, style: text.labelMedium),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => showProfileEditSheet(context, user),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(user == null ? l.shellProfileComplete : l.shellProfileEdit),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final stats = ref.watch(userStatsProvider);
    final now = ref.watch(dashboardClockProvider)();

    return stats.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox(height: AppSpacing.minTouch),
      error: (_, __) => Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_rounded),
          title: Text(l.shellHomeStatsError),
          trailing: TextButton(
            onPressed: () => ref.invalidate(userStatsProvider),
            child: Text(l.shellRetry),
          ),
        ),
      ),
      data: (s) {
        final value = s ?? const UserStats();
        return Row(
          children: [
            Expanded(child: _Stat(label: l.shellProfileLevel, value: '${value.level}')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _Stat(label: 'XP', value: '${value.xp}')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Stat(
                label: l.shellProfileStreak,
                value: '${value.effectiveStreak(now)}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Stat(
                label: l.shellProfileExams,
                value: '${value.examsCompleted}',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: text.titleLarge),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: text.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final u = user;
    final rows = <(IconData, String, String)>[
      (Icons.flag_outlined, l.shellProfileGoal, u?.goalBand ?? l.shellGoalUnsure),
      (
        Icons.timer_outlined,
        l.shellProfileDailyGoal,
        u?.dailyGoalMinutes == null
            ? l.shellNotSet
            : l.shellDailyMinutes(u!.dailyGoalMinutes!),
      ),
      (
        Icons.account_balance_outlined,
        l.shellOnbUniversityLabel,
        (u?.targetUniversities.isNotEmpty ?? false)
            ? u!.targetUniversities.join(', ')
            : l.shellNotSet,
      ),
      (
        Icons.translate_rounded,
        l.shellProfileExamLanguage,
        u?.preferredLanguage == 'ky' ? l.shellLangKyNative : l.shellLangRuNative,
      ),
    ];
    return Card(
      child: Column(
        children: [
          for (final (icon, label, value) in rows)
            ListTile(
              leading: Icon(icon),
              title: Text(label, style: text.bodySmall),
              subtitle: Text(value, style: text.titleSmall),
              dense: true,
            ),
        ],
      ),
    );
  }
}

class _AccountLinks extends ConsumerWidget {
  const _AccountLinks();

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.shellSignOutTitle),
        content: Text(l.shellSignOutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.shellCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.shellSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (_) {}
    // The router's auth guard also redirects; go() makes it immediate.
    if (context.mounted) context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final danger = context.tokens.danger;
    Widget tile(IconData icon, String title, VoidCallback onTap, {Color? color}) =>
        ListTile(
          leading: Icon(icon, color: color),
          title: Text(title, style: color == null ? null : TextStyle(color: color)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            children: [
              tile(Icons.emoji_events_outlined, l.shellProfileAchievements,
                  () => context.push(RoutePaths.achievements)),
              const Divider(height: 1),
              tile(Icons.receipt_long_outlined, l.shellProfileTransactions,
                  () => context.push(RoutePaths.transactions)),
              const Divider(height: 1),
              tile(Icons.settings_outlined, l.shellSettingsTitle,
                  () => context.push(RoutePaths.settings)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Column(
            children: [
              tile(Icons.logout_rounded, l.shellSignOut, () => _signOut(context, ref)),
              const Divider(height: 1),
              tile(Icons.delete_outline_rounded, l.shellProfileDeleteAccount,
                  () => context.push(RoutePaths.accountDelete),
                  color: danger),
            ],
          ),
        ),
      ],
    );
  }
}
