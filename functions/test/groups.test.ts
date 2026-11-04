import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  assertCanCreateGroup,
  decideFriendAdd,
  decideGroupJoin,
  decideGroupLeave,
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
