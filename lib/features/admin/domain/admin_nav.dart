import '../../../core/routes/route_paths.dart';
import 'admin_role.dart';

/// Sections of the admin CMS and the role check that decides whether a role
/// may open each one. Pure Dart so the visibility rules are unit-tested; the
/// server (Firestore rules + callables) enforces the same matrix again.
enum AdminSection {
  dashboard('/admin/dashboard'),
  subjects('/admin/subjects'),
  lessons('/admin/lessons'),
  practiceQuestions('/admin/questions'),
  examBank('/admin/exam-bank'),
  variants('/admin/variants'),

  /// Fresh-variant pool health and settings (ARCHITECTURE §10.1).
  examPool(RoutePaths.adminExamPool),
  aiDrafts('/admin/ai-drafts'),
  users('/admin/users'),
  payments('/admin/payments'),
  pricing('/admin/pricing'),
  logs('/admin/logs'),

  // Phase 3 (ARCHITECTURE §9.2, §9.4).
  notifications(RoutePaths.adminNotifications),
  promoCodes(RoutePaths.adminPromoCodes),
  achievements(RoutePaths.adminAchievements);

  const AdminSection(this.path);

  /// Route path (always under `/admin`).
  final String path;

  /// Whether [role] may open this section.
  bool visibleTo(AdminRole role) {
    switch (this) {
      case AdminSection.dashboard:
        return role.can(AdminPermission.viewStats);
      case AdminSection.subjects:
      case AdminSection.lessons:
        return role.can(AdminPermission.editContent);
      case AdminSection.practiceQuestions:
      case AdminSection.examBank:
        return role.can(AdminPermission.editQuestions);
      case AdminSection.variants:
        // Methodologists may inspect variants; publishing itself needs
        // publish_variants (checked on the button and by the callable).
        return role.can(AdminPermission.publishVariants) ||
            role.can(AdminPermission.editQuestions);
      case AdminSection.examPool:
        // adminExamPoolHealth: super_admin, content_manager, methodologist.
        return role.canViewExamPool;
      case AdminSection.aiDrafts:
        return role.canDraftWithAi;
      case AdminSection.users:
        return role.can(AdminPermission.viewUsers);
      case AdminSection.payments:
        return role.can(AdminPermission.viewPayments);
      case AdminSection.pricing:
        return role.can(AdminPermission.managePricing);
      case AdminSection.logs:
        return role.canReadAdminLogs;
      case AdminSection.notifications:
        return role.can(AdminPermission.sendNotifications);
      case AdminSection.promoCodes:
        // Promo codes grant free credits: finance, super_admin only (§9.2).
        return role.can(AdminPermission.grantCredits);
      case AdminSection.achievements:
        return role.can(AdminPermission.manageAchievements);
    }
  }

  static List<AdminSection> visibleSections(AdminRole role) =>
      values.where((s) => s.visibleTo(role)).toList();

  /// The section a path belongs to (longest matching prefix), if any.
  static AdminSection? forPath(String path) {
    AdminSection? best;
    for (final s in values) {
      if (path == s.path || path.startsWith('${s.path}/')) {
        if (best == null || s.path.length > best.path.length) best = s;
      }
    }
    return best;
  }
}
