import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routes/admin_session.dart';
import '../features/admin/domain/admin_role.dart';
import 'auth_provider.dart';

/// Verified admin session. Single source of truth for admin authority on the
/// client is the resolved [AdminRole] (custom claim `role`, legacy
/// `users.role == 'admin'` → super_admin). The old `/admins/{uid}` collection
/// and `AdminGuard` (DEAD-01 / FB-28) are gone.
///
/// The server (Firestore rules + callables) re-checks every action; this state
/// only decides which screens and buttons the CMS shows.
class AdminSession {
  final String uid;
  final String? email;
  final AdminRole role;

  /// `true` when the role came from the legacy `users.role` field rather than
  /// a custom claim (shown as a hint in the UI).
  final bool fromLegacyField;

  const AdminSession({
    required this.uid,
    required this.role,
    this.email,
    this.fromLegacyField = false,
  });
}

class AdminSessionNotifier extends Notifier<AdminSession?> {
  @override
  AdminSession? build() {
    void onVerifiedChanged() {
      if (!adminVerified.value && state != null) state = null;
    }

    adminVerified.addListener(onVerifiedChanged);
    ref.onDispose(() => adminVerified.removeListener(onVerifiedChanged));

    // Another account signing in (or a sign-out through any code path) must
    // drop the admin session.
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
      final user = next.valueOrNull;
      final current = state;
      if (current == null || next.isLoading) return;
      if (user == null || user.uid != current.uid) clear();
    });
    return null;
  }

  void start(AdminSession session) {
    state = session;
    adminVerified.value = true;
  }

  void clear() {
    state = null;
    adminVerified.value = false;
  }
}

final adminSessionProvider =
    NotifierProvider<AdminSessionNotifier, AdminSession?>(AdminSessionNotifier.new);

/// The verified admin role, or `null` when no admin session is active.
final adminRoleProvider =
    Provider<AdminRole?>((ref) => ref.watch(adminSessionProvider)?.role);

/// Convenience: whether the current admin may perform [permission].
final adminCanProvider = Provider.family<bool, AdminPermission>(
  (ref, permission) => ref.watch(adminRoleProvider)?.can(permission) ?? false,
);
