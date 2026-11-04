// Firestore security rules tests. Requires the Firestore emulator (Java 21+):
//   cd tests/rules && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';

const PROJECT = 'demo-ort-rules';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

/** Firestore client as `uid` (with optional custom claims), or anonymous. */
function db(uid, claims = {}) {
  return uid ? env.authenticatedContext(uid, claims).firestore() : env.unauthenticatedContext().firestore();
}

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

const freeProfile = {
  name: 'Aida',
  email: 'aida@example.com',
  grade: 11,
  preferred_language: 'ru',
  subscription: { tier: 'free', expires_at: null },
  level: 'beginner',
};

describe('users/{uid}', () => {
  it('owner can create a default profile', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), freeProfile));
  });

  it('create cannot claim privileges', async () => {
    const a = db('alice');
    await assertFails(setDoc(doc(a, 'users/alice'), { ...freeProfile, role: 'admin' }));
    await assertFails(setDoc(doc(a, 'users/alice'), { ...freeProfile, is_premium: true }));
    await assertFails(setDoc(doc(a, 'users/alice'), { ...freeProfile, roles: ['admin'] }));
    await assertFails(setDoc(doc(a, 'users/alice'), { ...freeProfile, subscription: { tier: 'yearly', expires_at: Timestamp.now() } }));
    await assertFails(setDoc(doc(a, 'users/bob'), freeProfile));
  });

  it('owner may edit profile fields but no privileged field', async () => {
    await seed('users/alice', { ...freeProfile, role: 'student' });
    const a = db('alice');
    await assertSucceeds(updateDoc(doc(a, 'users/alice'), { name: 'Aida K.', last_active: Timestamp.now() }));
    for (const field of ['role', 'roles', 'is_premium', 'premium', 'is_banned', 'isActive', 'subscription', 'isAdmin']) {
      await assertFails(updateDoc(doc(a, 'users/alice'), { [field]: field === 'role' ? 'admin' : true }));
    }
  });

  it('owner cannot delete the profile (accountDelete function does)', async () => {
    await seed('users/alice', freeProfile);
    await assertFails(deleteDoc(doc(db('alice'), 'users/alice')));
  });

  it('other students cannot read profiles; support and moderators can', async () => {
    await seed('users/alice', freeProfile);
    await assertFails(getDoc(doc(db('bob'), 'users/alice')));
    await assertSucceeds(getDoc(doc(db('sup', { role: 'support' }), 'users/alice')));
    await assertSucceeds(getDoc(doc(db('mod', { role: 'moderator' }), 'users/alice')));
  });

  it('super_admin (claim or legacy users.role == admin) can change roles; moderator only bans', async () => {
    await seed('users/alice', freeProfile);
    await seed('users/legacy', { ...freeProfile, role: 'admin' });
    await assertSucceeds(updateDoc(doc(db('root', { role: 'super_admin' }), 'users/alice'), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(db('legacy'), 'users/alice'), { is_premium: true }));
    const mod = db('mod', { role: 'moderator' });
    await assertSucceeds(updateDoc(doc(mod, 'users/alice'), { is_banned: true }));
    await assertFails(updateDoc(doc(mod, 'users/alice'), { role: 'student' }));
  });

  it('a valid claim overrides the legacy field', async () => {
    await seed('users/cm', { ...freeProfile, role: 'admin' });
    await seed('users/alice', freeProfile);
    await assertFails(updateDoc(doc(db('cm', { role: 'content_manager' }), 'users/alice'), { is_premium: true }));
  });
});

describe('exam content', () => {
  beforeEach(async () => {
    await seed('exam_questions/q1', { stem: 'x', review: { status: 'draft' } });
    await seed('exam_question_keys/q1', { correct: 'A' });
    await seed('exam_passages/p1', { text: 't' });
    await seed('exam_variants/pub', { status: 'published', blueprint_id: 'ort_main_2026', number: 1, language: 'ru' });
    await seed('exam_variants/draft', { status: 'draft', blueprint_id: 'ort_main_2026', number: 2, language: 'ru' });
    await seed('exam_blueprints/ort_main_2026', { id: 'ort_main_2026' });
  });

  it('students can never read questions, keys or passages', async () => {
    const s = db('alice');
    await assertFails(getDoc(doc(s, 'exam_questions/q1')));
    await assertFails(getDoc(doc(s, 'exam_question_keys/q1')));
    await assertFails(getDoc(doc(s, 'exam_passages/p1')));
    await assertFails(getDocs(collection(s, 'exam_question_keys')));
  });

  it('content roles can read and write them', async () => {
    for (const role of ['super_admin', 'content_manager', 'methodologist']) {
      const c = db(`u_${role}`, { role });
      await assertSucceeds(getDoc(doc(c, 'exam_question_keys/q1')));
      await assertSucceeds(setDoc(doc(c, 'exam_passages/p2'), { text: 'new' }));
    }
    await assertFails(getDoc(doc(db('m', { role: 'moderator' }), 'exam_question_keys/q1')));
  });

  it('only reviewers may approve questions', async () => {
    const cm = db('cm', { role: 'content_manager' });
    await assertFails(updateDoc(doc(cm, 'exam_questions/q1'), { review: { status: 'methodologist_approved' } }));
    await assertSucceeds(updateDoc(doc(cm, 'exam_questions/q1'), { review: { status: 'ai_verified' } }));
    const me = db('me', { role: 'methodologist' });
    await assertSucceeds(updateDoc(doc(me, 'exam_questions/q1'), { review: { status: 'methodologist_approved' } }));
  });

  it('students read published variants only (and may query by status)', async () => {
    const s = db('alice');
    await assertSucceeds(getDoc(doc(s, 'exam_variants/pub')));
    await assertFails(getDoc(doc(s, 'exam_variants/draft')));
    await assertSucceeds(getDocs(query(collection(s, 'exam_variants'), where('status', '==', 'published'))));
    await assertFails(getDocs(collection(s, 'exam_variants')));
    await assertSucceeds(getDoc(doc(s, 'exam_blueprints/ort_main_2026')));
    await assertFails(getDoc(doc(db(null), 'exam_blueprints/ort_main_2026')));
  });

  it('variants cannot be published by a direct write', async () => {
    const cm = db('cm', { role: 'content_manager' });
    await assertFails(setDoc(doc(cm, 'exam_variants/v3'), { status: 'published' }));
    await assertSucceeds(setDoc(doc(cm, 'exam_variants/v3'), { status: 'draft' }));
    await assertFails(updateDoc(doc(cm, 'exam_variants/draft'), { status: 'published' }));
    await assertFails(updateDoc(doc(cm, 'exam_variants/pub'), { number: 9 }));
    await assertFails(setDoc(doc(db('me', { role: 'methodologist' }), 'exam_variants/v4'), { status: 'draft' }));
  });
});

describe('exam attempts and drafts', () => {
  const inFuture = () => Timestamp.fromMillis(Date.now() + 30 * 60_000);
  const longAgo = () => Timestamp.fromMillis(Date.now() - 10 * 60_000);

  async function seedAttempt(id, over = {}) {
    await seed(`exam_attempts/${id}`, {
      uid: 'alice',
      status: 'in_progress',
      current_section_id: 'math',
      current_deadline_at: inFuture(),
      ...over,
    });
  }

  it('owner reads, nobody writes the attempt', async () => {
    await seedAttempt('a1');
    await seed('exam_attempts/a1/answers/math', { answers: { q1: 'A' } });
    await assertSucceeds(getDoc(doc(db('alice'), 'exam_attempts/a1')));
    await assertSucceeds(getDoc(doc(db('alice'), 'exam_attempts/a1/answers/math')));
    await assertFails(getDoc(doc(db('bob'), 'exam_attempts/a1')));
    await assertFails(getDoc(doc(db('bob'), 'exam_attempts/a1/answers/math')));
    await assertFails(updateDoc(doc(db('alice'), 'exam_attempts/a1'), { status: 'completed' }));
    await assertFails(setDoc(doc(db('alice'), 'exam_attempts/a1/answers/math'), { answers: {} }));
    await assertFails(setDoc(doc(db('alice'), 'exam_attempts/new'), { uid: 'alice', status: 'completed' }));
  });

  it('owner may save a draft of the current section before the deadline', async () => {
    await seedAttempt('a1');
    await assertSucceeds(
      setDoc(doc(db('alice'), 'exam_attempts/a1/drafts/math'), { answers: { q1: 'A' }, flags: ['q2'], client_updated_at: Timestamp.now() }),
    );
  });

  it('drafts are rejected for other sections, other users, extra keys, oversize maps, late or finished attempts', async () => {
    await seedAttempt('a1');
    await seedAttempt('late', { current_deadline_at: longAgo() });
    await seedAttempt('done', { status: 'completed' });
    const a = db('alice');
    await assertFails(setDoc(doc(a, 'exam_attempts/a1/drafts/verbal'), { answers: {} }));
    await assertFails(setDoc(doc(db('bob'), 'exam_attempts/a1/drafts/math'), { answers: {} }));
    await assertFails(setDoc(doc(a, 'exam_attempts/a1/drafts/math'), { answers: {}, score: 100 }));
    const big = Object.fromEntries(Array.from({ length: 101 }, (_, i) => [`q${i}`, 'A']));
    await assertFails(setDoc(doc(a, 'exam_attempts/a1/drafts/math'), { answers: big }));
    await assertFails(setDoc(doc(a, 'exam_attempts/late/drafts/math'), { answers: {} }));
    await assertFails(setDoc(doc(a, 'exam_attempts/done/drafts/math'), { answers: {} }));
  });

  it('drafts are accepted within the 2-minute grace after the deadline', async () => {
    await seedAttempt('grace', { current_deadline_at: Timestamp.fromMillis(Date.now() - 60_000) });
    await assertSucceeds(setDoc(doc(db('alice'), 'exam_attempts/grace/drafts/math'), { answers: { q1: 'B' } }));
  });
});

describe('server-owned collections', () => {
  beforeEach(async () => {
    await seed('entitlements/alice', { credits: 3, free_exam_used: true });
    await seed('entitlements/alice/ledger/l1', { delta: -1 });
    await seed('purchases/h1', { uid: 'alice', state: 'granted' });
    await seed('purchases/h1/private/token', { purchase_token: 'secret' });
    await seed('user_stats/alice', { xp: 10 });
    await seed('xp_events/alice/events/e1', { amount: 10 });
    await seed('leaderboards/all_time/entries/alice', { uid: 'alice', xp: 10 });
    await seed('ai_usage/alice/days/2026-11-02', { count: 1 });
    await seed('admin_logs/x', { action: 'set_role' });
    await seed('config/pricing', { products: { exam_single: 1 } });
    await seed('config/ai_tutor', { daily_limit: 15 });
  });

  it('owner reads own server data but cannot write it', async () => {
    const a = db('alice');
    for (const p of ['entitlements/alice', 'entitlements/alice/ledger/l1', 'purchases/h1', 'user_stats/alice', 'xp_events/alice/events/e1', 'ai_usage/alice/days/2026-11-02']) {
      await assertSucceeds(getDoc(doc(a, p)));
    }
    await assertFails(setDoc(doc(a, 'entitlements/alice'), { credits: 999 }));
    await assertFails(setDoc(doc(a, 'user_stats/alice'), { xp: 99999 }));
    await assertFails(setDoc(doc(a, 'xp_events/alice/events/e2'), { amount: 500 }));
    await assertFails(setDoc(doc(a, 'purchases/h2'), { uid: 'alice', state: 'granted' }));
    await assertFails(setDoc(doc(a, 'leaderboards/all_time/entries/alice'), { xp: 1e9 }));
    await assertFails(setDoc(doc(a, 'ai_usage/alice/days/2026-11-02'), { count: 0 }));
  });

  it('other users cannot read them; raw purchase tokens are never readable', async () => {
    const b = db('bob');
    await assertFails(getDoc(doc(b, 'entitlements/alice')));
    await assertFails(getDoc(doc(b, 'purchases/h1')));
    await assertFails(getDoc(doc(b, 'user_stats/alice')));
    await assertFails(getDoc(doc(db('alice'), 'purchases/h1/private/token')));
    await assertFails(getDoc(doc(db('root', { role: 'super_admin' }), 'purchases/h1/private/token')));
  });

  it('support sees payments and admin logs; leaderboards are public to signed-in users', async () => {
    const sup = db('sup', { role: 'support' });
    await assertSucceeds(getDoc(doc(sup, 'purchases/h1')));
    await assertSucceeds(getDoc(doc(sup, 'admin_logs/x')));
    await assertFails(getDoc(doc(db('cm', { role: 'content_manager' }), 'admin_logs/x')));
    await assertSucceeds(getDoc(doc(db('bob'), 'leaderboards/all_time/entries/alice')));
    await assertFails(getDoc(doc(db(null), 'leaderboards/all_time/entries/alice')));
  });

  it('pricing is readable, tutor config is not', async () => {
    await assertSucceeds(getDoc(doc(db('alice'), 'config/pricing')));
    await assertFails(getDoc(doc(db('alice'), 'config/ai_tutor')));
    await assertFails(setDoc(doc(db('root', { role: 'super_admin' }), 'config/pricing'), { products: {} }));
  });
});

describe('user_mistakes', () => {
  it('owner writes practice items only', async () => {
    const a = db('alice');
    await assertSucceeds(setDoc(doc(a, 'user_mistakes/alice/items/q1'), { question_id: 'q1', source: 'practice', wrong_count: 1 }));
    await assertFails(setDoc(doc(a, 'user_mistakes/alice/items/q2'), { question_id: 'q2', source: 'exam' }));
    await assertFails(setDoc(doc(a, 'user_mistakes/alice/items/q3'), { question_id: 'other', source: 'practice' }));
    await assertFails(setDoc(doc(db('bob'), 'user_mistakes/alice/items/q4'), { question_id: 'q4', source: 'practice' }));
  });

  it('exam items: owner may only advance the review schedule', async () => {
    await seed('user_mistakes/alice/items/eq1', { question_id: 'eq1', source: 'exam', wrong_count: 1, resolved: false });
    const a = db('alice');
    await assertSucceeds(updateDoc(doc(a, 'user_mistakes/alice/items/eq1'), { resolved: true, interval_days: 3 }));
    await assertFails(updateDoc(doc(a, 'user_mistakes/alice/items/eq1'), { source: 'practice' }));
    await assertFails(updateDoc(doc(a, 'user_mistakes/alice/items/eq1'), { wrong_count: 0 }));
    await assertFails(deleteDoc(doc(a, 'user_mistakes/alice/items/eq1')));
  });
});

describe('legacy collections', () => {
  it('cosmetic gamification is owner read/write', async () => {
    const a = db('alice');
    await assertSucceeds(setDoc(doc(a, 'user_gamification/alice'), { xp: 10 }));
    await assertSucceeds(setDoc(doc(a, 'user_achievements/alice'), { achievements: [] }));
    await assertSucceeds(setDoc(doc(a, 'daily_quests/alice_2026-11-2'), { quests: [] }));
    await assertSucceeds(setDoc(doc(a, 'gamification/alice'), { level: 1 }));
    await assertFails(setDoc(doc(a, 'user_gamification/bob'), { xp: 10 }));
    await assertFails(setDoc(doc(a, 'daily_quests/bob_2026-11-2'), { quests: [] }));
    await assertFails(setDoc(doc(a, 'daily_quests/alice'), { quests: [] }));
  });

  it('daily lessons: read signed-in, write content roles', async () => {
    await seed('daily_lessons/d1', { title: 't' });
    await assertSucceeds(getDoc(doc(db('alice'), 'daily_lessons/d1')));
    await assertFails(setDoc(doc(db('alice'), 'daily_lessons/d2'), { title: 'x' }));
    await assertSucceeds(setDoc(doc(db('me', { role: 'methodologist' }), 'daily_lessons/d2'), { title: 'x' }));
  });

  it('content writes need a content role; legacy admins still work', async () => {
    await seed('users/legacy', { ...freeProfile, role: 'admin' });
    await assertFails(setDoc(doc(db('alice'), 'questions/q1'), { stem: {} }));
    await assertSucceeds(setDoc(doc(db('legacy'), 'questions/q1'), { stem: {} }));
    await assertSucceeds(setDoc(doc(db('cm', { role: 'content_manager' }), 'lessons/l1'), { subjectId: 'math', order: 1 }));
    await assertFails(setDoc(doc(db('sup', { role: 'support' }), 'subjects/s1'), { name: 'x' }));
  });

  it('client payments are never writable; forum posts are bound to the author', async () => {
    const a = db('alice');
    await assertFails(setDoc(doc(a, 'payments/p1'), { uid: 'alice', status: 'confirmed', amount: 0 }));
    await assertSucceeds(setDoc(doc(a, 'forum_posts/f1'), { author_uid: 'alice', text: 'hi' }));
    await assertFails(setDoc(doc(a, 'forum_posts/f2'), { author_uid: 'bob', text: 'impersonation' }));
  });

  it('progress docs cannot be re-assigned to another user', async () => {
    await seed('flashcard_progress/fp1', { uid: 'bob', box: 1 });
    await assertFails(setDoc(doc(db('alice'), 'flashcard_progress/fp1'), { uid: 'alice', box: 5 }));
    await seed('ort_attempts/o1', { user_id: 'bob', score: 1 });
    await assertFails(updateDoc(doc(db('alice'), 'ort_attempts/o1'), { user_id: 'alice' }));
  });

  it('unknown collections are denied', async () => {
    await assertFails(setDoc(doc(db('alice'), 'anything/x'), { a: 1 }));
    await assertFails(getDoc(doc(db('alice'), 'admins/alice')));
  });
});
