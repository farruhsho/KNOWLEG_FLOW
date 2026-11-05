/**
 * Account-state rules shared by the callables (ARCHITECTURE §2/§3): deleted
 * or disabled accounts, moderation bans, the recent-sign-in requirement of
 * accountDelete, and the "no AI tutor during a live exam" rule. Pure, so the
 * handlers stay thin and these decisions are unit-tested.
 */
import { DomainError, Reasons } from './reasons';
import { isRecord } from './types';

/** accountDelete accepts an ID token whose auth_time is at most this old. */
export const RECENT_LOGIN_MAX_AGE_SEC = 5 * 60;

export type AccessDecision = 'ok' | 'deleted' | 'disabled' | 'banned';

export interface AccessInput {
  /** getAuth().getUser(uid) found the user. */
  authUserExists: boolean;
  /** UserRecord.disabled */
  disabled?: boolean;
  /** users/{uid} data (may be missing for brand-new accounts). */
  profile?: unknown;
}

/** True when the users/{uid} profile carries a moderation ban. */
export function isBannedProfile(profile: unknown): boolean {
  return isRecord(profile) && profile['is_banned'] === true;
}

/**
 * Whether a caller with a still-valid ID token may use a student callable.
 * The ID token stays valid for up to an hour after accountDelete or a ban,
 * so the handlers re-check the Auth user and the profile on every call.
 */
export function decideAccess(input: AccessInput): AccessDecision {
  if (!input.authUserExists) return 'deleted';
  if (input.disabled === true) return 'disabled';
  if (isBannedProfile(input.profile)) return 'banned';
  return 'ok';
}

/**
 * True when the ID token's `auth_time` (seconds since epoch, the time of the
 * last real sign-in or re-authentication; token refreshes do not change it)
 * is within `maxAgeSec` of `nowMs`.
 */
export function isRecentLogin(authTimeSec: unknown, nowMs: number, maxAgeSec = RECENT_LOGIN_MAX_AGE_SEC): boolean {
  const t = typeof authTimeSec === 'number' ? authTimeSec : typeof authTimeSec === 'string' ? Number(authTimeSec) : NaN;
  if (!Number.isFinite(t) || t <= 0) return false;
  return nowMs / 1000 - t <= maxAgeSec;
}

/** Throws REQUIRES_RECENT_LOGIN (failed-precondition) unless the sign-in is recent. */
export function assertRecentLogin(authTimeSec: unknown, nowMs: number): void {
  if (!isRecentLogin(authTimeSec, nowMs)) {
    throw new DomainError(Reasons.REQUIRES_RECENT_LOGIN, 'recent sign-in required', { maxAgeSec: RECENT_LOGIN_MAX_AGE_SEC });
  }
}

/**
 * AI tutor integrity rule (ARCHITECTURE §6, decision D8): while the user has
 * ANY in-progress exam attempt, every tutor request is rejected, whatever
 * questionId/attemptId the client sends (or omits).
 */
export function assertNoLiveExam(inProgressAttempts: number): void {
  if (inProgressAttempts > 0) {
    throw new DomainError(Reasons.AI_EXAM_IN_PROGRESS, 'finish the exam in progress first');
  }
}

/**
 * Document-id range that matches every `daily_quests` id of `uid`
 * (`${uid}_${dayKey}`): [`${uid}_`, `${uid}` + '`'), because '`' (U+0060) is
 * the code point right after '_' (U+005F).
 */
export function dailyQuestIdRange(uid: string): { start: string; end: string } {
  return { start: `${uid}_`, end: uid + String.fromCharCode(0x60) };
}

/**
 * accountDelete (§9.7): true only for `friends/{owner}/list/{uid}` — an entry
 * another user keeps about `uid` — so the collection-group query on `list`
 * can never delete documents of some other `list` sub-collection (or the
 * user's own list entries, which go with the friends/{uid} tree).
 */
export function isFriendEntryAbout(path: string, uid: string): boolean {
  const parts = path.split('/');
  return parts.length === 4 && parts[0] === 'friends' && parts[2] === 'list' && parts[3] === uid && parts[1] !== uid && parts[1] !== '';
}
