// Firestore security rules tests. Requires the Firestore emulator (Java 21+):
//   cd tests/rules && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  arrayRemove,
  collection,
  deleteDoc,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  increment,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
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
    await seed('users/bob', freeProfile);
    await seed('users/legacy', { ...freeProfile, role: 'admin' });
    await assertSucceeds(updateDoc(doc(db('root', { role: 'super_admin' }), 'users/alice'), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(db('legacy'), 'users/alice'), { is_premium: true }));
    // alice is staff now, so the moderator works on a student profile.
    const mod = db('mod', { role: 'moderator' });
    await assertSucceeds(updateDoc(doc(mod, 'users/bob'), { is_banned: true }));
    await assertFails(updateDoc(doc(mod, 'users/bob'), { role: 'admin' }));
    await assertFails(updateDoc(doc(mod, 'users/alice'), { is_banned: true }));
  });

  // Exact maps written by the CMS (lib/features/admin/data/repositories/people_repositories.dart setBanned).
  const banMap = (actor) => ({ is_banned: true, ban_reason: 'spam', banned_by: actor, banned_at: serverTimestamp() });
  const unbanMap = { is_banned: false, ban_reason: null, banned_by: null, banned_at: null };

  it('moderator can ban and unban with the CMS map (D5, AUTH-ADM-02)', async () => {
    await seed('users/alice', { ...freeProfile, role: 'student' });
    const mod = db('mod', { role: 'moderator' });
    await assertSucceeds(updateDoc(doc(mod, 'users/alice'), banMap('mod')));
    await assertSucceeds(updateDoc(doc(mod, 'users/alice'), { ...unbanMap, updated_at: serverTimestamp() }));
  });

  it('moderator cannot attribute the ban to someone else, touch premium/roles, or ban staff', async () => {
    await seed('users/alice', { ...freeProfile, role: 'student' });
    await seed('users/cm', { ...freeProfile, role: 'student', admin_role: 'content_manager' });
    await seed('users/oldadmin', { ...freeProfile, role: 'admin' });
    const mod = db('mod', { role: 'moderator' });
    await assertFails(updateDoc(doc(mod, 'users/alice'), banMap('someone_else')));
    await assertFails(updateDoc(doc(mod, 'users/alice'), { subscription: { tier: 'yearly', expires_at: Timestamp.now() } }));
    await assertFails(updateDoc(doc(mod, 'users/alice'), { is_premium: true }));
    await assertFails(updateDoc(doc(mod, 'users/alice'), { isActive: false }));
    // Re-writing an unchanged value is not a change; changing the role is denied.
    await assertFails(updateDoc(doc(mod, 'users/alice'), { ...banMap('mod'), role: 'admin' }));
    await assertFails(updateDoc(doc(mod, 'users/cm'), banMap('mod')));
    await assertFails(updateDoc(doc(mod, 'users/oldadmin'), banMap('mod')));
    // Support has view_users but not moderate_users.
    await assertFails(updateDoc(doc(db('sup', { role: 'support' }), 'users/alice'), banMap('sup')));
    // super_admin may ban anyone and change premium.
    const root = db('root', { role: 'super_admin' });
    await assertSucceeds(updateDoc(doc(root, 'users/cm'), banMap('root')));
    await assertSucceeds(updateDoc(doc(root, 'users/alice'), { subscription: { tier: 'yearly', expires_at: Timestamp.now() } }));
  });

  it('owners cannot set or clear ban fields on their own profile', async () => {
    await seed('users/alice', { ...freeProfile, role: 'student', is_banned: true, ban_reason: 'spam', banned_by: 'mod' });
    const a = db('alice');
    await assertFails(updateDoc(doc(a, 'users/alice'), { is_banned: false }));
    await assertFails(updateDoc(doc(a, 'users/alice'), { ban_reason: null }));
    await assertFails(updateDoc(doc(a, 'users/alice'), { banned_by: null }));
    await assertFails(setDoc(doc(db('bob'), 'users/bob'), { ...freeProfile, ban_reason: 'x' }));
  });

  it('reminder fields stay owner-writable (D12: enable, disable, sign-out token removal)', async () => {
    await seed('users/alice', { ...freeProfile, role: 'student', fcm_tokens: ['tok1'], daily_reminder_enabled: true });
    const a = db('alice');
    await assertSucceeds(
      setDoc(doc(a, 'users/alice'), { daily_reminder_enabled: false, fcm_tokens: arrayRemove('tok1'), reminder_timezone: 'Asia/Bishkek' }, { merge: true }),
    );
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

  it('content_manager may edit metadata of approved questions but not reviewed content (AUTH-ADM-04)', async () => {
    await seed('exam_questions/qa', {
      stem: 'x', options: [{ id: 'A', text: '1' }], topic_id: 't1', difficulty: 2, part_id: 'p1', language: 'ru',
      review: { status: 'methodologist_approved' }, content_hash: 'sha256:abc',
    });
    await seed('exam_questions/qr', { stem: 'y', review: { status: 'rejected' } });
    const cm = db('cm', { role: 'content_manager' });
    await assertSucceeds(
      updateDoc(doc(cm, 'exam_questions/qa'), { topic_id: 't2', difficulty: 3, part_id: 'p2', edited_in_cms_at: serverTimestamp(), updated_at: serverTimestamp() }),
    );
    await assertSucceeds(updateDoc(doc(cm, 'exam_questions/qa'), { translation_group_id: 'tg_1' }));
    await assertSucceeds(updateDoc(doc(cm, 'exam_questions/qr'), { translation_group_id: null }));
    await assertFails(updateDoc(doc(cm, 'exam_questions/qa'), { stem: 'changed' }));
    await assertFails(updateDoc(doc(cm, 'exam_questions/qa'), { table: { headers: ['A', 'B'], rows: [{ cells: ['1', '2'] }] } }));
    await assertFails(updateDoc(doc(cm, 'exam_questions/qa'), { review: { status: 'rejected' } }));
    // A content edit is allowed together with the reset to draft.
    await assertSucceeds(updateDoc(doc(cm, 'exam_questions/qa'), { stem: 'changed', review: { status: 'draft' } }));
  });

  it('answer keys: non-reviewers change `correct` only with a draft question (AUTH-ADM-07)', async () => {
    await seed('exam_questions/qa', { stem: 'x', review: { status: 'methodologist_approved' } });
    await seed('exam_question_keys/qa', { correct: 'A', explanation: 'old' });
    const cm = db('cm', { role: 'content_manager' });
    await assertFails(updateDoc(doc(cm, 'exam_question_keys/qa'), { correct: 'B' }));
    await assertSucceeds(updateDoc(doc(cm, 'exam_question_keys/qa'), { explanation: 'better explanation' }));
    // Key change + reset of the question to draft in the same batch (what the CMS does).
    const batch = writeBatch(cm);
    batch.update(doc(cm, 'exam_questions/qa'), { review: { status: 'draft' } });
    batch.set(doc(cm, 'exam_question_keys/qa'), { correct: 'B', explanation: 'x' });
    await assertSucceeds(batch.commit());
    // New draft question + key in one batch.
    const create = writeBatch(cm);
    create.set(doc(cm, 'exam_questions/qnew'), { stem: 'n', review: { status: 'draft' } });
    create.set(doc(cm, 'exam_question_keys/qnew'), { correct: 'C' });
    await assertSucceeds(create.commit());
    // A key for an approved question cannot be created by a non-reviewer.
    await seed('exam_questions/qb', { stem: 'x', review: { status: 'methodologist_approved' } });
    await assertFails(setDoc(doc(cm, 'exam_question_keys/qb'), { correct: 'D' }));
    // Reviewers write keys freely; only publish roles delete them.
    const me = db('me', { role: 'methodologist' });
    await assertSucceeds(setDoc(doc(me, 'exam_question_keys/qb'), { correct: 'D' }));
    await assertFails(deleteDoc(doc(me, 'exam_question_keys/qb')));
    await assertSucceeds(deleteDoc(doc(cm, 'exam_question_keys/qb')));
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
    await assertSucceeds(
      setDoc(doc(db('alice'), 'exam_attempts/a1/drafts/math'), { answers: { q1: 'B' }, client_updated_at: Date.now() }),
    );
    await assertFails(
      setDoc(doc(db('alice'), 'exam_attempts/a1/drafts/math'), { answers: { q1: 'B' }, client_updated_at: 'yesterday' }),
    );
  });

  it('accepts the exact map FirestoreExamDraftSink writes (D1, EXAM-01/SEC-DRAFT-01)', async () => {
    await seedAttempt('a1');
    const a = db('alice');
    // lib/features/exam/data/exam_draft_sink.dart: {answers, flags, client_updated_at: serverTimestamp()}
    const sinkMap = { answers: { q1: 'A', q2: null }, flags: ['q2'], client_updated_at: serverTimestamp() };
    await assertSucceeds(setDoc(doc(a, 'exam_attempts/a1/drafts/math'), sinkMap));
    await assertSucceeds(setDoc(doc(a, 'exam_attempts/a1/drafts/math'), { ...sinkMap, answers: { q1: 'B' } }));
    // The pre-D1 client map (extra keys) stays rejected.
    await assertFails(
      setDoc(doc(a, 'exam_attempts/a1/drafts/math'), {
        section_id: 'math', answers: { q1: 'A' }, flags: [], client_saved_at: Date.now(), updated_at: serverTimestamp(),
      }),
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

  it('super_admin, support and moderator read entitlements, ledger and user_stats (D6)', async () => {
    for (const role of ['super_admin', 'support', 'moderator']) {
      const s = db(`u_${role}`, { role });
      await assertSucceeds(getDoc(doc(s, 'entitlements/alice')));
      await assertSucceeds(getDocs(collection(s, 'entitlements/alice/ledger')));
      await assertSucceeds(getDoc(doc(s, 'user_stats/alice')));
      await assertFails(setDoc(doc(s, 'entitlements/alice'), { credits: 100 }));
      await assertFails(setDoc(doc(s, 'user_stats/alice'), { xp: 1 }));
    }
    for (const role of ['content_manager', 'methodologist']) {
      const s = db(`u_${role}`, { role });
      await assertFails(getDoc(doc(s, 'entitlements/alice')));
      await assertFails(getDoc(doc(s, 'entitlements/alice/ledger/l1')));
      await assertFails(getDoc(doc(s, 'user_stats/alice')));
    }
    await assertFails(getDoc(doc(db('bob'), 'entitlements/alice/ledger/l1')));
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
    // Exact maps of the client exam-review path (MistakesService reviewExamItem / markExamResolved).
    await assertSucceeds(
      setDoc(
        doc(a, 'user_mistakes/alice/items/eq1'),
        { next_review_at: Timestamp.fromMillis(Date.now() + 3 * 86_400_000), interval_days: 3, resolved: false,
          last_reviewed_at: serverTimestamp(), review_count: increment(1) },
        { merge: true },
      ),
    );
    await assertSucceeds(setDoc(doc(a, 'user_mistakes/alice/items/eq1'), { resolved: true, last_reviewed_at: serverTimestamp() }, { merge: true }));
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

  it('banned users cannot post or edit forum posts (D5)', async () => {
    await seed('users/troll', { ...freeProfile, is_banned: true });
    await seed('forum_posts/old', { author_uid: 'troll', text: 'before the ban' });
    const t = db('troll');
    await assertFails(setDoc(doc(t, 'forum_posts/f3'), { author_uid: 'troll', text: 'spam' }));
    await assertFails(updateDoc(doc(t, 'forum_posts/old'), { text: 'edited spam' }));
    await assertSucceeds(deleteDoc(doc(t, 'forum_posts/old')));
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

// ---------------------------------------------------------------------------
// Phase 3 (ARCHITECTURE §9): referrals, promo codes, friends, groups,
// assignments, broadcasts, achievements config. Client maps below are the
// shapes §9 defines.

describe('phase 3: server-only fields and collections', () => {
  it('users: referral_code, referred_by and group_ids are privileged (create and update)', async () => {
    await assertFails(setDoc(doc(db('alice'), 'users/alice'), { ...freeProfile, referral_code: 'ABC234' }));
    await assertFails(setDoc(doc(db('alice'), 'users/alice'), { ...freeProfile, referred_by: 'bob' }));
    await assertFails(setDoc(doc(db('alice'), 'users/alice'), { ...freeProfile, group_ids: ['g1'] }));
    await seed('users/alice', { ...freeProfile, role: 'student', referral_code: 'ABC234', group_ids: ['g1'] });
    const a = db('alice');
    await assertFails(updateDoc(doc(a, 'users/alice'), { referral_code: 'ZZZ999' }));
    await assertFails(updateDoc(doc(a, 'users/alice'), { referred_by: 'bob' }));
    await assertFails(updateDoc(doc(a, 'users/alice'), { group_ids: ['g1', 'g2'] }));
    await assertFails(updateDoc(doc(a, 'users/alice'), { group_ids: [] }));
    // Ordinary profile edits (merge) keep working with the server fields present.
    await assertSucceeds(
      setDoc(doc(a, 'users/alice'), { name: 'Aida', region: { oblast: 'Чуйская область', district: '', settlement: '' } }, { merge: true }),
    );
  });

  it('code reservations, promo / code attempt counters and broadcast quota are never client-accessible', async () => {
    await seed('referral_codes/ABC234', { uid: 'alice' });
    await seed('group_join_codes/XYZ789', { group_id: 'g1' });
    await seed('promo_attempts/alice_2026-11-05', { count: 3 });
    await seed('code_attempts/alice_2026-11-05', { uid: 'alice', day: '2026-11-05', count: 7 });
    await seed('notification_quota/2026-11-05', { count: 1 });
    const paths = [
      'referral_codes/ABC234',
      'group_join_codes/XYZ789',
      'promo_attempts/alice_2026-11-05',
      'code_attempts/alice_2026-11-05',
      'notification_quota/2026-11-05',
    ];
    for (const who of [db('alice'), db('root', { role: 'super_admin' })]) {
      for (const p of paths) {
        await assertFails(getDoc(doc(who, p)));
        await assertFails(setDoc(doc(who, p), { x: 1 }));
      }
    }
    await assertFails(getDocs(query(collection(db('alice'), 'referral_codes'), where('uid', '==', 'alice'))));
    await assertFails(getDocs(query(collection(db('alice'), 'code_attempts'), where('uid', '==', 'alice'))));
  });

  it('promo codes: students never read them; super_admin (grant_credits) reads codes and redemptions; nobody writes', async () => {
    await seed('promo_codes/WELCOME', { credits: 1, max_redemptions: null, redemptions: 1, expires_at: null, active: true, note: '', created_by: 'root' });
    await seed('promo_codes/WELCOME/redemptions/alice', { at: Timestamp.now() });
    await assertFails(getDoc(doc(db('alice'), 'promo_codes/WELCOME')));
    await assertFails(getDoc(doc(db('alice'), 'promo_codes/WELCOME/redemptions/alice')));
    await assertFails(getDocs(collection(db('alice'), 'promo_codes')));
    const root = db('root', { role: 'super_admin' });
    await assertSucceeds(getDocs(collection(root, 'promo_codes')));
    await assertSucceeds(getDoc(doc(root, 'promo_codes/WELCOME')));
    await assertSucceeds(getDocs(collection(root, 'promo_codes/WELCOME/redemptions')));
    await assertFails(setDoc(doc(root, 'promo_codes/NEW1'), { credits: 1, active: true }));
    await assertFails(updateDoc(doc(root, 'promo_codes/WELCOME'), { redemptions: 0 }));
    for (const role of ['content_manager', 'support', 'moderator', 'methodologist']) {
      await assertFails(getDoc(doc(db(`u_${role}`, { role }), 'promo_codes/WELCOME')));
    }
    await seed('users/legacy', { ...freeProfile, role: 'admin' });
    await assertSucceeds(getDoc(doc(db('legacy'), 'promo_codes/WELCOME')));
  });

  it('referrals: the referrer reads their counters and items; nobody writes', async () => {
    await seed('referrals/alice', { joined_total: 1, rewarded_total: 0, month_key: '2026-11', month_rewarded: 0 });
    await seed('referrals/alice/items/bob', { status: 'joined', joined_at: Timestamp.now(), display_name: 'Bob' });
    const a = db('alice');
    await assertSucceeds(getDoc(doc(a, 'referrals/alice')));
    await assertSucceeds(getDocs(collection(a, 'referrals/alice/items')));
    await assertSucceeds(getDoc(doc(a, 'referrals/alice/items/bob')));
    await assertFails(getDoc(doc(db('bob'), 'referrals/alice/items/bob')));
    await assertFails(getDocs(collection(db('bob'), 'referrals/alice/items')));
    await assertFails(setDoc(doc(a, 'referrals/alice/items/carol'), { status: 'rewarded', joined_at: Timestamp.now(), display_name: 'C' }));
    await assertFails(updateDoc(doc(a, 'referrals/alice/items/bob'), { status: 'rewarded' }));
    await assertFails(setDoc(doc(a, 'referrals/alice'), { month_rewarded: 0 }));
  });

  it('referrals: view_users roles (super_admin, moderator, support) read counters, items and the count() aggregate (§9.7)', async () => {
    await seed('referrals/alice', { joined_total: 2, rewarded_total: 1, month_key: '2026-11', month_rewarded: 1 });
    await seed('referrals/alice/items/bob', { status: 'rewarded', joined_at: Timestamp.now(), display_name: 'Bob' });
    await seed('referrals/alice/items/carol', { status: 'joined', joined_at: Timestamp.now(), display_name: 'Carol' });
    for (const role of ['super_admin', 'moderator', 'support']) {
      const s = db(`u_${role}`, { role });
      await assertSucceeds(getDoc(doc(s, 'referrals/alice')));
      await assertSucceeds(getDocs(collection(s, 'referrals/alice/items')));
      const agg = await assertSucceeds(getCountFromServer(collection(s, 'referrals/alice/items')));
      if (agg.data().count !== 2) throw new Error(`count() as ${role}: ${agg.data().count}`);
      // A user with no referrals: the CMS count is 0, not permission-denied.
      await assertSucceeds(getCountFromServer(collection(s, 'referrals/nobody/items')));
      await assertFails(setDoc(doc(s, 'referrals/alice/items/dave'), { status: 'joined' }));
    }
    for (const role of ['content_manager', 'methodologist']) {
      await assertFails(getCountFromServer(collection(db(`u_${role}`, { role }), 'referrals/alice/items')));
      await assertFails(getDoc(doc(db(`u_${role}`, { role }), 'referrals/alice')));
    }
    await assertFails(getCountFromServer(collection(db('bob'), 'referrals/alice/items')));
    await seed('users/legacy', { ...freeProfile, role: 'admin' });
    await assertSucceeds(getCountFromServer(collection(db('legacy'), 'referrals/alice/items')));
  });

  it('friends: the owner reads and deletes; only friendAdd creates', async () => {
    await seed('friends/alice/list/bob', { uid: 'bob', display_name: 'Bob', added_at: Timestamp.now() });
    const a = db('alice');
    await assertSucceeds(getDocs(collection(a, 'friends/alice/list')));
    await assertFails(getDocs(collection(db('bob'), 'friends/alice/list')));
    await assertFails(setDoc(doc(a, 'friends/alice/list/carol'), { display_name: 'Carol', added_at: serverTimestamp() }));
    await assertFails(updateDoc(doc(a, 'friends/alice/list/bob'), { display_name: 'Robert' }));
    await assertFails(deleteDoc(doc(db('bob'), 'friends/alice/list/bob')));
    await assertSucceeds(deleteDoc(doc(a, 'friends/alice/list/bob')));
  });

  it('notifications history: admin roles read, students do not, nobody writes', async () => {
    await seed('notifications/n1', {
      title: { ru: 't', ky: 't' }, body: { ru: 'b', ky: 'b' }, audience: { kind: 'all', value: null }, recipients: 3, sent: 3, failed: 0,
    });
    for (const role of ['super_admin', 'content_manager', 'methodologist', 'moderator', 'support']) {
      await assertSucceeds(getDoc(doc(db(`u_${role}`, { role }), 'notifications/n1')));
    }
    await assertSucceeds(getDocs(collection(db('cm', { role: 'content_manager' }), 'notifications')));
    await assertFails(getDoc(doc(db('alice'), 'notifications/n1')));
    await assertFails(setDoc(doc(db('root', { role: 'super_admin' }), 'notifications/n2'), { title: {} }));
  });

  it('config/achievements: signed-in read; manage_achievements roles write exactly {titles, descriptions, disabled}', async () => {
    const cfg = {
      titles: { streak_7: { ru: 'Неделя подряд', ky: 'Жума катары' } },
      descriptions: { streak_7: { ru: '7 дней подряд', ky: '7 күн катары' } },
      disabled: ['reader'],
    };
    for (const role of ['super_admin', 'content_manager']) {
      await assertSucceeds(setDoc(doc(db(`u_${role}`, { role }), 'config/achievements'), cfg));
    }
    const cm = db('cm', { role: 'content_manager' });
    await assertSucceeds(setDoc(doc(cm, 'config/achievements'), { disabled: [] }, { merge: true }));
    await assertSucceeds(getDoc(doc(db('alice'), 'config/achievements')));
    await assertFails(getDoc(doc(db(null), 'config/achievements')));
    await assertFails(setDoc(doc(db('alice'), 'config/achievements'), cfg));
    await assertFails(setDoc(doc(db('me', { role: 'methodologist' }), 'config/achievements'), cfg));
    await assertFails(setDoc(doc(cm, 'config/achievements'), { ...cfg, thresholds: { streak_7: 1 } }));
    await assertFails(setDoc(doc(cm, 'config/achievements'), { ...cfg, disabled: 'reader' }));
    await assertFails(setDoc(doc(cm, 'config/achievements'), { ...cfg, titles: 'x' }));
    await assertFails(deleteDoc(doc(db('root', { role: 'super_admin' }), 'config/achievements')));
  });

  it('region and group league boards are readable like every leaderboard, never writable', async () => {
    await seed('leaderboards/region_chuy_weekly_2026-W45/entries/alice', { uid: 'alice', xp: 10 });
    await seed('leaderboards/group_g1_weekly_2026-W45/entries/alice', { uid: 'alice', xp: 10 });
    await assertSucceeds(getDocs(collection(db('bob'), 'leaderboards/region_chuy_weekly_2026-W45/entries')));
    await assertSucceeds(getDoc(doc(db('bob'), 'leaderboards/group_g1_weekly_2026-W45/entries/alice')));
    await assertFails(setDoc(doc(db('alice'), 'leaderboards/group_g1_weekly_2026-W45/entries/alice'), { xp: 1e6 }));
  });
});

describe('phase 3: groups, assignments, submissions', () => {
  const due = () => Timestamp.fromMillis(Date.now() + 7 * 86_400_000);
  // Exact client maps (ARCHITECTURE §9.3).
  const assignmentMap = (owner) => ({
    title: 'Повторить квадратные уравнения',
    kind: 'lesson',
    ref_id: 'math_quadratic_1',
    due_at: due(),
    created_by: owner,
    created_at: serverTimestamp(),
  });
  const submissionMap = { done_at: serverTimestamp(), score_percent: 80 };

  beforeEach(async () => {
    await seed('groups/g1', { name: '11А', owner_uid: 'teacher', join_code: 'ABC234', member_count: 2, created_at: Timestamp.now() });
    await seed('groups/g1/members/teacher', { uid: 'teacher', display_name: 'Teacher', role: 'owner', joined_at: Timestamp.now() });
    await seed('groups/g1/members/alice', { uid: 'alice', display_name: 'Aida', role: 'member', joined_at: Timestamp.now() });
    await seed('groups/g1/assignments/a1', { ...assignmentMap('teacher'), created_at: Timestamp.now() });
    await seed('groups/g1/assignments/a1/submissions/alice', { done_at: Timestamp.now() });
  });

  it('members read the group, its members and assignments; outsiders do not', async () => {
    for (const uid of ['teacher', 'alice']) {
      const c = db(uid);
      await assertSucceeds(getDoc(doc(c, 'groups/g1')));
      await assertSucceeds(getDocs(collection(c, 'groups/g1/members')));
      await assertSucceeds(getDocs(collection(c, 'groups/g1/assignments')));
    }
    const out = db('mallory');
    await assertFails(getDoc(doc(out, 'groups/g1')));
    await assertFails(getDocs(collection(out, 'groups/g1/members')));
    await assertFails(getDoc(doc(out, 'groups/g1/assignments/a1')));
  });

  it('view_users roles read the group document only (CMS user card, §9.7); sub-collections stay member-only', async () => {
    for (const role of ['super_admin', 'moderator', 'support']) {
      const s = db(`u_${role}`, { role });
      await assertSucceeds(getDoc(doc(s, 'groups/g1')));
      // A deleted group reads as missing (not denied) for staff.
      await assertSucceeds(getDoc(doc(s, 'groups/gone')));
      await assertFails(getDocs(collection(s, 'groups/g1/members')));
      await assertFails(getDoc(doc(s, 'groups/g1/assignments/a1')));
      await assertFails(getDoc(doc(s, 'groups/g1/assignments/a1/submissions/alice')));
      await assertFails(updateDoc(doc(s, 'groups/g1'), { name: 'Renamed' }));
      // Listing every group would expose every join_code.
      await assertFails(getDocs(collection(s, 'groups')));
      await assertFails(getDocs(collection(s, 'referrals')));
    }
    for (const role of ['content_manager', 'methodologist']) {
      await assertFails(getDoc(doc(db(`u_${role}`, { role }), 'groups/g1')));
    }
  });

  it('removed-member markers are server only (§9.7)', async () => {
    await seed('groups/g1/removed/mallory', { uid: 'mallory', by: 'teacher', at: Timestamp.now() });
    for (const who of [db('teacher'), db('alice'), db('mallory'), db('root', { role: 'super_admin' })]) {
      await assertFails(getDoc(doc(who, 'groups/g1/removed/mallory')));
      await assertFails(getDocs(collection(who, 'groups/g1/removed')));
      await assertFails(deleteDoc(doc(who, 'groups/g1/removed/mallory')));
    }
    await assertFails(setDoc(doc(db('teacher'), 'groups/g1/removed/alice'), { uid: 'alice' }));
  });

  it('nobody writes groups or members directly (callables only)', async () => {
    await assertFails(updateDoc(doc(db('teacher'), 'groups/g1'), { member_count: 99 }));
    await assertFails(updateDoc(doc(db('teacher'), 'groups/g1'), { name: 'Renamed' }));
    await assertFails(
      setDoc(doc(db('mallory'), 'groups/g1/members/mallory'), { uid: 'mallory', display_name: 'M', role: 'member', joined_at: serverTimestamp() }),
    );
    await assertFails(setDoc(doc(db('alice'), 'groups/g1/members/alice'), { role: 'owner' }, { merge: true }));
    await assertFails(deleteDoc(doc(db('teacher'), 'groups/g1/members/alice')));
    await assertFails(setDoc(doc(db('mallory'), 'groups/g2'), { name: 'x', owner_uid: 'mallory', join_code: 'ZZZ999', member_count: 1 }));
  });

  it('the owner creates, edits and deletes assignments with the §9 map', async () => {
    const t = db('teacher');
    await assertSucceeds(setDoc(doc(t, 'groups/g1/assignments/a2'), assignmentMap('teacher')));
    await assertSucceeds(
      setDoc(doc(t, 'groups/g1/assignments/a3'), { ...assignmentMap('teacher'), kind: 'exam_variant', ref_id: 'ort_main_ru_1', due_at: null }),
    );
    await assertSucceeds(setDoc(doc(t, 'groups/g1/assignments/a4'), { ...assignmentMap('teacher'), kind: 'practice', ref_id: 'math' }));
    // "Quick practice" (§9.7): kind practice with an empty ref_id.
    await assertSucceeds(setDoc(doc(t, 'groups/g1/assignments/a5'), { ...assignmentMap('teacher'), kind: 'practice', ref_id: '' }));
    await assertSucceeds(updateDoc(doc(t, 'groups/g1/assignments/a5'), { title: 'Быстрая практика', updated_at: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(t, 'groups/g1/assignments/a2'), { title: 'Новый заголовок', due_at: due() }));
    await assertSucceeds(updateDoc(doc(t, 'groups/g1/assignments/a2'), { description: 'Страницы 1–3', updated_at: serverTimestamp() }));
    await assertSucceeds(deleteDoc(doc(t, 'groups/g1/assignments/a4')));
  });

  it('assignments: members, outsiders and malformed maps are rejected', async () => {
    await assertFails(setDoc(doc(db('alice'), 'groups/g1/assignments/x'), assignmentMap('alice')));
    await assertFails(setDoc(doc(db('mallory'), 'groups/g1/assignments/x'), assignmentMap('mallory')));
    await assertFails(deleteDoc(doc(db('alice'), 'groups/g1/assignments/a1')));
    const t = db('teacher');
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), assignmentMap('someone_else')));
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), { ...assignmentMap('teacher'), kind: 'video' }));
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), { ...assignmentMap('teacher'), title: '' }));
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), { ...assignmentMap('teacher'), title: 'x'.repeat(121) }));
    // An empty ref_id is only allowed for kind 'practice' (§9.7).
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), { ...assignmentMap('teacher'), ref_id: '' }));
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), { ...assignmentMap('teacher'), kind: 'exam_variant', ref_id: '' }));
    await assertFails(updateDoc(doc(t, 'groups/g1/assignments/a1'), { ref_id: '' }));
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), { ...assignmentMap('teacher'), kind: 'practice', ref_id: 'x'.repeat(151) }));
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), { ...assignmentMap('teacher'), kind: 'practice', ref_id: null }));
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), { ...assignmentMap('teacher'), due_at: 'next week' }));
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), { ...assignmentMap('teacher'), points: 10 }));
    const { created_at: _omit, ...noCreatedAt } = assignmentMap('teacher');
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), noCreatedAt));
    await assertFails(updateDoc(doc(t, 'groups/g1/assignments/a1'), { created_by: 'alice' }));
    await assertFails(updateDoc(doc(t, 'groups/g1/assignments/a1'), { created_at: Timestamp.fromMillis(0) }));
    // A banned owner cannot publish homework.
    await seed('users/teacher', { ...freeProfile, is_banned: true });
    await assertFails(setDoc(doc(t, 'groups/g1/assignments/x'), assignmentMap('teacher')));
  });

  it('submissions: a member writes only their own {done_at, score_percent?}', async () => {
    const a = db('alice');
    const own = 'groups/g1/assignments/a1/submissions/alice';
    await assertSucceeds(setDoc(doc(a, own), submissionMap));
    await assertSucceeds(setDoc(doc(a, own), { done_at: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(a, own), { done_at: serverTimestamp(), score_percent: 66.7 }));
    await assertSucceeds(setDoc(doc(a, own), { done_at: serverTimestamp(), score_percent: null }));
    await assertFails(setDoc(doc(a, 'groups/g1/assignments/a1/submissions/teacher'), submissionMap));
    await assertFails(setDoc(doc(a, own), { done_at: serverTimestamp(), score_percent: 101 }));
    await assertFails(setDoc(doc(a, own), { done_at: serverTimestamp(), score_percent: -1 }));
    await assertFails(setDoc(doc(a, own), { done_at: 'today' }));
    await assertFails(setDoc(doc(a, own), { ...submissionMap, verified: true }));
    await assertFails(setDoc(doc(a, 'groups/g1/assignments/missing/submissions/alice'), submissionMap));
    await assertFails(setDoc(doc(db('mallory'), 'groups/g1/assignments/a1/submissions/mallory'), submissionMap));
  });

  it('submissions: the owner reads all; a member reads only their own', async () => {
    await seed('groups/g1/members/bob', { uid: 'bob', display_name: 'Bob', role: 'member', joined_at: Timestamp.now() });
    await assertSucceeds(getDocs(collection(db('teacher'), 'groups/g1/assignments/a1/submissions')));
    await assertSucceeds(getDoc(doc(db('alice'), 'groups/g1/assignments/a1/submissions/alice')));
    await assertFails(getDoc(doc(db('bob'), 'groups/g1/assignments/a1/submissions/alice')));
    await assertFails(getDocs(collection(db('bob'), 'groups/g1/assignments/a1/submissions')));
    await assertFails(getDoc(doc(db('mallory'), 'groups/g1/assignments/a1/submissions/alice')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'groups/g1/assignments/a1/submissions/alice')));
  });
});

describe('phase 4 (ARCHITECTURE §10): generated variants, exam pool config, web payments', () => {
  const generated = {
    status: 'generated', source: 'fresh', generated_for: 'alice', attempt_id: 'att1', blueprint_id: 'ort_main_2026',
    language: 'ru', number: 0, sections: [{ section_id: 'math', question_ids: ['q1'] }], seed: 'abc',
  };

  beforeEach(async () => {
    await seed('exam_variants/fresh_att1', generated);
    await seed('exam_variants/pub', { status: 'published', blueprint_id: 'ort_main_2026', number: 1, language: 'ru' });
  });

  it('students never read a generated variant, not even the one assembled for them', async () => {
    await assertFails(getDoc(doc(db('alice'), 'exam_variants/fresh_att1')));
    await assertFails(getDoc(doc(db('bob'), 'exam_variants/fresh_att1')));
    await assertFails(getDoc(doc(db(null), 'exam_variants/fresh_att1')));
    // The library query (published only) keeps working and never returns it.
    const lib = await assertSucceeds(getDocs(query(collection(db('alice'), 'exam_variants'), where('status', '==', 'published'))));
    if (lib.docs.map((d) => d.id).join() !== 'pub') throw new Error(`library returned ${lib.docs.map((d) => d.id).join()}`);
    await assertFails(getDocs(query(collection(db('alice'), 'exam_variants'), where('generated_for', '==', 'alice'))));
  });

  it('content roles read generated variants (CMS / support), but nobody creates, edits or deletes them', async () => {
    const cm = db('cm', { role: 'content_manager' });
    const sa = db('sa', { role: 'super_admin' });
    await assertSucceeds(getDoc(doc(cm, 'exam_variants/fresh_att1')));
    await assertSucceeds(getDocs(query(collection(cm, 'exam_variants'), where('blueprint_id', '==', 'ort_main_2026'))));
    await assertFails(updateDoc(doc(cm, 'exam_variants/fresh_att1'), { status: 'draft' }));
    await assertFails(updateDoc(doc(sa, 'exam_variants/fresh_att1'), { status: 'archived' }));
    await assertFails(deleteDoc(doc(sa, 'exam_variants/fresh_att1')));
    await assertFails(setDoc(doc(cm, 'exam_variants/fresh_forged'), { ...generated }));
    await assertFails(setDoc(doc(sa, 'exam_variants/fresh_forged'), { ...generated }));
    // Drafts stay editable and deletable as before.
    await assertSucceeds(setDoc(doc(cm, 'exam_variants/d1'), { status: 'draft', blueprint_id: 'ort_main_2026' }));
    await assertSucceeds(deleteDoc(doc(sa, 'exam_variants/d1')));
  });

  it('config/exam_pool: signed-in read, never written by a client', async () => {
    await seed('config/exam_pool', { fresh_enabled: true, min_review_status: 'methodologist_approved' });
    await assertSucceeds(getDoc(doc(db('alice'), 'config/exam_pool')));
    await assertFails(getDoc(doc(db(null), 'config/exam_pool')));
    await assertFails(setDoc(doc(db('alice'), 'config/exam_pool'), { fresh_enabled: false }));
    await assertFails(setDoc(doc(db('sa', { role: 'super_admin' }), 'config/exam_pool'), { min_review_status: 'ai_verified' }));
    await assertFails(deleteDoc(doc(db('sa', { role: 'super_admin' }), 'config/exam_pool')));
  });

  it('payment_orders: the owner reads own orders, super_admin and support read all; nobody writes', async () => {
    const order = (uid) => ({
      uid, product_id: 'exam_single', credits: 1, amount_som: 100, currency: 'KGS', provider: 'sandbox',
      status: 'pending', granted: false, created_at: Timestamp.now(),
    });
    await seed('payment_orders/o_alice', order('alice'));
    await seed('payment_orders/o_bob', order('bob'));
    const a = db('alice');
    await assertSucceeds(getDoc(doc(a, 'payment_orders/o_alice')));
    await assertFails(getDoc(doc(a, 'payment_orders/o_bob')));
    await assertSucceeds(getDocs(query(collection(a, 'payment_orders'), where('uid', '==', 'alice'))));
    await assertFails(getDocs(collection(a, 'payment_orders')));
    await assertFails(getDoc(doc(db(null), 'payment_orders/o_alice')));
    for (const role of ['super_admin', 'support']) {
      const staff = db(`staff_${role}`, { role });
      await assertSucceeds(getDoc(doc(staff, 'payment_orders/o_bob')));
      await assertSucceeds(getDocs(query(collection(staff, 'payment_orders'), where('status', '==', 'pending'))));
    }
    for (const role of ['moderator', 'content_manager', 'methodologist']) {
      await assertFails(getDoc(doc(db(`staff_${role}`, { role }), 'payment_orders/o_bob')));
    }
    // No client writes: not the owner, not the staff.
    await assertFails(setDoc(doc(a, 'payment_orders/o_new'), order('alice')));
    await assertFails(updateDoc(doc(a, 'payment_orders/o_alice'), { status: 'paid', granted: true }));
    await assertFails(deleteDoc(doc(a, 'payment_orders/o_alice')));
    await assertFails(updateDoc(doc(db('sa', { role: 'super_admin' }), 'payment_orders/o_alice'), { status: 'refunded' }));
  });

  it('payment_events and payment_attempts are server only', async () => {
    await seed('payment_events/sandbox_evt1', { provider: 'sandbox', order_id: 'o_alice', status: 'paid', result: 'granted' });
    await seed('payment_attempts/alice_2026-11-05', { uid: 'alice', day: '2026-11-05', count: 1 });
    for (const who of [db('alice'), db('sa', { role: 'super_admin' }), db('sup', { role: 'support' })]) {
      await assertFails(getDoc(doc(who, 'payment_events/sandbox_evt1')));
      await assertFails(setDoc(doc(who, 'payment_events/sandbox_evt2'), { status: 'paid' }));
      await assertFails(getDoc(doc(who, 'payment_attempts/alice_2026-11-05')));
      await assertFails(setDoc(doc(who, 'payment_attempts/alice_2026-11-05'), { count: 0 }));
    }
  });
});
