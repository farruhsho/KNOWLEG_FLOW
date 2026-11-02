import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/shared/models/user_model.dart';

/// Security guard for SEC-002/SEC-003. The admin role is provisioned
/// server-side and must NEVER be writable by the client. These tests pin two
/// invariants the router admin-gate and firestore.rules depend on:
///   1. a user with no role parses as 'student' (least privilege by default);
///   2. UserModel.toFirestore() never serialises `role`, so a client write can
///      not create or escalate an admin.
void main() {
  UserModel base() => UserModel(
        uid: 'u1',
        name: 'Test',
        email: 't@example.com',
        grade: 11,
        preferredLanguage: 'ru',
        subscription: const SubscriptionModel(),
        linkedAccounts: const LinkedAccounts(),
        createdAt: DateTime(2026, 1, 1),
        lastActive: DateTime(2026, 1, 1),
      );

  group('UserModel role security invariants', () {
    test('defaults to student when no role is provided', () {
      expect(base().role, 'student');
    });

    test('toFirestore() never serialises role (client must not write it)', () {
      final admin = base().copyWith(role: 'admin');
      expect(admin.role, 'admin');
      expect(admin.toFirestore().containsKey('role'), isFalse);
    });

    test('copyWith preserves role across other edits', () {
      final admin = base().copyWith(role: 'admin');
      expect(admin.copyWith(name: 'Renamed').role, 'admin');
    });
  });
}
