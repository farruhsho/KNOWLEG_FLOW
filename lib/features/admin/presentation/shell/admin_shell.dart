import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/admin_access_provider.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_auth_service.dart';
import '../../domain/admin_nav.dart';
import '../../domain/admin_role.dart';
import '../widgets/admin_widgets.dart';

String adminSectionLabel(AppLocalizations l, AdminSection s) => switch (s) {
      AdminSection.dashboard => l.adminNavDashboard,
      AdminSection.subjects => l.adminNavSubjects,
      AdminSection.lessons => l.adminNavLessons,
      AdminSection.practiceQuestions => l.adminNavPractice,
      AdminSection.examBank => l.adminNavExamBank,
      AdminSection.variants => l.adminNavVariants,
      AdminSection.examPool => l.adminNavExamPool,
      AdminSection.aiDrafts => l.adminNavAiDrafts,
      AdminSection.users => l.adminNavUsers,
      AdminSection.payments => l.adminNavPayments,
      AdminSection.pricing => l.adminNavPricing,
      AdminSection.logs => l.adminNavLogs,
      AdminSection.notifications => l.adminNavNotifications,
      AdminSection.promoCodes => l.adminNavPromoCodes,
      AdminSection.achievements => l.adminNavAchievements,
    };

IconData adminSectionIcon(AdminSection s) => switch (s) {
      AdminSection.dashboard => Icons.space_dashboard_outlined,
      AdminSection.subjects => Icons.category_outlined,
      AdminSection.lessons => Icons.menu_book_outlined,
      AdminSection.practiceQuestions => Icons.quiz_outlined,
      AdminSection.examBank => Icons.fact_check_outlined,
      AdminSection.variants => Icons.view_list_outlined,
      AdminSection.examPool => Icons.shuffle_outlined,
      AdminSection.aiDrafts => Icons.auto_awesome_outlined,
      AdminSection.users => Icons.people_outline,
      AdminSection.payments => Icons.receipt_long_outlined,
      AdminSection.pricing => Icons.sell_outlined,
      AdminSection.logs => Icons.history_outlined,
      AdminSection.notifications => Icons.campaign_outlined,
      AdminSection.promoCodes => Icons.confirmation_number_outlined,
      AdminSection.achievements => Icons.emoji_events_outlined,
    };

String adminRoleLabel(AppLocalizations l, AdminRole r) => switch (r) {
      AdminRole.superAdmin => l.adminRoleSuperAdmin,
      AdminRole.contentManager => l.adminRoleContentManager,
      AdminRole.methodologist => l.adminRoleMethodologist,
      AdminRole.moderator => l.adminRoleModerator,
      AdminRole.support => l.adminRoleSupport,
    };

/// Marks widgets rendered inside [AdminShell] (pages reached through a legacy
/// route outside the shell wrap themselves in it).
class AdminShellScope extends InheritedWidget {
  const AdminShellScope({super.key, required super.child});

  static bool isInside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AdminShellScope>() != null;

  @override
  bool updateShouldNotify(AdminShellScope oldWidget) => false;
}

/// One shell for the whole CMS: permanent sidebar on wide screens, drawer on
/// phones; destinations filtered by the admin role.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final role = ref.watch(adminRoleProvider);
    if (role == null) {
      return Scaffold(
        body: AdminMessageView(
          icon: Icons.lock_clock_outlined,
          title: l.adminSessionExpiredTitle,
          message: l.adminSessionExpiredBody,
          action: FilledButton(
            onPressed: () => context.go(RoutePaths.adminLogin),
            child: Text(l.adminSignInAgain),
          ),
        ),
      );
    }
    final current = AdminSection.forPath(location) ?? AdminSection.dashboard;
    final appCheckNotice = ref.watch(adminAppCheckNoticeProvider);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      final nav = _AdminNav(
          role: role, current: current, closeOnTap: !wide, appCheckNotice: appCheckNotice);
      return Scaffold(
        appBar: AppBar(
          title: Text(adminSectionLabel(l, current), overflow: TextOverflow.ellipsis),
          actions: [_AccountMenu(role: role)],
        ),
        drawer: wide ? null : Drawer(child: nav),
        body: AdminShellScope(
          child: wide
              ? Row(
                  children: [
                    SizedBox(width: 264, child: nav),
                    VerticalDivider(width: 1, color: context.tokens.border),
                    Expanded(child: child),
                  ],
                )
              : child,
        ),
      );
    });
  }
}

class _AdminNav extends StatelessWidget {
  const _AdminNav({
    required this.role,
    required this.current,
    required this.closeOnTap,
    required this.appCheckNotice,
  });
  final AdminRole role;
  final AdminSection current;
  final bool closeOnTap;

  /// The backend enforces App Check on admin callables and this platform has
  /// none ([adminAppCheckNoticeProvider]): they will be rejected.
  final bool appCheckNotice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.adminAppTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                AdminPill(adminRoleLabel(l, role), tone: AdminTone.info),
                if (appCheckNotice) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: context.tokens.warning),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          l.adminAppCheckPlatformNote,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: context.tokens.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          for (final s in AdminSection.visibleSections(role))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
              child: ListTile(
                dense: true,
                selected: s == current,
                selectedTileColor: scheme.secondaryContainer,
                selectedColor: scheme.onSecondaryContainer,
                shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
                leading: Icon(adminSectionIcon(s)),
                title: Text(adminSectionLabel(l, s), overflow: TextOverflow.ellipsis),
                onTap: () {
                  if (closeOnTap) Navigator.of(context).maybePop();
                  if (s != current) context.go(s.path);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.role});
  final AdminRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final email = ref.watch(adminSessionProvider.select((s) => s?.email)) ?? '';
    return PopupMenuButton<String>(
      tooltip: l.adminAccountMenu,
      icon: const Icon(Icons.account_circle_outlined),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(email, overflow: TextOverflow.ellipsis),
              Text(adminRoleLabel(l, role), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(l.adminLogout),
          ),
        ),
      ],
      onSelected: (v) async {
        if (v != 'logout') return;
        final router = GoRouter.of(context);
        await ref.read(adminAuthServiceProvider).signOut();
        router.go(RoutePaths.adminLogin);
      },
    );
  }
}

/// Shows [child] only when the current admin role may open [section].
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key, required this.section, required this.child, this.standalone = false});
  final AdminSection section;
  final Widget child;

  /// `true` for full-screen routes outside the shell: the forbidden view then
  /// brings its own Scaffold with a back button.
  final bool standalone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(adminRoleProvider);
    if (role != null && section.visibleTo(role)) return child;
    return standalone
        ? Scaffold(appBar: AppBar(), body: const AdminForbiddenView())
        : const AdminForbiddenView();
  }
}
