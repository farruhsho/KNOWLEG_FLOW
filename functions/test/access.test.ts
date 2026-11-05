import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import {
  assertNoLiveExam,
  assertRecentLogin,
  dailyQuestIdRange,
  decideAccess,
  isBannedProfile,
  isFriendEntryAbout,
  isRecentLogin,
  RECENT_LOGIN_MAX_AGE_SEC,
} from '../src/domain/access';
import { DomainError, Reasons } from '../src/domain/reasons';

const NOW = 1_762_000_000_000;
const nowSec = NOW / 1000;

describe('decideAccess (deleted accounts, bans)', () => {
  it('a deleted Auth user is rejected even though the ID token is still valid (SEC-FREE-01)', () => {
    assert.equal(decideAccess({ authUserExists: false, profile: undefined }), 'deleted');
    assert.equal(decideAccess({ authUserExists: true, disabled: true, profile: {} }), 'disabled');
  });

  it('a moderation ban (users.is_banned == true) is detected (D5)', () => {
    assert.equal(decideAccess({ authUserExists: true, profile: { is_banned: true, ban_reason: 'spam' } }), 'banned');
    assert.equal(isBannedProfile({ is_banned: 'true' }), false);
    assert.equal(decideAccess({ authUserExists: true, profile: { is_banned: false } }), 'ok');
    assert.equal(decideAccess({ authUserExists: true, profile: undefined }), 'ok');
  });
});

describe('recent sign-in for accountDelete (D9)', () => {
  it('accepts an auth_time within 5 minutes', () => {
    assert.equal(isRecentLogin(nowSec - 10, NOW), true);
    assert.equal(isRecentLogin(nowSec - RECENT_LOGIN_MAX_AGE_SEC, NOW), true);
    assert.doesNotThrow(() => assertRecentLogin(nowSec - 60, NOW));
  });

  it('rejects old or missing auth_time with REQUIRES_RECENT_LOGIN / failed-precondition', () => {
    assert.equal(isRecentLogin(nowSec - RECENT_LOGIN_MAX_AGE_SEC - 1, NOW), false);
    assert.equal(isRecentLogin(undefined, NOW), false);
    assert.equal(isRecentLogin(0, NOW), false);
    assert.throws(
      () => assertRecentLogin(nowSec - 3600, NOW),
      (e: unknown) => e instanceof DomainError && e.reason === Reasons.REQUIRES_RECENT_LOGIN && e.code === 'failed-precondition',
    );
  });
});

describe('AI tutor during an exam (D8)', () => {
  it('any in-progress attempt blocks the tutor, whatever ids the client sent', () => {
    assert.doesNotThrow(() => assertNoLiveExam(0));
    assert.throws(
      () => assertNoLiveExam(1),
      (e: unknown) => e instanceof DomainError && e.reason === Reasons.AI_EXAM_IN_PROGRESS,
    );
  });
});

describe('dailyQuestIdRange (ACC-DQ-01)', () => {
  // Firestore orders document ids by UTF-8 bytes; for these ASCII ids that is plain string order.
  const inRange = (id: string, r: { start: string; end: string }) => id >= r.start && id < r.end;

  it('covers every `${uid}_${day}` id and nothing of other users', () => {
    const r = dailyQuestIdRange('alice');
    assert.notEqual(r.start, r.end, 'the range must not be empty');
    for (const id of ['alice_2026-11-2', 'alice_2026-11-02', 'alice_', 'alice_zzz', 'alice_~x']) assert.ok(inRange(id, r), id);
    for (const id of ['alice', 'alicea_2026-11-02', 'alice0_x', 'bob_2026-11-02', 'alicf']) assert.ok(!inRange(id, r), id);
  });
});

describe('isFriendEntryAbout (accountDelete, §9.7 P3-BE-06)', () => {
  it('matches only friends/{other}/list/{uid}', () => {
    assert.ok(isFriendEntryAbout('friends/bob/list/alice', 'alice'));
    assert.ok(isFriendEntryAbout('friends/carol/list/alice', 'alice'));
  });

  it('never touches other `list` collections, other entries or the user\'s own list', () => {
    for (const p of [
      'friends/bob/list/carol', // an entry about someone else
      'friends/alice/list/alice', // own tree (deleted with friends/{uid})
      'groups/g1/list/alice', // some other `list` sub-collection
      'users/bob/list/alice',
      'a/friends/bob/list/alice', // nested deeper
      'friends/bob/lists/alice',
      'friends//list/alice',
    ]) {
      assert.equal(isFriendEntryAbout(p, 'alice'), false, p);
    }
  });
});

describe('reason codes', () => {
  it('USER_BANNED is permission-denied and REQUIRES_RECENT_LOGIN failed-precondition', () => {
    assert.equal(new DomainError(Reasons.USER_BANNED).code, 'permission-denied');
    assert.equal(new DomainError(Reasons.REQUIRES_RECENT_LOGIN).code, 'failed-precondition');
  });

  it('every server reason exists in the Flutter BackendReasons contract', () => {
    const dart = readFileSync(path.resolve(__dirname, '..', '..', 'lib', 'core', 'backend', 'backend_contract.dart'), 'utf8');
    for (const reason of Object.values(Reasons)) assert.ok(dart.includes(`'${reason}'`), `BackendReasons is missing ${reason}`);
  });
});
