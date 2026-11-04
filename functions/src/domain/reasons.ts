/**
 * `details.reason` codes carried by every HttpsError the backend throws.
 * Must match docs/modernization/ARCHITECTURE.md §3 and
 * lib/core/backend/backend_contract.dart (BackendReasons).
 */
export const Reasons = {
  NO_ENTITLEMENT: 'NO_ENTITLEMENT',
  VARIANT_NOT_AVAILABLE: 'VARIANT_NOT_AVAILABLE',
  ATTEMPT_NOT_FOUND: 'ATTEMPT_NOT_FOUND',
  ATTEMPT_NOT_IN_PROGRESS: 'ATTEMPT_NOT_IN_PROGRESS',
  WRONG_SECTION: 'WRONG_SECTION',
  PURCHASE_INVALID: 'PURCHASE_INVALID',
  PURCHASE_ACCOUNT_MISMATCH: 'PURCHASE_ACCOUNT_MISMATCH',
  PURCHASE_PENDING: 'PURCHASE_PENDING',
  AI_QUOTA_EXCEEDED: 'AI_QUOTA_EXCEEDED',
  AI_DISABLED: 'AI_DISABLED',
  AI_EXAM_IN_PROGRESS: 'AI_EXAM_IN_PROGRESS',
  FORBIDDEN_ROLE: 'FORBIDDEN_ROLE',
  VALIDATION_FAILED: 'VALIDATION_FAILED',
} as const;

export type Reason = (typeof Reasons)[keyof typeof Reasons];

/** Subset of HttpsError codes the domain layer uses. */
export type ErrorCode =
  | 'invalid-argument'
  | 'failed-precondition'
  | 'not-found'
  | 'permission-denied'
  | 'resource-exhausted'
  | 'unauthenticated'
  | 'unavailable'
  | 'internal';

/** Default HttpsError code for each reason (handlers may override). */
export const defaultCodeFor: Record<Reason, ErrorCode> = {
  NO_ENTITLEMENT: 'failed-precondition',
  VARIANT_NOT_AVAILABLE: 'failed-precondition',
  ATTEMPT_NOT_FOUND: 'not-found',
  ATTEMPT_NOT_IN_PROGRESS: 'failed-precondition',
  WRONG_SECTION: 'failed-precondition',
  PURCHASE_INVALID: 'invalid-argument',
  PURCHASE_ACCOUNT_MISMATCH: 'permission-denied',
  PURCHASE_PENDING: 'failed-precondition',
  AI_QUOTA_EXCEEDED: 'resource-exhausted',
  AI_DISABLED: 'failed-precondition',
  AI_EXAM_IN_PROGRESS: 'failed-precondition',
  FORBIDDEN_ROLE: 'permission-denied',
  VALIDATION_FAILED: 'invalid-argument',
};

/**
 * Error thrown by pure domain code. Handlers translate it into an
 * HttpsError with `details: {reason}` (see handlers/common.ts), so the
 * domain layer stays free of Firebase imports and is unit-testable.
 */
export class DomainError extends Error {
  readonly reason: Reason;
  readonly code: ErrorCode;
  readonly extra: Record<string, unknown> | undefined;

  constructor(reason: Reason, message?: string, extra?: Record<string, unknown>, code?: ErrorCode) {
    super(message ?? reason);
    this.name = 'DomainError';
    this.reason = reason;
    this.code = code ?? defaultCodeFor[reason];
    this.extra = extra;
  }
}

export function validationError(message: string, extra?: Record<string, unknown>): DomainError {
  return new DomainError(Reasons.VALIDATION_FAILED, message, extra);
}
