/**
 * Shared adapter helpers: Admin SDK singletons, callable options, error
 * translation, input validation and Timestamp conversion.
 */
import '../config';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp, type DocumentSnapshot, type Firestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { HttpsError, type CallableOptions, type CallableRequest } from 'firebase-functions/v2/https';
import { APP_CHECK_ENFORCE, APP_CHECK_ENFORCE_ADMIN } from '../config';
import { decideAccess, isBannedProfile } from '../domain/access';
import { DomainError, Reasons, type ErrorCode, type Reason } from '../domain/reasons';
import { hasPermission, resolveRole, type Permission, type Role } from '../domain/roles';
import { isRecord } from '../domain/types';

if (getApps().length === 0) initializeApp();

export function db(): Firestore {
  return getFirestore();
}

export { FieldValue, Timestamp };

/** Base options for every student onCall: App Check enforced unless APP_CHECK_ENFORCE=false. */
export function callableOptions(extra: Omit<CallableOptions, 'enforceAppCheck'> = {}): CallableOptions {
  return { enforceAppCheck: APP_CHECK_ENFORCE, timeoutSeconds: 60, ...extra };
}

/**
 * Options for the admin* callables. They already require a staff role (fresh
 * custom claims), so App Check is controlled by the separate
 * APP_CHECK_ENFORCE_ADMIN param (default false): the CMS also runs on web and
 * desktop builds where App Check may not be configured.
 */
export function adminCallableOptions(extra: Omit<CallableOptions, 'enforceAppCheck'> = {}): CallableOptions {
  return { enforceAppCheck: APP_CHECK_ENFORCE_ADMIN, timeoutSeconds: 60, ...extra };
}

export function httpsError(reason: Reason, message: string, extra?: Record<string, unknown>, code?: ErrorCode): HttpsError {
  const d = new DomainError(reason, message, extra, code);
  return new HttpsError(d.code, message, { reason, ...(extra ?? {}) });
}

/**
 * Wraps a callable body: DomainError -> HttpsError{details.reason};
 * HttpsError passes through; anything else is logged and becomes a generic
 * 'internal' error (no stack traces or internals leak to clients).
 */
export function wrap<T, R>(name: string, fn: (req: CallableRequest<T>) => Promise<R>): (req: CallableRequest<T>) => Promise<R> {
  return async (req) => {
    try {
      return await fn(req);
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      if (e instanceof DomainError) {
        throw new HttpsError(e.code, e.message, { reason: e.reason, ...(e.extra ?? {}) });
      }
      logger.error(`${name} failed`, { error: e instanceof Error ? { message: e.message, stack: e.stack } : String(e), uid: req.auth?.uid });
      throw new HttpsError('internal', 'Internal error, please retry.');
    }
  };
}

export function requireAuth(req: CallableRequest<unknown>): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return uid;
}

/** getAuth().getUser(uid), or null when the Auth user no longer exists. */
export async function findAuthUser(uid: string) {
  try {
    return await getAuth().getUser(uid);
  } catch (e) {
    if ((e as { code?: string }).code === 'auth/user-not-found') return null;
    throw e;
  }
}

export interface ActiveUser {
  uid: string;
  /** users/{uid} (may not exist). */
  profile: DocumentSnapshot;
}

/**
 * requireAuth + account-state checks for entitlement-consuming callables.
 * An ID token stays valid for up to an hour after accountDelete, so the Auth
 * user must still exist (and not be disabled): HttpsError 'unauthenticated'
 * otherwise. Unless `allowBanned`, a moderation ban (users/{uid}.is_banned)
 * is rejected with permission-denied + reason USER_BANNED.
 */
export async function requireActiveUser(req: CallableRequest<unknown>, opts: { allowBanned?: boolean } = {}): Promise<ActiveUser> {
  const uid = requireAuth(req);
  const [authUser, profile] = await Promise.all([findAuthUser(uid), db().doc(`users/${uid}`).get()]);
  const decision = decideAccess({ authUserExists: authUser !== null, disabled: authUser?.disabled, profile: profile.data() });
  if (decision === 'deleted' || decision === 'disabled') {
    logger.warn('callable from a deleted/disabled account', { uid, decision });
    throw new HttpsError('unauthenticated', 'This account is no longer active. Please sign in again.');
  }
  if (decision === 'banned' && !opts.allowBanned) {
    throw httpsError(Reasons.USER_BANNED, 'This account is blocked.');
  }
  return { uid, profile };
}

// ---------------------------------------------------------------------------
// Input validation

export function payload(req: CallableRequest<unknown>): Record<string, unknown> {
  const d = req.data;
  if (d === undefined || d === null) return {};
  if (!isRecord(d)) throw httpsError(Reasons.VALIDATION_FAILED, 'payload must be an object');
  return d;
}

const DOC_ID_RE = /^[A-Za-z0-9_-]{1,128}$/;
/** Firestore ids from legacy collections may contain other printable chars (never '/'). */
const LOOSE_ID_RE = /^[^/\s]{1,150}$/;

export function reqId(v: unknown, field: string, loose = false): string {
  if (typeof v !== 'string' || !(loose ? LOOSE_ID_RE : DOC_ID_RE).test(v) || v === '.' || v === '..' || v.startsWith('__')) {
    throw httpsError(Reasons.VALIDATION_FAILED, `${field} is invalid`, { field });
  }
  return v;
}

export function optString(v: unknown, field: string, maxLen: number): string | null {
  if (v === undefined || v === null || v === '') return null;
  if (typeof v !== 'string' || v.length > maxLen) throw httpsError(Reasons.VALIDATION_FAILED, `${field} is invalid`, { field });
  return v;
}

export function reqString(v: unknown, field: string, minLen: number, maxLen: number): string {
  if (typeof v !== 'string') throw httpsError(Reasons.VALIDATION_FAILED, `${field} is required`, { field });
  const t = v.trim();
  if (t.length < minLen || t.length > maxLen) throw httpsError(Reasons.VALIDATION_FAILED, `${field} has invalid length`, { field });
  return t;
}

export function reqInt(v: unknown, field: string, min: number, max: number): number {
  if (typeof v !== 'number' || !Number.isInteger(v) || v < min || v > max) {
    throw httpsError(Reasons.VALIDATION_FAILED, `${field} must be an integer in [${min}, ${max}]`, { field });
  }
  return v;
}

// ---------------------------------------------------------------------------
// Timestamp conversion

export function tsToMs(v: unknown): number | null {
  if (v instanceof Timestamp) return v.toMillis();
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (isRecord(v) && typeof (v as { toMillis?: unknown }).toMillis === 'function') return (v as { toMillis: () => number }).toMillis();
  return null;
}

export function msToTs(ms: number | null | undefined): Timestamp | null {
  return typeof ms === 'number' && Number.isFinite(ms) ? Timestamp.fromMillis(ms) : null;
}

// ---------------------------------------------------------------------------
// Admin authorization

export interface AdminActor {
  uid: string;
  role: Role;
}

/**
 * Resolves the caller's role from FRESH Auth custom claims (not the possibly
 * hour-old ID token, so revocations apply immediately) with the legacy
 * users/{uid}.role == 'admin' fallback, then checks the permission matrix.
 */
export async function requirePermission(
  req: CallableRequest<unknown>,
  permission: Permission,
  opts: { rejectBanned?: boolean } = {},
): Promise<AdminActor> {
  const uid = requireAuth(req);
  const [user, profile] = await Promise.all([
    getAuth().getUser(uid),
    db().doc(`users/${uid}`).get(),
  ]);
  const role = resolveRole(user.customClaims?.['role'], profile.get('role'));
  if (!hasPermission(role, permission)) {
    logger.warn('admin permission denied', { uid, role, permission });
    throw httpsError(Reasons.FORBIDDEN_ROLE, `permission ${permission} required`, { permission });
  }
  if (opts.rejectBanned && isBannedProfile(profile.data())) {
    throw httpsError(Reasons.USER_BANNED, 'This account is blocked.');
  }
  return { uid, role: role as Role };
}

export async function writeAdminLog(
  actor: { uid: string; role: string },
  action: string,
  target: Record<string, unknown>,
  details: Record<string, unknown> = {},
): Promise<void> {
  try {
    await db().collection('admin_logs').add({
      actor_uid: actor.uid,
      actor_role: actor.role,
      action,
      target,
      details,
      at: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.error('admin_logs write failed', { action, error: String(e) });
  }
}

/** Runs async tasks with bounded concurrency. */
export async function mapLimit<T, R>(items: readonly T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i]!);
    }
  });
  await Promise.all(workers);
  return out;
}

export function chunk<T>(items: readonly T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}
