/**
 * Groups (classes, training centres) — ARCHITECTURE §9.3:
 *   groupCreate {name}              -> {groupId, joinCode}
 *   groupJoin {code}                -> {groupId, name}
 *   groupLeave {groupId}            -> {ok}
 *   groupRemoveMember {groupId, uid} -> {ok}
 *
 * groups/{gid} = {name, owner_uid, join_code, member_count, created_at}
 * groups/{gid}/members/{uid} = {display_name, role: owner|member, joined_at, uid}
 * group_join_codes/{code} = {group_id, created_at}  (uniqueness reservation, no client access)
 * users/{uid}.group_ids (privileged, ≤ 5) — the owner is a member too.
 *
 * Membership documents, member_count and users.group_ids always change in
 * one transaction. Assignments and submissions are written by clients under
 * firestore.rules (owner / member).
 */
import '../config';
import { randomInt } from 'node:crypto';
import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';
import { generateShortCode, isShortCode, MAX_CODE_ATTEMPTS, normalizeCode } from '../domain/codes';
import { assertCanCreateGroup, decideGroupJoin, decideGroupLeave, decideRemoveMember, MAX_OWNED_GROUPS, parseGroupName } from '../domain/groups';
import { leagueGroupIds } from '../domain/leaderboard';
import { DomainError, Reasons } from '../domain/reasons';
import { groupWeeklyBoardId } from '../domain/time';
import { int, str } from '../domain/types';
import { callableOptions, chunk, db, FieldValue, payload, reqId, requireActiveUser, wrap } from './common';
import { displayNameOf } from './gamification';

const groupRef = (gid: string) => db().doc(`groups/${gid}`);
const memberRef = (gid: string, uid: string) => db().doc(`groups/${gid}/members/${uid}`);
const joinCodeRef = (code: string) => db().doc(`group_join_codes/${code}`);
const userRef = (uid: string) => db().doc(`users/${uid}`);
/** Current week's group-league entry (removed when a member leaves). */
const groupBoardEntryRef = (gid: string, uid: string, nowMs: number) => db().doc(`leaderboards/${groupWeeklyBoardId(gid, nowMs)}/entries/${uid}`);

function codeInvalid(): DomainError {
  return new DomainError(Reasons.CODE_INVALID, 'group code is not valid');
}

function profileRequired(): DomainError {
  return new DomainError(Reasons.VALIDATION_FAILED, 'complete your profile first', { why: 'profile_missing' }, 'failed-precondition');
}

function without(ids: unknown, gid: string): string[] {
  return leagueGroupIds(ids).filter((g) => g !== gid);
}

// ---------------------------------------------------------------------------
// groupCreate {name} -> {groupId, joinCode}

export const groupCreate = onCall(
  callableOptions(),
  wrap('groupCreate', async (req) => {
    const { uid, profile } = await requireActiveUser(req);
    if (!profile.exists) throw profileRequired();
    const name = parseGroupName(payload(req)['name']);
    const ownedQuery = db().collection('groups').where('owner_uid', '==', uid).select().limit(MAX_OWNED_GROUPS);

    for (let i = 0; i < MAX_CODE_ATTEMPTS; i++) {
      const code = generateShortCode(randomInt);
      const created = await db().runTransaction(async (tx) => {
        const [[userSnap, codeSnap], owned] = await Promise.all([tx.getAll(userRef(uid), joinCodeRef(code)), tx.get(ownedQuery)]);
        assertCanCreateGroup({ groupIds: userSnap!.get('group_ids'), ownedCount: owned.size });
        if (codeSnap!.exists) return null; // collision: try another code
        const ref = db().collection('groups').doc();
        tx.set(ref, { name, owner_uid: uid, join_code: code, member_count: 1, created_at: FieldValue.serverTimestamp() });
        tx.set(memberRef(ref.id, uid), {
          uid,
          display_name: displayNameOf(userSnap!.data()),
          role: 'owner',
          joined_at: FieldValue.serverTimestamp(),
        });
        tx.set(joinCodeRef(code), { group_id: ref.id, created_at: FieldValue.serverTimestamp() });
        tx.set(userRef(uid), { group_ids: [...leagueGroupIds(userSnap!.get('group_ids')), ref.id] }, { merge: true });
        return { groupId: ref.id, joinCode: code };
      });
      if (created) {
        logger.info('group created', { uid, groupId: created.groupId });
        return created;
      }
    }
    throw new Error('could not allocate a group join code');
  }),
);

// ---------------------------------------------------------------------------
// groupJoin {code} -> {groupId, name}

export const groupJoin = onCall(
  callableOptions(),
  wrap('groupJoin', async (req) => {
    const { uid, profile } = await requireActiveUser(req);
    if (!profile.exists) throw profileRequired();
    const code = normalizeCode(payload(req)['code']);
    if (!isShortCode(code)) throw codeInvalid();
    const gid = str((await joinCodeRef(code).get()).get('group_id'));
    if (!gid) throw codeInvalid();

    return db().runTransaction(async (tx) => {
      const [userSnap, groupSnap, memberSnap] = await tx.getAll(userRef(uid), groupRef(gid), memberRef(gid, uid));
      if (!groupSnap!.exists || groupSnap!.get('join_code') !== code) throw codeInvalid();
      const ids = leagueGroupIds(userSnap!.get('group_ids'));
      const d = decideGroupJoin({ groupIds: ids, groupId: gid, isMember: memberSnap!.exists, memberCount: int(groupSnap!.get('member_count')) });
      if (d.kind === 'join') {
        tx.set(memberRef(gid, uid), { uid, display_name: displayNameOf(userSnap!.data()), role: 'member', joined_at: FieldValue.serverTimestamp() });
        tx.update(groupRef(gid), { member_count: int(groupSnap!.get('member_count')) + 1 });
      }
      // Also repairs a missing group id for an existing member.
      if (!ids.includes(gid)) tx.set(userRef(uid), { group_ids: [...ids, gid] }, { merge: true });
      return { groupId: gid, name: str(groupSnap!.get('name')) };
    });
  }),
);

// ---------------------------------------------------------------------------
// groupLeave {groupId} -> {ok}

export const groupLeave = onCall(
  callableOptions(),
  wrap('groupLeave', async (req) => {
    // Leaving is always allowed, also for banned accounts.
    const { uid } = await requireActiveUser(req, { allowBanned: true });
    const gid = reqId(payload(req)['groupId'], 'groupId');
    const nowMs = Date.now();
    const outcome = await db().runTransaction(async (tx) => {
      const [userSnap, groupSnap, memberSnap] = await tx.getAll(userRef(uid), groupRef(gid), memberRef(gid, uid));
      const ids = userSnap!.get('group_ids');
      const cleanIds = () => {
        if (userSnap!.exists && leagueGroupIds(ids).includes(gid)) tx.update(userRef(uid), { group_ids: without(ids, gid) });
      };
      if (!groupSnap!.exists) {
        cleanIds();
        return 'not_member' as const;
      }
      const d = decideGroupLeave({
        callerUid: uid,
        ownerUid: str(groupSnap!.get('owner_uid')) || null,
        isMember: memberSnap!.exists,
        memberCount: int(groupSnap!.get('member_count')),
      });
      cleanIds();
      if (d.kind === 'not_member') return d.kind;
      tx.delete(memberRef(gid, uid));
      tx.delete(groupBoardEntryRef(gid, uid, nowMs));
      if (d.kind === 'leave') {
        tx.update(groupRef(gid), { member_count: Math.max(1, int(groupSnap!.get('member_count')) - 1) });
      } else {
        tx.delete(groupRef(gid));
        const code = str(groupSnap!.get('join_code'));
        if (isShortCode(code)) tx.delete(joinCodeRef(code));
      }
      return d.kind;
    });
    if (outcome === 'delete_group') {
      // Assignments + submissions (sub-collections survive a document delete).
      await db().recursiveDelete(groupRef(gid));
      logger.info('group deleted by its last member (owner)', { uid, groupId: gid });
    }
    return { ok: true };
  }),
);

// ---------------------------------------------------------------------------
// groupRemoveMember {groupId, uid} -> {ok}

export const groupRemoveMember = onCall(
  callableOptions(),
  wrap('groupRemoveMember', async (req) => {
    const { uid } = await requireActiveUser(req, { allowBanned: true });
    const data = payload(req);
    const gid = reqId(data['groupId'], 'groupId');
    const target = reqId(data['uid'], 'uid');
    const nowMs = Date.now();
    await db().runTransaction(async (tx) => {
      const [groupSnap, targetMember, targetUser] = await tx.getAll(groupRef(gid), memberRef(gid, target), userRef(target));
      // Missing group and "not yours" look the same, so group ids cannot be probed.
      if (!groupSnap!.exists) throw new DomainError(Reasons.NOT_GROUP_OWNER, 'only the group owner can remove members');
      const d = decideRemoveMember({
        callerUid: uid,
        ownerUid: str(groupSnap!.get('owner_uid')) || null,
        targetUid: target,
        targetIsMember: targetMember!.exists,
      });
      const ids = targetUser!.get('group_ids');
      if (targetUser!.exists && leagueGroupIds(ids).includes(gid)) tx.update(userRef(target), { group_ids: without(ids, gid) });
      if (d.kind === 'not_member') return;
      tx.delete(memberRef(gid, target));
      tx.delete(groupBoardEntryRef(gid, target, nowMs));
      tx.update(groupRef(gid), { member_count: Math.max(1, int(groupSnap!.get('member_count')) - 1) });
    });
    logger.info('group member removed', { owner: uid, groupId: gid, target });
    return { ok: true };
  }),
);

// ---------------------------------------------------------------------------
// accountDelete support

/**
 * Removes `uid` from every group: memberships are dropped (member_count
 * decremented); groups the user owns are deleted with their assignments,
 * submissions and join code, and the other members' group_ids are cleaned.
 */
export async function removeUserFromGroups(uid: string): Promise<number> {
  const memberships = await db().collectionGroup('members').where('uid', '==', uid).limit(50).get();
  let n = 0;
  for (const m of memberships.docs) {
    const gRef = m.ref.parent.parent;
    if (!gRef || gRef.parent.id !== 'groups') continue;
    const gid = gRef.id;
    const owned = await db().runTransaction(async (tx) => {
      const g = await tx.get(gRef);
      if (!g.exists) {
        tx.delete(m.ref);
        return false;
      }
      if (g.get('owner_uid') === uid) return true;
      tx.delete(m.ref);
      tx.update(gRef, { member_count: Math.max(1, int(g.get('member_count')) - 1) });
      return false;
    });
    if (owned) {
      const members = await gRef.collection('members').select().get();
      for (const part of chunk(members.docs, 400)) {
        const users = await db().getAll(...part.map((d) => userRef(d.id)));
        const batch = db().batch();
        for (const u of users) {
          if (u.exists && u.id !== uid) batch.update(u.ref, { group_ids: FieldValue.arrayRemove(gid) });
        }
        await batch.commit();
      }
      const code = str((await gRef.get()).get('join_code'));
      if (isShortCode(code)) await joinCodeRef(code).delete();
      await db().recursiveDelete(gRef);
    }
    n++;
  }
  return n;
}
