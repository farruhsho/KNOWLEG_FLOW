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
import { getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, collection, query, where, getDocs, serverTimestamp, terminate } from 'firebase/firestore';
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
    sec.question_ids.forEach((qid, k) => {
      if (k % 5 === 4) { expectedSkipped++; return; } // leave every 5th unanswered
      const isQc = sec.section_id === 'math' && k < 30;
      const right = k % 2 === 0;
      answers[qid] = right ? (isQc ? 'B' : 'A') : 'C';
      if (right) expectedCorrect++;
    });
    last = await call('examSubmitSection')({ attemptId, sectionId: sec.section_id, answers, flags: [], clientElapsedSec: 60 });
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
  // The still-valid ID token can no longer claim anything.
  await assert.rejects(call('examStart')({ variantId: 'e2e_main_ru_1' }));
});
