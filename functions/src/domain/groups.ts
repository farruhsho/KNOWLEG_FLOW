/**
 * Social limits (ARCHITECTURE §9.3): friends and groups. Pure decisions; the
 * handlers persist them in transactions (member_count and users.group_ids
 * change in the same transaction as the members document).
 */
import { leagueGroupIds, MAX_GROUP_IDS } from './leaderboard';
import { DomainError, Reasons, validationError } from './reasons';

export const MAX_FRIENDS = 50;
/** Groups a user may own (each owned group is also one of the ≤ 5 memberships). */
export const MAX_OWNED_GROUPS = 5;
/** Groups a user may belong to (users/{uid}.group_ids). */
export const MAX_MEMBERSHIPS = MAX_GROUP_IDS;
/** Members per group (a class or a training-center cohort). */
export const MAX_GROUP_MEMBERS = 500;
export const GROUP_NAME_MIN = 2;
export const GROUP_NAME_MAX = 60;

/** Trimmed, single-spaced group name; VALIDATION_FAILED when out of bounds. */
export function parseGroupName(raw: unknown): string {
  if (typeof raw !== 'string') throw validationError('name is required', { field: 'name' });
  const t = raw.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim();
  if (t.length < GROUP_NAME_MIN || t.length > GROUP_NAME_MAX) {
    throw validationError(`name must be ${GROUP_NAME_MIN}-${GROUP_NAME_MAX} characters`, { field: 'name' });
  }
  return t;
}

export function limitReached(what: 'friends' | 'owned_groups' | 'memberships' | 'group_members', limit: number): DomainError {
  return new DomainError(Reasons.LIMIT_REACHED, `limit reached: ${what}`, { what, limit });
}

export interface CreateGroupInput {
  groupIds: unknown;
  ownedCount: number;
}

/** groupCreate: ≤ 5 own groups and ≤ 5 memberships (the owner is a member). */
export function assertCanCreateGroup(input: CreateGroupInput): void {
  if (input.ownedCount >= MAX_OWNED_GROUPS) throw limitReached('owned_groups', MAX_OWNED_GROUPS);
  if (leagueGroupIds(input.groupIds).length >= MAX_MEMBERSHIPS) throw limitReached('memberships', MAX_MEMBERSHIPS);
}

export type JoinDecision = { kind: 'join' } | { kind: 'already_member' };

export interface JoinInput {
  groupIds: unknown;
  groupId: string;
  isMember: boolean;
  memberCount: number;
  /** groups/{gid}/removed/{uid} exists: the owner removed this user (ARCHITECTURE §9.7). */
  removed?: boolean;
}

/**
 * groupJoin: idempotent for a member; a user the owner removed cannot come
 * back with the code (VALIDATION_FAILED, `why: removed_from_group`); then
 * the membership (≤ 5) and group size (≤ 500) limits.
 */
export function decideGroupJoin(input: JoinInput): JoinDecision {
  if (input.isMember) return { kind: 'already_member' };
  if (input.removed) {
    throw new DomainError(Reasons.VALIDATION_FAILED, 'you were removed from this group', { why: 'removed_from_group' }, 'failed-precondition');
  }
  const ids = leagueGroupIds(input.groupIds).filter((g) => g !== input.groupId);
  if (ids.length >= MAX_MEMBERSHIPS) throw limitReached('memberships', MAX_MEMBERSHIPS);
  if (input.memberCount >= MAX_GROUP_MEMBERS) throw limitReached('group_members', MAX_GROUP_MEMBERS);
  return { kind: 'join' };
}

export type LeaveDecision =
  | { kind: 'not_member' }
  | { kind: 'leave' }
  /** The owner is the last member: the group is deleted. */
  | { kind: 'delete_group' };

export interface LeaveInput {
  callerUid: string;
  ownerUid: string | null;
  isMember: boolean;
  memberCount: number;
}

/** groupLeave: the owner may leave only when no other member is left (the group is then deleted). */
export function decideGroupLeave(input: LeaveInput): LeaveDecision {
  if (!input.isMember) return { kind: 'not_member' };
  if (input.callerUid !== input.ownerUid) return { kind: 'leave' };
  if (input.memberCount > 1) {
    throw new DomainError(Reasons.VALIDATION_FAILED, 'the owner cannot leave while the group has members', { why: 'owner_has_members' }, 'failed-precondition');
  }
  return { kind: 'delete_group' };
}

export type RemoveDecision = { kind: 'not_member' } | { kind: 'remove' };

export interface RemoveInput {
  callerUid: string;
  ownerUid: string | null;
  targetUid: string;
  targetIsMember: boolean;
}

/** groupRemoveMember: owner only, never the owner themself. */
export function decideRemoveMember(input: RemoveInput): RemoveDecision {
  if (input.callerUid !== input.ownerUid) throw new DomainError(Reasons.NOT_GROUP_OWNER, 'only the group owner can remove members');
  if (input.targetUid === input.ownerUid) throw validationError('the owner cannot remove themself; use groupLeave', { field: 'uid' });
  return input.targetIsMember ? { kind: 'remove' } : { kind: 'not_member' };
}

export type MembershipCleanup =
  /** The user owns the group: the whole group is deleted. */
  | { kind: 'owned' }
  /** Delete the members doc; decrement member_count only when it still existed in a live group. */
  | { kind: 'drop_member'; decrement: boolean }
  /** Nothing left to do (a concurrent leave / removal / earlier run already dropped it). */
  | { kind: 'none' };

export interface MembershipCleanupInput {
  uid: string;
  groupExists: boolean;
  ownerUid: string | null;
  /** groups/{gid}/members/{uid} re-read inside the transaction. */
  memberExists: boolean;
}

/**
 * accountDelete group cleanup for one membership (ARCHITECTURE §9.7). The
 * member doc is re-read in the transaction, so a concurrent groupLeave /
 * groupRemoveMember or an overlapping accountDelete retry never decrements
 * member_count twice.
 */
export function decideMembershipCleanup(input: MembershipCleanupInput): MembershipCleanup {
  if (!input.groupExists) return input.memberExists ? { kind: 'drop_member', decrement: false } : { kind: 'none' };
  if (input.ownerUid !== null && input.ownerUid === input.uid) return { kind: 'owned' };
  return input.memberExists ? { kind: 'drop_member', decrement: true } : { kind: 'none' };
}

export type FriendDecision = { kind: 'add' } | { kind: 'already_friend' };

export interface FriendInput {
  callerUid: string;
  friendUid: string;
  alreadyFriend: boolean;
  friendCount: number;
}

/** friendAdd: never yourself, at most MAX_FRIENDS, idempotent for an existing friend. */
export function decideFriendAdd(input: FriendInput): FriendDecision {
  if (input.friendUid === input.callerUid) {
    throw new DomainError(Reasons.VALIDATION_FAILED, 'you cannot add yourself', { why: 'self', field: 'code' });
  }
  if (input.alreadyFriend) return { kind: 'already_friend' };
  if (input.friendCount >= MAX_FRIENDS) throw limitReached('friends', MAX_FRIENDS);
  return { kind: 'add' };
}
