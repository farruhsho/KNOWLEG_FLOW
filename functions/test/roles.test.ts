import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  CONTENT_ROLES,
  hasPermission,
  legacyUserRoleFor,
  PERMISSION_MATRIX,
  PERMISSIONS,
  permissionsFor,
  resolveRole,
  ROLES,
  type Permission,
  type Role,
} from '../src/domain/roles';

// ARCHITECTURE §2, transcribed row by row (super_admin, content_manager,
// methodologist, moderator, support).
const TABLE: Record<Permission, [boolean, boolean, boolean, boolean, boolean]> = {
  manage_roles: [true, false, false, false, false],
  manage_pricing: [true, false, false, false, false],
  grant_credits: [true, false, false, false, false],
  refund: [true, false, false, false, false],
  view_payments: [true, false, false, false, true],
  edit_content: [true, true, true, false, false],
  edit_questions: [true, true, true, false, false],
  review_questions: [true, false, true, false, false],
  publish_variants: [true, true, false, false, false],
  manage_free_tests: [true, true, false, false, false],
  view_users: [true, false, false, true, true],
  moderate_users: [true, false, false, true, false],
  send_notifications: [true, true, false, false, false],
  manage_achievements: [true, true, false, false, false],
  view_stats: [true, true, true, true, true],
};

describe('permission matrix', () => {
  it('matches ARCHITECTURE §2 exactly', () => {
    assert.deepEqual([...PERMISSIONS].sort(), Object.keys(TABLE).sort());
    for (const p of PERMISSIONS) {
      ROLES.forEach((role, i) => {
        assert.equal(hasPermission(role, p), TABLE[p][i], `${role} / ${p}`);
      });
      assert.equal(PERMISSION_MATRIX[p].length, TABLE[p].filter(Boolean).length);
    }
  });

  it('no role means no permission', () => {
    for (const p of PERMISSIONS) assert.equal(hasPermission(null, p), false);
    assert.deepEqual(permissionsFor(null), []);
  });

  it('content roles are exactly those who may edit content', () => {
    assert.deepEqual([...CONTENT_ROLES].sort(), ['content_manager', 'methodologist', 'super_admin']);
  });
});

describe('resolveRole', () => {
  it('a valid custom claim wins', () => {
    assert.equal(resolveRole('methodologist', 'admin'), 'methodologist');
  });

  it("legacy users.role == 'admin' maps to super_admin", () => {
    assert.equal(resolveRole(undefined, 'admin'), 'super_admin');
    assert.equal(resolveRole('bogus', 'admin'), 'super_admin');
  });

  it('anything else is no role', () => {
    assert.equal(resolveRole(undefined, 'student'), null);
    assert.equal(resolveRole('admin', undefined), null);
    assert.equal(resolveRole(undefined, 'content_manager'), null);
  });

  it('legacy field written on role change never keeps a stale admin', () => {
    const cases: Array<[Role | null, string]> = [
      ['super_admin', 'admin'],
      ['moderator', 'moderator'],
      [null, 'student'],
    ];
    for (const [role, legacy] of cases) assert.equal(legacyUserRoleFor(role), legacy);
  });
});
