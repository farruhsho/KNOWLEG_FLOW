import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/admin_access_provider.dart';
import '../../application/admin_providers.dart';
import '../../data/repositories/people_repositories.dart';
import '../../domain/admin_nav.dart';
import '../../domain/admin_role.dart';
import '../shell/admin_shell.dart';
import '../widgets/admin_widgets.dart';

/// CMS home: real counters from `count()` aggregations (FB-17 / CMS-02) and
/// shortcuts to the sections the role may open.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reached through a legacy route outside the shell: wrap ourselves.
    if (!AdminShellScope.isInside(context)) {
      return AdminShell(location: AdminSection.dashboard.path, child: const AdminDashboardPage());
    }
    final l = AppLocalizations.of(context)!;
    final role = ref.watch(adminRoleProvider);
    if (role == null) return const AdminForbiddenView();
    final stats = _statsFor(role);
    return AdminPageBody(
      children: [
        Text(l.adminDashboardWelcome(adminRoleLabel(l, role)),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [for (final s in stats) _StatTile(stat: s)],
        ),
        const SizedBox(height: AppSpacing.xxl),
        AdminCard(
          title: l.adminDashboardShortcuts,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in AdminSection.visibleSections(role))
                if (s != AdminSection.dashboard)
                  ActionChip(
                    avatar: Icon(adminSectionIcon(s), size: 18),
                    label: Text(adminSectionLabel(l, s)),
                    onPressed: () => context.go(s.path),
                  ),
            ],
          ),
        ),
        if (role.can(AdminPermission.reviewQuestions))
          AdminCard(
            title: l.adminDashboardReviewTitle,
            child: Text(l.adminDashboardReviewBody),
          ),
      ],
    );
  }

  static List<AdminStat> _statsFor(AdminRole role) => [
        if (role.can(AdminPermission.viewUsers)) AdminStat.users,
        if (role.can(AdminPermission.editContent)) ...[AdminStat.subjects, AdminStat.lessons],
        if (role.can(AdminPermission.editQuestions)) ...[
          AdminStat.practiceQuestions,
          AdminStat.examQuestions,
          AdminStat.examPendingReview,
          AdminStat.examApproved,
        ],
        AdminStat.publishedVariants,
        if (role.can(AdminPermission.viewPayments)) AdminStat.grantedPurchases,
      ];
}

String _statLabel(AppLocalizations l, AdminStat s) => switch (s) {
      AdminStat.users => l.adminStatUsers,
      AdminStat.subjects => l.adminStatSubjects,
      AdminStat.lessons => l.adminStatLessons,
      AdminStat.practiceQuestions => l.adminStatPractice,
      AdminStat.examQuestions => l.adminStatExam,
      AdminStat.examPendingReview => l.adminStatPendingReview,
      AdminStat.examApproved => l.adminStatApproved,
      AdminStat.publishedVariants => l.adminStatVariants,
      AdminStat.grantedPurchases => l.adminStatPurchases,
    };

class _StatTile extends ConsumerWidget {
  const _StatTile({required this.stat});
  final AdminStat stat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final value = ref.watch(adminStatProvider(stat));
    final width = MediaQuery.sizeOf(context).width < 520 ? double.infinity : 210.0;
    return SizedBox(
      width: width,
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_statLabel(l, stat),
                style: text.bodySmall?.copyWith(color: context.tokens.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            value.when(
              data: (n) => Text('$n', style: text.headlineSmall),
              loading: () => const SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
              error: (e, _) => Row(
                children: [
                  Text('—', style: text.headlineSmall),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Tooltip(
                      message: adminErrorMessage(l, e),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: l.adminRetry,
                        onPressed: () => ref.invalidate(adminStatProvider(stat)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
