import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/admin/domain/admin_nav.dart';
import 'package:knowledge_flow/features/admin/domain/admin_role.dart';
import 'package:knowledge_flow/features/admin/domain/review_workflow.dart';

/// ARCHITECTURE.md §2 — the permission matrix, transcribed row by row
/// (✓ columns: super_admin, content_manager, methodologist, moderator, support).
const Map<String, List<bool>> kDocMatrix = {
  'manage_roles': [true, false, false, false, false],
  'manage_pricing': [true, false, false, false, false],
  'grant_credits': [true, false, false, false, false],
  'refund': [true, false, false, false, false],
  'view_payments': [true, false, false, false, true],
  'edit_content': [true, true, true, false, false],
  'edit_questions': [true, true, true, false, false],
  'review_questions': [true, false, true, false, false],
  'publish_variants': [true, true, false, false, false],
  'manage_free_tests': [true, true, false, false, false],
  'view_users': [true, false, false, true, true],
  'moderate_users': [true, false, false, true, false],
  'send_notifications': [true, true, false, false, false],
  'manage_achievements': [true, true, false, false, false],
  'view_stats': [true, true, true, true, true],
};

const kRoleOrder = [
  AdminRole.superAdmin,
  AdminRole.contentManager,
  AdminRole.methodologist,
  AdminRole.moderator,
  AdminRole.support,
];

void main() {
  group('permission matrix (ARCHITECTURE.md §2)', () {
    test('every documented permission exists, and nothing else', () {
      expect(AdminPermission.values.map((p) => p.wire).toSet(), kDocMatrix.keys.toSet());
    });

    for (final entry in kDocMatrix.entries) {
      test(entry.key, () {
        final p = AdminPermission.fromWire(entry.key)!;
        for (var i = 0; i < kRoleOrder.length; i++) {
          expect(kRoleOrder[i].can(p), entry.value[i],
              reason: '${kRoleOrder[i].wire} / ${entry.key}');
        }
      });
    }
  });

  group('role parsing', () {
    test('wire values', () {
      expect(AdminRole.fromWire('super_admin'), AdminRole.superAdmin);
      expect(AdminRole.fromWire('content_manager'), AdminRole.contentManager);
      expect(AdminRole.fromWire('methodologist'), AdminRole.methodologist);
      expect(AdminRole.fromWire('moderator'), AdminRole.moderator);
      expect(AdminRole.fromWire('support'), AdminRole.support);
      expect(AdminRole.fromWire(' Support '), AdminRole.support);
    });

    test("legacy 'admin' maps to super_admin", () {
      expect(AdminRole.fromWire('admin'), AdminRole.superAdmin);
    });

    test('non-admin values are rejected (least privilege)', () {
      for (final v in [null, '', 'student', 'user', 'superadmin', 42, true, const ['admin']]) {
        expect(AdminRole.fromWire(v), isNull, reason: '$v');
      }
    });

    test('resolveAdminRole prefers the custom claim', () {
      expect(resolveAdminRole(claimRole: 'support', legacyUserRole: 'admin'), AdminRole.support);
      expect(resolveAdminRole(claimRole: 'methodologist'), AdminRole.methodologist);
    });

    test('resolveAdminRole falls back to users.role == admin only', () {
      expect(resolveAdminRole(claimRole: null, legacyUserRole: 'admin'), AdminRole.superAdmin);
      expect(resolveAdminRole(claimRole: 'student', legacyUserRole: 'admin'), AdminRole.superAdmin);
      // New role names are trusted only from the signed token, never from the
      // (historically client-writable) user document.
      expect(resolveAdminRole(claimRole: null, legacyUserRole: 'super_admin'), isNull);
      expect(resolveAdminRole(claimRole: null, legacyUserRole: 'student'), isNull);
      expect(resolveAdminRole(), isNull);
    });

    test('admin_logs readers', () {
      expect(AdminRole.superAdmin.canReadAdminLogs, isTrue);
      expect(AdminRole.support.canReadAdminLogs, isTrue);
      expect(AdminRole.contentManager.canReadAdminLogs, isFalse);
      expect(AdminRole.methodologist.canReadAdminLogs, isFalse);
      expect(AdminRole.moderator.canReadAdminLogs, isFalse);
    });

    test('AI drafts: super_admin, content_manager, methodologist', () {
      expect(kRoleOrder.where((r) => r.canDraftWithAi).toList(),
          [AdminRole.superAdmin, AdminRole.contentManager, AdminRole.methodologist]);
    });
  });

  group('CMS navigation', () {
    Set<AdminSection> sections(AdminRole r) => AdminSection.visibleSections(r).toSet();

    test('super_admin sees everything', () {
      expect(sections(AdminRole.superAdmin), AdminSection.values.toSet());
    });

    test('support: dashboard, users, payments, logs', () {
      expect(sections(AdminRole.support), {
        AdminSection.dashboard,
        AdminSection.users,
        AdminSection.payments,
        AdminSection.logs,
      });
    });

    test('moderator: dashboard and users only', () {
      expect(sections(AdminRole.moderator), {AdminSection.dashboard, AdminSection.users});
    });

    test('content roles never see payments, pricing or logs', () {
      for (final r in [AdminRole.contentManager, AdminRole.methodologist]) {
        final s = sections(r);
        expect(s.contains(AdminSection.payments), isFalse);
        expect(s.contains(AdminSection.pricing), isFalse);
        expect(s.contains(AdminSection.logs), isFalse);
        expect(s.contains(AdminSection.users), isFalse);
        expect(s.containsAll([AdminSection.examBank, AdminSection.lessons, AdminSection.aiDrafts]), isTrue);
      }
    });

    test('every section path is under /admin and resolves back', () {
      for (final s in AdminSection.values) {
        expect(s.path.startsWith('/admin/'), isTrue);
        expect(AdminSection.forPath(s.path), s);
      }
      expect(AdminSection.forPath('/admin/exam-bank/q1'), AdminSection.examBank);
      expect(AdminSection.forPath('/admin/lessons/new'), AdminSection.lessons);
      expect(AdminSection.forPath('/home'), isNull);
    });
  });

  group('review workflow', () {
    test('only review_questions roles can approve or reject', () {
      for (final r in kRoleOrder) {
        final targets = ReviewWorkflow.allowedTargets(ReviewStatus.aiVerified, r);
        final canApprove = targets.contains(ReviewStatus.methodologistApproved);
        expect(canApprove, r.can(AdminPermission.reviewQuestions), reason: r.wire);
        expect(targets.contains(ReviewStatus.rejected), r.can(AdminPermission.reviewQuestions));
      }
    });

    test('content_manager moves draft <-> ai_verified only', () {
      const cm = AdminRole.contentManager;
      expect(ReviewWorkflow.allowedTargets(ReviewStatus.draft, cm), [ReviewStatus.aiVerified]);
      expect(ReviewWorkflow.allowedTargets(ReviewStatus.aiVerified, cm), [ReviewStatus.draft]);
      expect(ReviewWorkflow.allowedTargets(ReviewStatus.methodologistApproved, cm), isEmpty);
    });

    test('roles without edit_questions cannot change review status', () {
      expect(ReviewWorkflow.allowedTargets(ReviewStatus.draft, AdminRole.support), isEmpty);
      expect(ReviewWorkflow.allowedTargets(ReviewStatus.draft, AdminRole.moderator), isEmpty);
    });

    test('a content edit by a non-reviewer resets approval to draft', () {
      expect(
        ReviewWorkflow.statusAfterContentEdit(ReviewStatus.methodologistApproved, AdminRole.contentManager),
        ReviewStatus.draft,
      );
      expect(
        ReviewWorkflow.statusAfterContentEdit(ReviewStatus.methodologistApproved, AdminRole.methodologist),
        ReviewStatus.methodologistApproved,
      );
    });

    test('unknown review status parses as draft', () {
      expect(ReviewStatus.parse(null), ReviewStatus.draft);
      expect(ReviewStatus.parse('whatever'), ReviewStatus.draft);
      expect(ReviewStatus.parse('methodologist_approved'), ReviewStatus.methodologistApproved);
    });
  });
}
