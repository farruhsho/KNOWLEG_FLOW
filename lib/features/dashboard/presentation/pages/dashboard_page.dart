import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../auth/presentation/widgets/email_verification_banner.dart';
import '../../data/dashboard_providers.dart';
import '../widgets/dashboard_cards.dart';

/// Home tab (GAM-07 / UI-07): real data only, honest empty states.
///
/// Every card is its own small consumer so a change in one source (stats,
/// entitlements, latest exam) rebuilds only that card.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  /// Re-subscribes the home data sources and waits (bounded) for their
  /// first fresh value, so the pull-to-refresh indicator reflects real work.
  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(userStatsProvider);
    ref.invalidate(latestExamProvider);
    ref.invalidate(userModelProvider);
    try {
      await Future.wait<Object?>([
        ref.read(userStatsProvider.future),
        ref.read(latestExamProvider.future),
      ]).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Errors are shown by the cards themselves (with retry).
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gutter = AppSpacing.gutter(context);
    final banner = ref.watch(examResumeBannerBuilderProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, AppSpacing.lg, gutter, AppSpacing.xxxl),
            children: [
              const _Greeting(),
              const SizedBox(height: AppSpacing.lg),
              banner(),
              const EmailVerificationBanner(),
              const SizedBox(height: AppSpacing.md),
              const TodayCard(),
              const SizedBox(height: AppSpacing.md),
              const NextStepCard(),
              const SizedBox(height: AppSpacing.md),
              const EntitlementChip(),
              const StudyProfilePromptCard(),
              const ReminderPromptCard(),
              const SizedBox(height: AppSpacing.xl),
              const _QuickActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final profileName =
        ref.watch(userModelProvider.select((v) => v.valueOrNull?.name));
    final authName = ref.watch(
      authStateProvider.select((v) => v.valueOrNull?.displayName),
    );
    final name = _firstName(profileName) ?? _firstName(authName);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null ? l.shellHomeGreeting : l.shellHomeGreetingName(name),
                style: text.headlineSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l.shellHomeSubtitle,
                style: text.bodyMedium?.copyWith(color: context.tokens.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Semantics(
          button: true,
          label: l.shellNavProfile,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go(RoutePaths.profile),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                (name ?? '').isEmpty ? '?' : name!.characters.first.toUpperCase(),
                style: text.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String? _firstName(String? full) {
    final trimmed = full?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final actions = <QuickAction>[
      QuickAction(
        icon: Icons.assignment_outlined,
        label: l.shellQuickMockExam,
        onTap: () => context.go(RoutePaths.exams),
      ),
      QuickAction(
        icon: Icons.bolt_outlined,
        label: l.shellQuickTest,
        onTap: () => context.push(RoutePaths.quickTest),
      ),
      QuickAction(
        icon: Icons.today_outlined,
        label: l.shellQuickDailyLesson,
        onTap: () => context.push(RoutePaths.dailyLesson),
      ),
      QuickAction(
        icon: Icons.forum_outlined,
        label: l.shellQuickTutor,
        onTap: () => context.push(RoutePaths.tutor),
      ),
      QuickAction(
        icon: Icons.leaderboard_outlined,
        label: l.shellQuickLeaderboard,
        onTap: () => context.push(RoutePaths.leaderboard),
      ),
      QuickAction(
        icon: Icons.menu_book_outlined,
        label: l.shellQuickHandbook,
        onTap: () => context.push(AppRouter.handbookIndex),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.shellQuickTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            final width = (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final action in actions)
                  SizedBox(width: width, child: QuickActionTile(action: action)),
              ],
            );
          },
        ),
      ],
    );
  }
}
