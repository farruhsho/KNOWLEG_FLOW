/// Admin roles and permissions — ARCHITECTURE.md §2.
///
/// The role is carried by the Firebase Auth custom claim `role` (set only by
/// the `adminSetRole` callable). Backward compatibility: the legacy
/// `users/{uid}.role == 'admin'` field maps to [AdminRole.superAdmin].
///
/// This file is pure Dart (no Flutter / Firebase imports) so the matrix can be
/// unit-tested and mirrored exactly by the backend.
library;

/// A single capability from the permission matrix in ARCHITECTURE.md §2.
enum AdminPermission {
  manageRoles('manage_roles'),
  managePricing('manage_pricing'),
  grantCredits('grant_credits'),
  refund('refund'),
  viewPayments('view_payments'),
  editContent('edit_content'),
  editQuestions('edit_questions'),
  reviewQuestions('review_questions'),
  publishVariants('publish_variants'),
  manageFreeTests('manage_free_tests'),
  viewUsers('view_users'),
  moderateUsers('moderate_users'),
  sendNotifications('send_notifications'),
  manageAchievements('manage_achievements'),
  viewStats('view_stats');

  const AdminPermission(this.wire);

  /// snake_case name used in the architecture doc and by the backend.
  final String wire;

  static AdminPermission? fromWire(String? value) {
    for (final p in values) {
      if (p.wire == value) return p;
    }
    return null;
  }
}

/// Admin roles, in descending order of privilege.
enum AdminRole {
  superAdmin('super_admin'),
  contentManager('content_manager'),
  methodologist('methodologist'),
  moderator('moderator'),
  support('support');

  const AdminRole(this.wire);

  /// Value stored in the `role` custom claim and passed to `adminSetRole`.
  final String wire;

  /// Legacy value of `users/{uid}.role` that is treated as [superAdmin].
  static const String legacyAdmin = 'admin';

  /// Parses a claim or legacy field value. Returns `null` for anything that is
  /// not an admin role (e.g. `student`, empty, wrong type) — least privilege.
  static AdminRole? fromWire(Object? value) {
    if (value is! String) return null;
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == legacyAdmin) return AdminRole.superAdmin;
    for (final r in values) {
      if (r.wire == v) return r;
    }
    return null;
  }

  /// Permission matrix — must match ARCHITECTURE.md §2 exactly.
  static const Map<AdminRole, Set<AdminPermission>> matrix = {
    AdminRole.superAdmin: {
      AdminPermission.manageRoles,
      AdminPermission.managePricing,
      AdminPermission.grantCredits,
      AdminPermission.refund,
      AdminPermission.viewPayments,
      AdminPermission.editContent,
      AdminPermission.editQuestions,
      AdminPermission.reviewQuestions,
      AdminPermission.publishVariants,
      AdminPermission.manageFreeTests,
      AdminPermission.viewUsers,
      AdminPermission.moderateUsers,
      AdminPermission.sendNotifications,
      AdminPermission.manageAchievements,
      AdminPermission.viewStats,
    },
    AdminRole.contentManager: {
      AdminPermission.editContent,
      AdminPermission.editQuestions,
      AdminPermission.publishVariants,
      AdminPermission.manageFreeTests,
      AdminPermission.sendNotifications,
      AdminPermission.manageAchievements,
      AdminPermission.viewStats,
    },
    AdminRole.methodologist: {
      AdminPermission.editContent,
      AdminPermission.editQuestions,
      AdminPermission.reviewQuestions,
      AdminPermission.viewStats,
    },
    AdminRole.moderator: {
      AdminPermission.viewUsers,
      AdminPermission.moderateUsers,
      AdminPermission.viewStats,
    },
    AdminRole.support: {
      AdminPermission.viewPayments,
      AdminPermission.viewUsers,
      AdminPermission.viewStats,
    },
  };

  Set<AdminPermission> get permissions => matrix[this] ?? const {};

  bool can(AdminPermission permission) => permissions.contains(permission);

  /// `admin_logs` readers per ARCHITECTURE.md §1 (not part of the §2 matrix).
  bool get canReadAdminLogs =>
      this == AdminRole.superAdmin || this == AdminRole.support;

  /// Roles that may call `adminAiDraftQuestions` (§3) — the same set as
  /// [AdminPermission.editQuestions].
  bool get canDraftWithAi => can(AdminPermission.editQuestions);
}

/// Resolves the effective admin role after sign-in.
///
/// 1. The custom claim `role` (authoritative, set by `adminSetRole`).
/// 2. Fallback: legacy `users/{uid}.role == 'admin'` → [AdminRole.superAdmin].
///    Only the literal legacy value is honoured from the user document; new
///    role names are trusted only from the signed token.
AdminRole? resolveAdminRole({Object? claimRole, Object? legacyUserRole}) {
  final fromClaim = AdminRole.fromWire(claimRole);
  if (fromClaim != null) return fromClaim;
  if (legacyUserRole is String &&
      legacyUserRole.trim().toLowerCase() == AdminRole.legacyAdmin) {
    return AdminRole.superAdmin;
  }
  return null;
}
