// End-to-end test of the ORT backend on the Firebase emulators.
//
// The Admin SDK seeds the real ORT 2026 blueprints (assets/data/exam_blueprints.json)
// and synthetic but structurally complete variants. A real client SDK then plays
// the student: every client read/write goes through firestore.rules exactly as
// the app's would, and every callable runs the deployed functions code
// (functions/lib, built with `npm run build`).
//
// Run: cd tests/e2e && npm install && npm test   (needs Java 21 for the emulators)
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import { initializeApp as initAdmin } from 'firebase-admin/app';
import { getFirestore as adminDb, FieldValue } from 'firebase-admin/firestore';
import { getAuth as adminAuth } from 'firebase-admin/auth';

import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, collection, query, where, getDocs, serverTimestamp, terminate, Timestamp } from 'firebase/firestore';
import { getFunctions, connectFunctionsEmulator, httpsCallable } from 'firebase/functions';

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-ort-e2e';
const REGION = 'europe-west1';
const here = path.dirname(fileURLToPath(import.meta.url));
const blueprints = JSON.parse(readFileSync(path.join(here, '../../assets/data/exam_blueprints.json'), 'utf8')).blueprints;

const admin = initAdmin({ projectId: PROJECT }, 'admin');
const db = adminDb(admin);
const auth = adminAuth(admin);

// ---------------------------------------------------------------- seeding

/** Synthetic questions that satisfy a blueprint section exactly (parts, option counts, passages). */
function seedQuestions(bp, section, lang, prefix, batch) {
  const ids = [];
  let n = 0;
  for (const part of section.parts) {
    for (let i = 0; i < part.question_count; i++) {
      n++;
      const id = `${prefix}_${section.id}_${n}`;
      const optionsCount = part.options_per_question;
      const isQc = part.item_type === 'quantitative_comparison';
      const passageId = part.item_type === 'text_based' ? `${prefix}_${section.id}_p${Math.floor(i / 10)}` : null;
      batch.set(db.doc(`exam_questions/${id}`), {
        subject_id: bp.subject_id ?? section.subject_area, section_id: section.id, part_id: part.id,
        topic_id: `${section.subject_area}.e2e_topic_${i % 3}`, difficulty: 1 + (i % 3), language: lang,
        type: isQc ? 'quantitative_comparison' : part.item_type, stem: isQc ? 'Сравните величины.' : `E2E вопрос ${n}: $2+2=?$`,
        options: isQc ? part.fixed_options.map((o) => ({ id: o.id, text: o.text[lang] ?? o.text.ru }))
                      : Array.from({ length: optionsCount }, (_, k) => ({ id: String.fromCharCode(65 + k), text: `${k + 3}` })),
        column_a: isQc ? '2 + 2' : null, column_b: isQc ? '5' : null,
        // Firestore storage shape for tables (decision D2): rows as {cells}.
        table: isQc ? { headers: ['А', 'Б'], rows: [{ cells: ['2 + 2', '5'] }] } : null,
        passage_id: passageId, image_path: null,
        review: { status: 'methodologist_approved' }, content_version: 1,
        source: { kind: 'original', basis: 'e2e fixture' },
      });
      // Correct answer: B for comparison (Б больше), A otherwise.
      batch.set(db.doc(`exam_question_keys/${id}`), { correct: isQc ? 'B' : 'A', explanation: 'E2E объяснение', wrong_option_notes: {}, solution_steps: [] });
      if (passageId) batch.set(db.doc(`exam_passages/${passageId}`), { language: lang, title: 'Текст', text: 'Строка 1\nСтрока 2\nСтрока 3\nСтрока 4\nСтрока 5' });
      ids.push(id);
    }
  }
  return ids;
}

async function seedVariant(bp, variantId, lang) {
  const sections = [];
  for (const section of bp.sections) {
    const batch = db.batch();
    sections.push({ section_id: section.id, question_ids: seedQuestions(bp, section, lang, variantId, batch) });
    await batch.commit();
  }
  await db.doc(`exam_variants/${variantId}`).set({
    blueprint_id: bp.id, blueprint_version: bp.version, number: 1, title: { ru: 'E2E вариант', ky: 'E2E вариант' },
    language: lang, status: 'published', sections, content_version: 1, created_by: 'e2e',
  });
  return sections;
}

const mainBp = blueprints.find((b) => b.id === 'ort_main_2026');
const chemBp = blueprints.find((b) => b.id === 'ort_subject_chemistry_2026');

// ---------------------------------------------------------------- client helpers

let app;
let cAuth;
let cDb;
let fns;
const call = (name) => async (data) => (await httpsCallable(fns, name, { timeout: 120_000 })(data)).data;
async function expectReason(promise, reason) {
  try {
    await promise;
  } catch (e) {
    const got = e?.details?.reason ?? e?.code;
    assert.equal(got, reason, `expected ${reason}, got ${got} (${e?.message})`);
    return e;
  }
  assert.fail(`expected ${reason}, but the call succeeded`);
}
async function expectDenied(promise) {
  await assert.rejects(promise, (e) => /permission|PERMISSION_DENIED/i.test(String(e?.code) + String(e?.message)));
}

const STUDENT = { email: 'student.e2e@example.test', password: 'e2e-Passw0rd!' };
const ADMIN = { email: 'admin.e2e@example.test', password: 'e2e-Adm1n-Passw0rd!' };
let studentUid;
let mainSections;

before(async () => {
  for (const bp of blueprints) await db.doc(`exam_blueprints/${bp.id}`).set(bp);
  await db.doc('config/pricing').set({ free_exams_per_user: 1, products: { exam_single: { credits: 1 }, exam_pack_5: { credits: 5 }, exam_pack_10: { credits: 10 } } });
  mainSections = await seedVariant(mainBp, 'e2e_main_ru_1', 'ru');
  await seedVariant(chemBp, 'e2e_chem_ru_1', 'ru');
  await db.doc('lessons/e2e_lesson_1').set({ id: 'e2e_lesson_1', subjectId: 'math', order: 1, title: { ru: 'E2E урок', ky: 'E2E сабак' } });

  const adminUser = await auth.createUser({ email: ADMIN.email, password: ADMIN.password, emailVerified: true });
  await auth.setCustomUserClaims(adminUser.uid, { role: 'super_admin' });

  app = initializeApp({ apiKey: 'demo-key', projectId: PROJECT, appId: '1:1:web:e2e' }, 'client');
  cAuth = getAuth(app);
  connectAuthEmulator(cAuth, 'http://127.0.0.1:9099', { disableWarnings: true });
  cDb = getFirestore(app);
  connectFirestoreEmulator(cDb, '127.0.0.1', 8080);
  fns = getFunctions(app, REGION);
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);

  const cred = await createUserWithEmailAndPassword(cAuth, STUDENT.email, STUDENT.password);
  studentUid = cred.user.uid;
  // Profile created by the app at sign-up (only fields the rules allow).
  await setDoc(doc(cDb, 'users', studentUid), {
    name: 'E2E Student', email: STUDENT.email, grade: 11, preferred_language: 'ru', role: 'student',
    subscription: { tier: 'free', expires_at: null }, created_at: serverTimestamp(),
  });
});

after(async () => {
  if (app) {
    await terminate(cDb).catch(() => {});
    await deleteApp(app).catch(() => {});
  }
});

/** topic_id seedQuestions gives the k-th question of a blueprint section (mirrors the fixture above). */
function e2eTopic(section, k) {
  let offset = 0;
  for (const part of section.parts) {
    if (k < offset + part.question_count) return `${section.subject_area}.e2e_topic_${(k - offset) % 3}`;
    offset += part.question_count;
  }
  return null;
}

// ---------------------------------------------------------------- the student journey

let attemptId;

test('security: a student cannot read answer keys, questions or other users', async () => {
  const anyQid = mainSections[0].question_ids[0];
  await expectDenied(getDoc(doc(cDb, 'exam_question_keys', anyQid)));
  await expectDenied(getDoc(doc(cDb, 'exam_questions', anyQid)));
  await expectDenied(setDoc(doc(cDb, 'users', studentUid), { role: 'admin' }, { merge: true }));
  await expectDenied(setDoc(doc(cDb, 'entitlements', studentUid), { credits: 99 }, { merge: true }));
  await expectDenied(setDoc(doc(cDb, 'user_stats', studentUid), { xp: 1e6 }, { merge: true }));
});

test('first full mock exam is free; payload carries only the current section without keys', async () => {
  const p = await call('examStart')({ variantId: 'e2e_main_ru_1', clientAppVersion: 'e2e' });
  attemptId = p.attemptId;
  assert.ok(attemptId);
  assert.equal(p.entitlementSource, 'free_first');
  assert.equal(p.section.sectionId, 'math');
  assert.equal(p.section.questions.length, 60);
  assert.equal(p.section.durationSec, 90 * 60);
  const json = JSON.stringify(p);
  assert.ok(!/"correct"|explanation|exam_question_keys/.test(json), 'payload must not leak keys');
  const qc = p.section.questions.find((q) => q.type === 'quantitative_comparison');
  assert.ok(qc, 'math part I comparison items present');
  assert.equal(qc.options.length, 4);
  assert.deepEqual(qc.table?.rows, [['2 + 2', '5']], 'table normalized to wire shape (D2)');
  const ent = (await getDoc(doc(cDb, 'entitlements', studentUid))).data();
  assert.equal(ent.free_exam_used, true);
  // Same variant again = resume, no second free claim.
  const again = await call('examStart')({ variantId: 'e2e_main_ru_1' });
  assert.equal(again.attemptId, attemptId);
});

test('AI tutor is blocked while an exam is in progress (D8)', async () => {
  await expectReason(call('aiTutor')({ mode: 'chat', message: 'Реши задачу 1', language: 'ru' }), 'AI_EXAM_IN_PROGRESS');
});

test('draft autosave with the exact client map is allowed; other sections are not (D1)', async () => {
  const qids = mainSections[0].question_ids;
  await setDoc(doc(cDb, 'exam_attempts', attemptId, 'drafts', 'math'), {
    answers: { [qids[0]]: 'B', [qids[1]]: 'A' }, flags: [qids[2]], client_updated_at: serverTimestamp(),
  });
  await expectDenied(setDoc(doc(cDb, 'exam_attempts', attemptId, 'drafts', 'verbal'), {
    answers: {}, flags: [], client_updated_at: serverTimestamp(),
  }));
  await expectDenied(setDoc(doc(cDb, 'exam_attempts', attemptId, 'drafts', 'math'), {
    answers: {}, flags: [], client_updated_at: serverTimestamp(), section_id: 'math',
  }));
});

test('sections are forward-only and the attempt completes with an honest result', async () => {
  // Wrong section is rejected.
  await expectReason(call('examSubmitSection')({ attemptId, sectionId: 'reading', answers: {}, flags: [] }), 'WRONG_SECTION');
  let expectedCorrect = 0;
  let expectedSkipped = 0;
  let last;
  for (const [i, sec] of mainSections.entries()) {
    const answers = {};
    // Per-question seconds (ARCHITECTURE §9.5): topic *_0 questions take 90 s,
    // the others 20 s, so every *.e2e_topic_0 topic is "slow" (> 1.5 × median 20 s).
    const timings = { not_in_this_section: 10 };
    const bpSection = mainBp.sections.find((s) => s.id === sec.section_id);
    sec.question_ids.forEach((qid, k) => {
      timings[qid] = e2eTopic(bpSection, k).endsWith('_0') ? 90 : 20;
    });
    sec.question_ids.forEach((qid, k) => {
      if (k % 5 === 4) { expectedSkipped++; return; } // leave every 5th unanswered
      const isQc = sec.section_id === 'math' && k < 30;
      const right = k % 2 === 0;
      answers[qid] = right ? (isQc ? 'B' : 'A') : 'C';
      if (right) expectedCorrect++;
    });
    last = await call('examSubmitSection')({ attemptId, sectionId: sec.section_id, answers, flags: [], clientElapsedSec: 60, timings });
    if (i < mainSections.length - 1) {
      assert.equal(last.completed, false);
      assert.equal(last.next.section.sectionId, mainSections[i + 1].section_id);
    }
  }
  assert.equal(last.completed, true);
  const r = last.result;
  assert.equal(r.total, 150);
  assert.equal(r.correct, expectedCorrect);
  assert.equal(r.skipped, expectedSkipped);
  assert.equal(r.incorrect, 150 - expectedCorrect - expectedSkipped);
  assert.equal(r.sections.length, 4);
  assert.ok(r.xp_awarded > 0);
  // Timings -> topic_time_avg / slow_topics (ARCHITECTURE §9.5).
  assert.equal(r.topic_time_avg['math.e2e_topic_0'], 90);
  assert.equal(r.topic_time_avg['math.e2e_topic_1'], 20);
  assert.ok(r.slow_topics.includes('math.e2e_topic_0') && r.slow_topics.includes('reading.e2e_topic_0'), r.slow_topics.join());
  assert.ok(r.slow_topics.every((t) => t.endsWith('.e2e_topic_0')), r.slow_topics.join());
  const mathAnswers = (await getDoc(doc(cDb, 'exam_attempts', attemptId, 'answers', 'math'))).data();
  assert.equal(mathAnswers.timings[mainSections[0].question_ids[0]], 90);
  assert.equal(mathAnswers.timings.not_in_this_section, undefined, 'foreign question ids are dropped');
  // A completed section cannot be reopened: a re-submit is either refused or
  // replayed idempotently, and never changes the stored result.
  let replay = null;
  try {
    replay = await call('examSubmitSection')({ attemptId, sectionId: 'math', answers: {}, flags: [] });
  } catch (e) {
    assert.equal(e?.details?.reason, 'ATTEMPT_NOT_IN_PROGRESS');
  }
  if (replay) {
    assert.equal(replay.completed, true);
    assert.equal(replay.result.correct, r.correct);
  }
});

test('review exposes keys and explanations only after completion', async () => {
  const review = await call('examGetReview')({ attemptId });
  assert.equal(review.items.length, 150);
  const first = review.items[0];
  assert.ok(first.correct, 'correct answer present after completion');
  assert.ok(first.explanation);
});

test('without a configured key the tutor is unavailable and spends no quota', async () => {
  // The emulator has no ANTHROPIC_API_KEY secret: the function must not fall
  // back to ambient credentials and must not count the request.
  await expectReason(call('aiTutor')({ mode: 'chat', message: 'Что такое дискриминант?', language: 'ru' }), 'AI_DISABLED');
  const usage = await db.collection(`ai_usage/${studentUid}/days`).get();
  assert.equal(usage.size, 0, 'no quota reserved');
});

test('server-owned stats, leaderboards and exam mistakes were written', async () => {
  const stats = (await getDoc(doc(cDb, 'user_stats', studentUid))).data();
  assert.ok(stats.xp > 0);
  assert.equal(stats.exams_completed, 1);
  const mistakes = await getDocs(collection(cDb, 'user_mistakes', studentUid, 'items'));
  assert.ok(mistakes.size > 0, 'wrong answers queued for review');
  assert.ok(mistakes.docs.every((d) => d.data().source === 'exam'));
  const allTime = await getDoc(doc(cDb, 'leaderboards', 'all_time', 'entries', studentUid));
  assert.ok(allTime.exists(), 'all-time leaderboard entry');
  // The student can reschedule an exam mistake (SRS fields only)…
  const m = mistakes.docs[0];
  await setDoc(m.ref, { next_review_at: new Date(Date.now() + 3 * 864e5), interval_days: 3, resolved: false, last_reviewed_at: serverTimestamp() }, { merge: true });
  // …but cannot forge exam-sourced mistakes.
  await expectDenied(setDoc(doc(cDb, 'user_mistakes', studentUid, 'items', 'forged'), { question_id: 'forged', source: 'exam', wrong_count: 1 }));
});

test('without free exams or credits a new attempt is refused (NO_ENTITLEMENT)', async () => {
  await expectReason(call('examStart')({ variantId: 'e2e_chem_ru_1' }), 'NO_ENTITLEMENT');
});

test('an admin credit grant unlocks exactly one paid attempt', async () => {
  await signOut(cAuth);
  await signInWithEmailAndPassword(cAuth, ADMIN.email, ADMIN.password);
  await cAuth.currentUser.getIdToken(true);
  const g = await call('adminGrantCredits')({ uid: studentUid, delta: 1, reason: 'e2e grant' });
  assert.equal(g.credits, 1);
  const logs = await getDocs(query(collection(cDb, 'admin_logs'), where('action', '==', 'grant_credits')));
  assert.ok(logs.size >= 1, 'admin action is logged');
  await signOut(cAuth);
  await signInWithEmailAndPassword(cAuth, STUDENT.email, STUDENT.password);

  const p = await call('examStart')({ variantId: 'e2e_chem_ru_1' });
  assert.equal(p.entitlementSource, 'credit');
  assert.equal(p.section.questions.length, 40);
  const ent = (await getDoc(doc(cDb, 'entitlements', studentUid))).data();
  assert.equal(ent.credits, 0);
  const ledger = await getDocs(collection(cDb, 'entitlements', studentUid, 'ledger'));
  assert.ok(ledger.size >= 3, 'free_first, admin_grant and exam_start are all in the ledger');
});

// ---------------------------------------------------------------- phase 3 (ARCHITECTURE §9)

const FRIEND = { email: 'friend.e2e@example.test', password: 'e2e-Fr1end-Passw0rd!' };
const NEWBIE = { email: 'newbie.e2e@example.test', password: 'e2e-N3wbie-Passw0rd!' };
let friendUid;
let newbieUid;
let friendCode;
let groupId;
let assignmentId;
const INTRUDER = { email: 'intruder.e2e@example.test', password: 'e2e-Intr0der-Passw0rd!' };

/** Sum of the code_attempts counters of `uid` (groupJoin + friendAdd, §9.7). */
async function codeAttempts(uid) {
  const snap = await db.collection('code_attempts').where('uid', '==', uid).get();
  return snap.docs.reduce((n, d) => n + (d.get('count') ?? 0), 0);
}

async function signInAs(user) {
  await signOut(cAuth);
  await signInWithEmailAndPassword(cAuth, user.email, user.password);
  await cAuth.currentUser.getIdToken(true);
}

/** Signs up a new student and creates the profile the way the app does. */
async function signUp(user, name, language) {
  await signOut(cAuth);
  const cred = await createUserWithEmailAndPassword(cAuth, user.email, user.password);
  await setDoc(doc(cDb, 'users', cred.user.uid), {
    name, email: user.email, grade: 11, preferred_language: language, role: 'student',
    subscription: { tier: 'free', expires_at: null }, created_at: serverTimestamp(),
  });
  return cred.user.uid;
}

test('promo codes: the admin creates one, a student redeems it once (ALREADY_REDEEMED after)', async () => {
  await signInAs(ADMIN);
  const up = await call('adminUpsertPromoCode')({ code: 'e2e-welcome', credits: 2, maxRedemptions: 10, expiresAt: null, active: true, note: 'e2e', createOnly: true });
  assert.equal(up.ok, true);
  assert.equal(up.code, 'E2EWELCOME');
  assert.equal(up.created, true);
  const promo = (await getDoc(doc(cDb, 'promo_codes', 'E2EWELCOME'))).data();
  assert.deepEqual([promo.credits, promo.redemptions, promo.active, promo.max_redemptions], [2, 0, true, 10]);
  // §9.7: "create" never overwrites an existing code; the edit path (no createOnly) still updates.
  const exists = await expectReason(call('adminUpsertPromoCode')({ code: 'E2EWELCOME', credits: 5, active: true, createOnly: true }), 'VALIDATION_FAILED');
  assert.equal(exists.details?.why, 'exists');
  assert.equal((await getDoc(doc(cDb, 'promo_codes', 'E2EWELCOME'))).data().credits, 2, 'existing code untouched');
  const edit = await call('adminUpsertPromoCode')({ code: 'E2EWELCOME', credits: 2, maxRedemptions: 10, expiresAt: null, active: true, note: 'e2e edited' });
  assert.equal(edit.created, false);
  assert.equal((await getDoc(doc(cDb, 'promo_codes', 'E2EWELCOME'))).data().note, 'e2e edited');
  await expectReason(call('adminUpsertPromoCode')({ code: 'AB', credits: 1, active: true }), 'VALIDATION_FAILED');
  const logs = await getDocs(query(collection(cDb, 'admin_logs'), where('action', '==', 'create_promo_code')));
  assert.equal(logs.size, 1, 'admin action is logged');

  await signInAs(STUDENT);
  await expectReason(call('adminUpsertPromoCode')({ code: 'FREECREDITS', credits: 10, active: true }), 'FORBIDDEN_ROLE');
  await expectDenied(getDoc(doc(cDb, 'promo_codes', 'E2EWELCOME')));
  const before = (await getDoc(doc(cDb, 'entitlements', studentUid))).data().credits;
  const red = await call('promoRedeem')({ code: 'e2ewelcome' });
  assert.deepEqual(red, { credits: 2, balance: before + 2 });
  await expectReason(call('promoRedeem')({ code: 'E2EWELCOME' }), 'ALREADY_REDEEMED');
  await expectReason(call('promoRedeem')({ code: 'NOSUCHCODE' }), 'CODE_INVALID');
  const ledger = await getDocs(query(collection(cDb, 'entitlements', studentUid, 'ledger'), where('reason', '==', 'promo')));
  assert.equal(ledger.size, 1);
  assert.equal(ledger.docs[0].data().delta, 2);
  assert.equal((await db.doc('promo_codes/E2EWELCOME').get()).get('redemptions'), 1);
  const attempts = await db.collection('promo_attempts').where('uid', '==', studentUid).get();
  assert.equal(attempts.docs[0]?.get('count'), 3, 'every attempt is counted (10/day cap)');
});

test('referrals: get a code, apply it once; REFERRAL_NOT_ALLOWED after an exam or for your own code', async () => {
  friendUid = await signUp(FRIEND, 'E2E Friend', 'ru');
  const { code } = await call('referralGetCode')({});
  assert.match(code, /^[A-HJ-NP-Z2-9]{6}$/);
  friendCode = code;
  assert.equal((await call('referralGetCode')({})).code, code, 'idempotent');
  assert.equal((await getDoc(doc(cDb, 'users', friendUid))).data().referral_code, code);
  await expectDenied(getDoc(doc(cDb, 'referral_codes', code)));
  await expectReason(call('referralApply')({ code }), 'REFERRAL_NOT_ALLOWED');

  // The main student already completed an exam.
  await signInAs(STUDENT);
  await expectReason(call('referralApply')({ code }), 'REFERRAL_NOT_ALLOWED');
  await expectReason(call('referralApply')({ code: 'ZZZZZZ' }), 'CODE_INVALID');

  // A fresh account may apply it, exactly once (a retry is idempotent).
  newbieUid = await signUp(NEWBIE, 'E2E Newbie', 'ky');
  assert.deepEqual(await call('referralApply')({ code: code.toLowerCase() }), { ok: true });
  assert.deepEqual(await call('referralApply')({ code }), { ok: true });
  assert.equal((await getDoc(doc(cDb, 'users', newbieUid))).data().referred_by, friendUid);
  await expectDenied(setDoc(doc(cDb, 'users', newbieUid), { referred_by: null }, { merge: true }));

  await signInAs(FRIEND);
  const items = await getDocs(collection(cDb, 'referrals', friendUid, 'items'));
  assert.deepEqual(items.docs.map((d) => [d.id, d.data().status, d.data().display_name]), [[newbieUid, 'joined', 'E2E Newbie']]);
});

test('friendAdd: by the friend\'s referral code, idempotent, never yourself', async () => {
  await signInAs(STUDENT);
  const r = await call('friendAdd')({ code: friendCode });
  assert.equal(r.friendUid, friendUid);
  await call('friendAdd')({ code: friendCode });
  const list = await getDocs(collection(cDb, 'friends', studentUid, 'list'));
  assert.deepEqual(list.docs.map((d) => [d.id, d.data().display_name, d.data().uid]), [[friendUid, 'E2E Friend', friendUid]]);
  await expectDenied(setDoc(doc(cDb, 'friends', studentUid, 'list', newbieUid), { display_name: 'x', added_at: serverTimestamp() }));
  const own = (await call('referralGetCode')({})).code;
  await expectReason(call('friendAdd')({ code: own }), 'VALIDATION_FAILED');
  await expectReason(call('friendAdd')({ code: 'not a code' }), 'CODE_INVALID');
});

test('groups: create, join, owner assignment, member submission, leagues, leave', async () => {
  await signInAs(FRIEND);
  const g = await call('groupCreate')({ name: '  11 «А»   класс ' });
  groupId = g.groupId;
  assert.match(g.joinCode, /^[A-HJ-NP-Z2-9]{6}$/);
  const group = (await getDoc(doc(cDb, 'groups', groupId))).data();
  assert.deepEqual([group.name, group.owner_uid, group.member_count, group.join_code], ['11 «А» класс', friendUid, 1, g.joinCode]);
  // The owner publishes homework with the exact §9.3 map.
  const aRef = doc(collection(cDb, 'groups', groupId, 'assignments'));
  assignmentId = aRef.id;
  await setDoc(aRef, {
    title: 'Вариант 1: математика', kind: 'exam_variant', ref_id: 'e2e_main_ru_1',
    due_at: Timestamp.fromMillis(Date.now() + 7 * 864e5), created_by: friendUid, created_at: serverTimestamp(),
  });

  // Non-members see nothing.
  await signInAs(NEWBIE);
  await expectDenied(getDoc(doc(cDb, 'groups', groupId)));
  await expectDenied(getDoc(aRef));
  await expectReason(call('groupJoin')({ code: 'ZZZZZZ' }), 'CODE_INVALID');

  await signInAs(STUDENT);
  await setDoc(doc(cDb, 'users', studentUid), { region: { oblast: 'Чуйская область', district: 'Аламединский район', settlement: '' } }, { merge: true });
  const j = await call('groupJoin')({ code: g.joinCode.toLowerCase() });
  assert.equal(j.groupId, groupId);
  assert.equal((await call('groupJoin')({ code: g.joinCode })).groupId, groupId, 'idempotent');
  assert.equal((await getDoc(doc(cDb, 'groups', groupId))).data().member_count, 2);
  assert.deepEqual((await getDoc(doc(cDb, 'users', studentUid))).data().group_ids, [groupId]);
  const members = await getDocs(collection(cDb, 'groups', groupId, 'members'));
  assert.deepEqual(members.docs.map((d) => d.data().role).sort(), ['member', 'owner']);
  assert.equal((await getDoc(aRef)).data().kind, 'exam_variant');
  await expectDenied(setDoc(doc(collection(cDb, 'groups', groupId, 'assignments')), {
    title: 'x', kind: 'lesson', ref_id: 'l', due_at: null, created_by: studentUid, created_at: serverTimestamp(),
  }));
  await setDoc(doc(cDb, 'groups', groupId, 'assignments', aRef.id, 'submissions', studentUid), { done_at: serverTimestamp(), score_percent: 72.5 });
  await expectDenied(setDoc(doc(cDb, 'groups', groupId, 'assignments', aRef.id, 'submissions', friendUid), { done_at: serverTimestamp() }));
  await expectReason(call('groupRemoveMember')({ groupId, uid: friendUid }), 'NOT_GROUP_OWNER');

  // League fan-out + study time: lesson XP reaches the region and group weekly boards.
  const act = await call('recordActivity')({ kind: 'lesson_completed', refId: 'e2e_lesson_1', seconds: 300 });
  assert.ok(act.xpAwarded >= 20);
  assert.equal(act.stats.study_seconds_total, 300);
  const stats = (await getDoc(doc(cDb, 'user_stats', studentUid))).data();
  assert.deepEqual([stats.study_seconds_total, stats.study_seconds_today], [300, 300]);
  await expectReason(call('recordActivity')({ kind: 'lesson_completed', refId: 'e2e_lesson_1', seconds: 4000 }), 'VALIDATION_FAILED');
  // §9.7: a retried report (same reportId, e.g. after a lost response) adds its seconds once.
  const report = { kind: 'lesson_completed', refId: 'e2e_lesson_1', seconds: 120, reportId: 'e2e_report_0001' };
  assert.equal((await call('recordActivity')(report)).stats.study_seconds_total, 420);
  assert.equal((await call('recordActivity')(report)).stats.study_seconds_total, 420, 'a retry adds no time');
  assert.equal((await call('recordActivity')({ ...report, reportId: 'e2e_report_0002' })).stats.study_seconds_total, 540);
  await expectReason(call('recordActivity')({ ...report, reportId: 'bad id' }), 'VALIDATION_FAILED');
  assert.deepEqual((await getDoc(doc(cDb, 'user_stats', studentUid))).data().study_report_ids, ['e2e_report_0001', 'e2e_report_0002']);
  const boards = (await db.collectionGroup('entries').where('uid', '==', studentUid).get()).docs.map((d) => d.ref.parent.parent.id);
  assert.ok(boards.some((b) => b.startsWith('region_chuy_weekly_')), boards.join());
  assert.ok(boards.some((b) => b.startsWith(`group_${groupId}_weekly_`)), boards.join());

  // The owner reads every submission and cannot leave while members remain.
  await signInAs(FRIEND);
  const subs = await getDocs(collection(cDb, 'groups', groupId, 'assignments', aRef.id, 'submissions'));
  assert.deepEqual(subs.docs.map((d) => [d.id, d.data().score_percent]), [[studentUid, 72.5]]);
  await expectReason(call('groupLeave')({ groupId }), 'VALIDATION_FAILED');

  await signInAs(STUDENT);
  assert.deepEqual(await call('groupLeave')({ groupId }), { ok: true });
  assert.equal((await db.doc(`groups/${groupId}/assignments/${aRef.id}/submissions/${studentUid}`).get()).exists, false,
    'a member who leaves takes their homework marks along (§9.7)');
  await expectDenied(getDoc(doc(cDb, 'groups', groupId)));
  assert.deepEqual((await getDoc(doc(cDb, 'users', studentUid))).data().group_ids, []);
  assert.equal((await db.doc(`groups/${groupId}`).get()).get('member_count'), 1);
});

test('groupRemoveMember: a removed member cannot rejoin with the code; a member who left can (§9.7)', async () => {
  await signInAs(FRIEND);
  const joinCode = (await getDoc(doc(cDb, 'groups', groupId))).data().join_code;
  const intruderUid = await signUp(INTRUDER, 'E2E Intruder', 'ru');
  assert.equal((await call('groupJoin')({ code: joinCode })).groupId, groupId);

  await signInAs(FRIEND);
  assert.deepEqual(await call('groupRemoveMember')({ groupId, uid: intruderUid }), { ok: true });
  assert.equal((await db.doc(`groups/${groupId}`).get()).get('member_count'), 1);
  assert.equal((await db.doc(`groups/${groupId}/removed/${intruderUid}`).get()).get('by'), friendUid);
  await expectDenied(getDoc(doc(cDb, 'groups', groupId, 'removed', intruderUid)));

  await signInAs(INTRUDER);
  const e = await expectReason(call('groupJoin')({ code: joinCode }), 'VALIDATION_FAILED');
  assert.equal(e.details?.why, 'removed_from_group');
  assert.deepEqual((await getDoc(doc(cDb, 'users', intruderUid))).data().group_ids ?? [], []);
  assert.equal((await db.doc(`groups/${groupId}/members/${intruderUid}`).get()).exists, false);

  // The student left voluntarily and may come back (stays a member until accountDelete).
  await signInAs(STUDENT);
  assert.equal((await call('groupJoin')({ code: joinCode })).groupId, groupId);
  assert.equal((await db.doc(`groups/${groupId}`).get()).get('member_count'), 2);
  // Every groupJoin / friendAdd / referralApply call is counted, failed ones too
  // (4 friendAdd + 3 groupJoin + 2 rejected referralApply).
  assert.equal(await codeAttempts(studentUid), 9);
  // Back in the group: a fresh homework mark for the account-deletion test
  // (the earlier one left with the student, §9.7).
  await setDoc(doc(cDb, 'groups', groupId, 'assignments', assignmentId, 'submissions', studentUid), { done_at: serverTimestamp() });
  assert.equal(await codeAttempts(intruderUid), 2);
});

test('adminSendNotification: dry run counts recipients per audience (send_notifications only)', async () => {
  await signInAs(STUDENT);
  await setDoc(doc(cDb, 'users', studentUid), { fcm_tokens: ['e2e-token-student'] }, { merge: true });
  const msg = { title: { ru: 'Новый вариант', ky: 'Жаңы вариант' }, body: { ru: 'Попробуйте сегодня', ky: 'Бүгүн байкап көрүңүз' } };
  await expectReason(call('adminSendNotification')({ ...msg, audience: { kind: 'all' }, dryRun: true }), 'FORBIDDEN_ROLE');
  await signInAs(NEWBIE);
  await setDoc(doc(cDb, 'users', newbieUid), { fcm_tokens: ['e2e-token-newbie-1', 'e2e-token-newbie-2'] }, { merge: true });

  await signInAs(ADMIN);
  const send = (audience) => call('adminSendNotification')({ ...msg, audience, dryRun: true });
  const all = await send({ kind: 'all' });
  assert.deepEqual([all.recipients, all.tokens, all.sent, all.failed, all.notificationId, all.dryRun], [2, 3, 0, 0, null, true]);
  assert.equal((await send({ kind: 'language', value: 'ky' })).recipients, 1);
  assert.equal((await send({ kind: 'language', value: 'ru' })).recipients, 1);
  assert.equal((await send({ kind: 'region', value: 'chuy' })).recipients, 1);
  assert.equal((await send({ kind: 'region', value: 'naryn' })).recipients, 0);
  assert.equal((await send({ kind: 'group', value: groupId })).recipients, 1, 'the student (with a device) rejoined; the owner has none');
  await expectReason(send({ kind: 'planet', value: 'mars' }), 'VALIDATION_FAILED');
  await expectReason(call('adminSendNotification')({ title: { ru: '' }, body: msg.body, audience: { kind: 'all' }, dryRun: true }), 'VALIDATION_FAILED');
  assert.equal((await getDocs(collection(cDb, 'notifications'))).size, 0, 'dry runs leave no history');

  await signInAs(STUDENT);
});

test('practice XP is server-awarded and capped (recordActivity)', async () => {
  const before = (await getDoc(doc(cDb, 'user_stats', studentUid))).data().xp;
  const r = await call('recordActivity')({ kind: 'practice_answered', refId: 'quiz_e2e_1', correct: 5, count: 10 });
  assert.ok(r.xpAwarded >= 0);
  const afterXp = (await getDoc(doc(cDb, 'user_stats', studentUid))).data().xp;
  assert.equal(afterXp, before + r.xpAwarded);
  let total = 0;
  for (let i = 0; i < 40; i++) total += (await call('recordActivity')({ kind: 'practice_answered', refId: `quiz_e2e_cap_${i}`, correct: 10, count: 10 })).xpAwarded;
  assert.ok(total + r.xpAwarded <= 200, `daily practice XP cap respected (got ${total + r.xpAwarded})`);
});

test('account deletion removes the account and its data (Google Play requirement)', async () => {
  // The student is a member of FRIEND's group with a homework submission (§9.7 cleanup).
  const submissionPath = `groups/${groupId}/assignments/${assignmentId}/submissions/${studentUid}`;
  assert.equal((await db.doc(submissionPath).get()).exists, true, 'submission seeded by the groups test');
  assert.equal((await db.doc(`groups/${groupId}`).get()).get('member_count'), 2);
  // Fresh sign-in satisfies the recent-login requirement (D9).
  await signOut(cAuth);
  await signInWithEmailAndPassword(cAuth, STUDENT.email, STUDENT.password);
  const r = await call('accountDelete')({});
  assert.equal(r.ok, true);
  await assert.rejects(auth.getUser(studentUid), /no user record|user-not-found/i);
  for (const p of [`users/${studentUid}`, `user_stats/${studentUid}`, `entitlements/${studentUid}`]) {
    assert.equal((await db.doc(p).get()).exists, false, `${p} deleted`);
  }
  const attempts = await db.collection('exam_attempts').where('uid', '==', studentUid).get();
  assert.equal(attempts.size, 0, 'attempts deleted');
  // Phase 3 data: friends, own referral code, promo attempt counters.
  assert.equal((await db.collection(`friends/${studentUid}/list`).get()).size, 0, 'friend list deleted');
  assert.equal((await db.collection('referral_codes').where('uid', '==', studentUid).get()).size, 0, 'referral code released');
  assert.equal((await db.collection('promo_attempts').where('uid', '==', studentUid).get()).size, 0, 'promo attempts deleted');
  assert.equal((await db.collection('code_attempts').where('uid', '==', studentUid).get()).size, 0, 'code attempts deleted');
  // Membership in someone else's group: submission and member doc gone, member_count decremented once.
  assert.equal((await db.doc(submissionPath).get()).exists, false, 'own submission deleted');
  assert.equal((await db.doc(`groups/${groupId}/members/${studentUid}`).get()).exists, false, 'membership deleted');
  assert.equal((await db.doc(`groups/${groupId}`).get()).get('member_count'), 1);
  // The still-valid ID token can no longer claim anything.
  await assert.rejects(call('examStart')({ variantId: 'e2e_main_ru_1' }));
});

test('deleting a group owner deletes the group, its join code, referral data and the invitee item', async () => {
  // NEWBIE joins FRIEND's group first, so the cleanup of other members is exercised.
  await signInAs(FRIEND);
  const joinCode = (await getDoc(doc(cDb, 'groups', groupId))).data().join_code;
  await signInAs(NEWBIE);
  await call('groupJoin')({ code: joinCode });
  assert.deepEqual((await getDoc(doc(cDb, 'users', newbieUid))).data().group_ids, [groupId]);
  // NEWBIE keeps FRIEND in their friend list (entry carries uid, §9.7).
  await call('friendAdd')({ code: friendCode });
  assert.equal((await getDoc(doc(cDb, 'friends', newbieUid, 'list', friendUid))).data().uid, friendUid);

  await signInAs(FRIEND);
  assert.equal((await call('accountDelete')({})).ok, true);
  assert.equal((await db.doc(`friends/${newbieUid}/list/${friendUid}`).get()).exists, false, "others' friend entries about the user deleted");
  assert.equal((await db.doc(`groups/${groupId}`).get()).exists, false, 'owned group deleted');
  assert.equal((await db.collection(`groups/${groupId}/assignments`).get()).size, 0, 'assignments deleted');
  assert.equal((await db.doc(`group_join_codes/${joinCode}`).get()).exists, false, 'join code released');
  assert.equal((await db.doc(`referral_codes/${friendCode}`).get()).exists, false, 'referral code released');
  assert.equal((await db.collection(`referrals/${friendUid}/items`).get()).size, 0, 'referral items deleted');
  assert.deepEqual((await db.doc(`users/${newbieUid}`).get()).get('group_ids'), [], 'other members cleaned');
});
