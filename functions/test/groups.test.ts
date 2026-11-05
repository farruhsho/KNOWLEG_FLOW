import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  assertCanCreateGroup,
  decideFriendAdd,
  decideGroupJoin,
  decideGroupLeave,
  decideMembershipCleanup,
  decideRemoveMember,
  MAX_FRIENDS,
  MAX_GROUP_MEMBERS,
  parseGroupName,
} from '../src/domain/groups';
import { DomainError } from '../src/domain/reasons';

function reasonOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    return e instanceof DomainError ? e.reason : 'other';
  }
  return undefined;
}

describe('group limits (ARCHITECTURE §9.3)', () => {
  it('group names are trimmed, single-spaced and 2-60 characters', () => {
    assert.equal(parseGroupName('  11 «А»   класс  '), '11 «А» класс');
    assert.equal(parseGroupName('a\nb'), 'a b');
    for (const bad of ['', ' a ', 'x'.repeat(61), 5, null]) assert.equal(reasonOf(() => parseGroupName(bad)), 'VALIDATION_FAILED');
  });

  it('groupCreate: at most 5 own groups and 5 memberships', () => {
    assert.equal(reasonOf(() => assertCanCreateGroup({ groupIds: ['g1', 'g2'], ownedCount: 2 })), undefined);
    assert.equal(reasonOf(() => assertCanCreateGroup({ groupIds: [], ownedCount: 5 })), 'LIMIT_REACHED');
    assert.equal(reasonOf(() => assertCanCreateGroup({ groupIds: ['a', 'b', 'c', 'd', 'e'], ownedCount: 0 })), 'LIMIT_REACHED');
    // Garbage in group_ids does not count.
    assert.equal(reasonOf(() => assertCanCreateGroup({ groupIds: ['a', 'a', 'b/c', 7, 'd'], ownedCount: 0 })), undefined);
  });

  it('groupJoin: idempotent for members, limited to 5 memberships and 500 members', () => {
    assert.deepEqual(decideGroupJoin({ groupIds: [], groupId: 'g', isMember: false, memberCount: 3 }), { kind: 'join' });
    assert.deepEqual(decideGroupJoin({ groupIds: ['a', 'b', 'c', 'd', 'e'], groupId: 'g', isMember: true, memberCount: 3 }), { kind: 'already_member' });
    assert.equal(reasonOf(() => decideGroupJoin({ groupIds: ['a', 'b', 'c', 'd', 'e'], groupId: 'g', isMember: false, memberCount: 3 })), 'LIMIT_REACHED');
    // A stale id of the same group in group_ids does not block re-joining.
    assert.deepEqual(decideGroupJoin({ groupIds: ['a', 'b', 'c', 'd', 'g'], groupId: 'g', isMember: false, memberCount: 3 }), { kind: 'join' });
    assert.equal(reasonOf(() => decideGroupJoin({ groupIds: [], groupId: 'g', isMember: false, memberCount: MAX_GROUP_MEMBERS })), 'LIMIT_REACHED');
  });

  it('groupJoin: the full group is LIMIT_REACHED what=group_members, the 6th membership what=memberships (§9.7)', () => {
    const whatOf = (fn: () => unknown) => {
      try {
        fn();
      } catch (e) {
        return e instanceof DomainError ? e.extra?.['what'] : 'other';
      }
      return undefined;
    };
    assert.equal(whatOf(() => decideGroupJoin({ groupIds: [], groupId: 'g', isMember: false, memberCount: MAX_GROUP_MEMBERS })), 'group_members');
    assert.equal(whatOf(() => decideGroupJoin({ groupIds: ['a', 'b', 'c', 'd', 'e'], groupId: 'g', isMember: false, memberCount: 3 })), 'memberships');
  });

  it('groupJoin: a member the owner removed cannot rejoin with the code (§9.7, P3-BE-04)', () => {
    let err: unknown;
    try {
      decideGroupJoin({ groupIds: [], groupId: 'g', isMember: false, memberCount: 3, removed: true });
    } catch (e) {
      err = e;
    }
    assert.ok(err instanceof DomainError);
    assert.equal(err.reason, 'VALIDATION_FAILED');
    assert.equal(err.code, 'failed-precondition');
    assert.equal(err.extra?.['why'], 'removed_from_group');
    // The removal check comes before the limits, and a current member stays idempotent.
    assert.equal(reasonOf(() => decideGroupJoin({ groupIds: [], groupId: 'g', isMember: false, memberCount: MAX_GROUP_MEMBERS, removed: true })), 'VALIDATION_FAILED');
    assert.deepEqual(decideGroupJoin({ groupIds: ['g'], groupId: 'g', isMember: true, memberCount: 3, removed: true }), { kind: 'already_member' });
    assert.deepEqual(decideGroupJoin({ groupIds: [], groupId: 'g', isMember: false, memberCount: 3, removed: false }), { kind: 'join' });
  });

  it('accountDelete cleanup decrements member_count only while the member doc exists (§9.7, P3-BE-05)', () => {
    const base = { uid: 'u', groupExists: true, ownerUid: 'o', memberExists: true };
    assert.deepEqual(decideMembershipCleanup(base), { kind: 'drop_member', decrement: true });
    // A concurrent groupLeave / groupRemoveMember or an overlapping retry already removed it: no second decrement.
    assert.deepEqual(decideMembershipCleanup({ ...base, memberExists: false }), { kind: 'none' });
    // Own group: deleted as a whole, also when the member doc is already gone.
    assert.deepEqual(decideMembershipCleanup({ ...base, ownerUid: 'u' }), { kind: 'owned' });
    assert.deepEqual(decideMembershipCleanup({ ...base, ownerUid: 'u', memberExists: false }), { kind: 'owned' });
    // Orphan member doc of a deleted group: dropped without touching a counter.
    assert.deepEqual(decideMembershipCleanup({ ...base, groupExists: false, ownerUid: null }), { kind: 'drop_member', decrement: false });
    assert.deepEqual(decideMembershipCleanup({ ...base, groupExists: false, ownerUid: null, memberExists: false }), { kind: 'none' });
    // A group without owner_uid is never treated as owned.
    assert.deepEqual(decideMembershipCleanup({ ...base, ownerUid: null }), { kind: 'drop_member', decrement: true });
    // Two overlapping runs: the second sees the member gone, so the count drops by exactly one.
    let count = 3;
    let memberExists = true;
    for (let run = 0; run < 2; run++) {
      const d = decideMembershipCleanup({ ...base, memberExists });
      if (d.kind === 'drop_member') {
        memberExists = false;
        if (d.decrement) count -= 1;
      }
    }
    assert.equal(count, 2);
  });

  it('groupLeave: members leave; the owner only when alone (the group is then deleted)', () => {
    assert.deepEqual(decideGroupLeave({ callerUid: 'm', ownerUid: 'o', isMember: true, memberCount: 3 }), { kind: 'leave' });
    assert.deepEqual(decideGroupLeave({ callerUid: 'x', ownerUid: 'o', isMember: false, memberCount: 3 }), { kind: 'not_member' });
    assert.deepEqual(decideGroupLeave({ callerUid: 'o', ownerUid: 'o', isMember: true, memberCount: 1 }), { kind: 'delete_group' });
    let err: unknown;
    try {
      decideGroupLeave({ callerUid: 'o', ownerUid: 'o', isMember: true, memberCount: 2 });
    } catch (e) {
      err = e;
    }
    assert.ok(err instanceof DomainError);
    assert.equal(err.reason, 'VALIDATION_FAILED');
    assert.equal(err.code, 'failed-precondition');
    assert.deepEqual(err.extra, { why: 'owner_has_members' });
  });

  it('groupRemoveMember: owner only (NOT_GROUP_OWNER), never the owner, idempotent', () => {
    assert.equal(reasonOf(() => decideRemoveMember({ callerUid: 'm', ownerUid: 'o', targetUid: 'x', targetIsMember: true })), 'NOT_GROUP_OWNER');
    assert.equal(reasonOf(() => decideRemoveMember({ callerUid: 'o', ownerUid: 'o', targetUid: 'o', targetIsMember: true })), 'VALIDATION_FAILED');
    assert.deepEqual(decideRemoveMember({ callerUid: 'o', ownerUid: 'o', targetUid: 'm', targetIsMember: true }), { kind: 'remove' });
    assert.deepEqual(decideRemoveMember({ callerUid: 'o', ownerUid: 'o', targetUid: 'm', targetIsMember: false }), { kind: 'not_member' });
  });
});

describe('friendAdd (ARCHITECTURE §9.3)', () => {
  it('adds, is idempotent, refuses yourself and the 51st friend', () => {
    assert.deepEqual(decideFriendAdd({ callerUid: 'a', friendUid: 'b', alreadyFriend: false, friendCount: 0 }), { kind: 'add' });
    assert.deepEqual(decideFriendAdd({ callerUid: 'a', friendUid: 'b', alreadyFriend: true, friendCount: MAX_FRIENDS }), { kind: 'already_friend' });
    assert.equal(reasonOf(() => decideFriendAdd({ callerUid: 'a', friendUid: 'a', alreadyFriend: false, friendCount: 0 })), 'VALIDATION_FAILED');
    assert.equal(reasonOf(() => decideFriendAdd({ callerUid: 'a', friendUid: 'b', alreadyFriend: false, friendCount: MAX_FRIENDS })), 'LIMIT_REACHED');
    assert.deepEqual(decideFriendAdd({ callerUid: 'a', friendUid: 'b', alreadyFriend: false, friendCount: MAX_FRIENDS - 1 }), { kind: 'add' });
  });
});
