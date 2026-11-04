/**
 * Admin roles and the permission matrix, exactly as ARCHITECTURE §2.
 * The role lives in the Firebase Auth custom claim `role`; for backward
 * compatibility a legacy `users/{uid}.role == 'admin'` counts as
 * super_admin. firestore.rules mirrors this logic.
 */

export const ROLES = ['super_admin', 'content_manager', 'methodologist', 'moderator', 'support'] as const;
export type Role = (typeof ROLES)[number];

export const PERMISSIONS = [
  'manage_roles',
  'manage_pricing',
  'grant_credits',
  'refund',
  'view_payments',
  'edit_content',
  'edit_questions',
  'review_questions',
  'publish_variants',
  'manage_free_tests',
  'view_users',
  'moderate_users',
  'send_notifications',
  'manage_achievements',
  'view_stats',
] as const;
export type Permission = (typeof PERMISSIONS)[number];

const SA: Role = 'super_admin';
const CM: Role = 'content_manager';
const ME: Role = 'methodologist';
const MO: Role = 'moderator';
const SU: Role = 'support';

/** permission -> roles that hold it (ARCHITECTURE §2 table, row by row). */
export const PERMISSION_MATRIX: Readonly<Record<Permission, readonly Role[]>> = Object.freeze({
  manage_roles: [SA],
  manage_pricing: [SA],
  grant_credits: [SA],
  refund: [SA],
  view_payments: [SA, SU],
  edit_content: [SA, CM, ME],
  edit_questions: [SA, CM, ME],
  review_questions: [SA, ME],
  publish_variants: [SA, CM],
  manage_free_tests: [SA, CM],
  view_users: [SA, MO, SU],
  moderate_users: [SA, MO],
  send_notifications: [SA, CM],
  manage_achievements: [SA, CM],
  view_stats: [SA, CM, ME, MO, SU],
});

export function isRole(value: unknown): value is Role {
  return typeof value === 'string' && (ROLES as readonly string[]).includes(value);
}

/**
 * Effective admin role: a valid custom claim wins; otherwise the legacy
 * users.role == 'admin' maps to super_admin; anything else is no role.
 */
export function resolveRole(claimRole: unknown, legacyUserRole: unknown): Role | null {
  if (isRole(claimRole)) return claimRole;
  if (legacyUserRole === 'admin') return 'super_admin';
  return null;
}

export function hasPermission(role: Role | null, permission: Permission): boolean {
  return role !== null && PERMISSION_MATRIX[permission].includes(role);
}

export function permissionsFor(role: Role | null): Permission[] {
  return role === null ? [] : PERMISSIONS.filter((p) => PERMISSION_MATRIX[p].includes(role));
}

/** Roles that may write content/media (firestore.rules `isContentRole`). */
export const CONTENT_ROLES: readonly Role[] = PERMISSION_MATRIX.edit_content;

/**
 * Value written to the legacy users/{uid}.role field when a role changes, so
 * the legacy fallback can never outlive a revoked claim: only super_admin
 * keeps 'admin'; everything else is a non-privileged value.
 */
export function legacyUserRoleFor(role: Role | null): string {
  if (role === 'super_admin') return 'admin';
  return role ?? 'student';
}
