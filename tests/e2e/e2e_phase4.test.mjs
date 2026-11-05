// End-to-end test of phase 4 (ARCHITECTURE §10) on the Firebase emulators:
//  - examStart mode 'fresh': a new variant assembled from the verified bank per
//    attempt (free first / 1 credit), resume, freshness + honest repeats, review;
//  - POOL_TOO_SMALL charges nothing; config/exam_pool admin switch and health;
//  - strict ORT style: SECTION_NOT_OVER before the deadline, flags ignored;
//  - web payments with the emulator-only `sandbox` provider: order -> checkout
//    page -> signed webhook -> credits, idempotent replay, wrong amount, cancel,
//    refunds (admin + provider) with clawback, a refund in progress refused,
//    a paid-but-never-granted order refunded without clawback, referral
//    reward via the shared Google Play logic, ORDER_NOT_FOUND, 10 orders/day,
//    account deletion; adminUpdatePricing (webProducts only) logged.
// PAYMENTS_DISABLED cannot happen here (the emulator runs the sandbox): it is
// covered by functions/test/payments.test.ts.
//
// Run with e2e.test.mjs: cd tests/e2e && npm test (needs Java 21 for the emulators).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, createHmac } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import { initializeApp as initAdmin } from 'firebase-admin/app';
import { getFirestore as adminDb, Timestamp as AdminTimestamp } from 'firebase-admin/firestore';
import { getAuth as adminAuth } from 'firebase-admin/auth';

import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, collection, query, where, getDocs, serverTimestamp, terminate } from 'firebase/firestore';
import { getFunctions, connectFunctionsEmulator, httpsCallable } from 'firebase/functions';

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-ort-e2e';
const REGION = 'europe-west1';
const FN_BASE = `http://127.0.0.1:5001/${PROJECT}/${REGION}`;
/** Fixed signing key of the sandbox provider (functions/src/payments/sandbox.ts) — emulator only. */
const SANDBOX_SECRET = 'ort-sandbox-emulator-only-secret';
/** Allowed by PAYMENT_RETURN_ORIGINS in functions/.env.demo-ort-e2e. */
const RETURN_URL = 'http://localhost:8088/pay/return';
const CHEM = 'ort_subject_chemistry_2026';
const BIO = 'ort_subject_biology_2026';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '../..');
const blueprints = JSON.parse(readFileSync(path.join(root, 'assets/data/exam_blueprints.json'), 'utf8')).blueprints;
const matrixPart = (bpId, lang) => {
  const m = JSON.parse(readFileSync(path.join(root, `content/matrix/${bpId}.json`), 'utf8'));
  return m.languages.find((l) => l.language === lang).sections[0].parts[0];
};

const admin = initAdmin({ projectId: PROJECT }, 'admin-phase4');
const db = adminDb(admin);
const auth = adminAuth(admin);

// ---------------------------------------------------------------- seeding

/**
 * A chemistry (ru) pool of 1.5 variants: every topic × difficulty cell of the
 * matrix with n questions per variant holds n + ceil(n/2). One fresh variant
 * uses n of each cell; the next one can take only ceil(n/2) unseen ones, so it
 * repeats exactly Σ floor(n/2) questions.
 */
async function seedChemPool() {
  const part = matrixPart(CHEM, 'ru');
  const cells = [];
  const batch = db.batch();
  for (const t of part.topics) {
    for (const d of [1, 2, 3]) {
      const n = t.difficulty_targets[String(d)];
      if (!n) continue;
      const size = n + Math.ceil(n / 2);
      const ids = [];
      for (let k = 0; k < size; k++) {
        const id = `p4_chem_${t.topic_id.replace(/\W/g, '_')}_${d}_${k}`;
        ids.push(id);
        batch.set(db.doc(`exam_questions/${id}`), {
          subject_id: 'chemistry', section_id: 'chemistry', part_id: 'chemistry', blueprint_id: CHEM,
          topic_id: t.topic_id, difficulty: d, language: 'ru', type: 'single_choice',
          stem: `P4 химия ${id}: выберите верный ответ.`,
          options: ['A', 'B', 'C', 'D'].map((o, i) => ({ id: o, text: `вариант ${i + 1}` })),
          passage_id: null, image_path: null, table: null,
          review: { status: 'methodologist_approved' }, content_version: 1,
          source: { kind: 'original', basis: 'e2e phase 4 fixture' },
        });
        batch.set(db.doc(`exam_question_keys/${id}`), { correct: 'A', explanation: 'E2E', wrong_option_notes: {}, solution_steps: [] });
      }
      cells.push({ topic: t.topic_id, difficulty: d, n, ids });
    }
  }
  await batch.commit();
  return cells;
}

/** Five biology questions: far too few for a 40-question variant (POOL_TOO_SMALL). */
async function seedBioScraps() {
  const t = matrixPart(BIO, 'ru').topics[0];
  const batch = db.batch();
  for (let k = 0; k < 5; k++) {
    const id = `p4_bio_${k}`;
    batch.set(db.doc(`exam_questions/${id}`), {
      subject_id: 'biology', section_id: 'biology', part_id: 'biology', topic_id: t.topic_id, difficulty: 1 + (k % 3), language: 'ru',
      type: 'single_choice', stem: `P4 биология ${k}`, options: [{ id: 'A', text: '1' }, { id: 'B', text: '2' }],
      passage_id: null, review: { status: 'methodologist_approved' },
    });
    batch.set(db.doc(`exam_question_keys/${id}`), { correct: 'A' });
  }
  await batch.commit();
}

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

const ADMIN = { email: 'admin.p4@example.test', password: 'e2e-P4-Adm1n-Passw0rd!' };
const BUYER = { email: 'buyer.p4@example.test', password: 'e2e-P4-Buyer-Passw0rd!' };
const STRICT = { email: 'strict.p4@example.test', password: 'e2e-P4-Str1ct-Passw0rd!' };
const REFERRER = { email: 'referrer.p4@example.test', password: 'e2e-P4-Ref-Passw0rd!' };
const REFEREE = { email: 'referee.p4@example.test', password: 'e2e-P4-Ree-Passw0rd!' };

async function signInAs(user) {
  await signOut(cAuth);
  await signInWithEmailAndPassword(cAuth, user.email, user.password);
  await cAuth.currentUser.getIdToken(true);
  return cAuth.currentUser.uid;
}

async function signUp(user, name) {
  await signOut(cAuth);
  const cred = await createUserWithEmailAndPassword(cAuth, user.email, user.password);
  await setDoc(doc(cDb, 'users', cred.user.uid), {
    name, email: user.email, grade: 11, preferred_language: 'ru', role: 'student',
    subscription: { tier: 'free', expires_at: null }, created_at: serverTimestamp(),
  });
  return cred.user.uid;
}

const entitlement = async (uid) => (await db.doc(`entitlements/${uid}`).get()).data() ?? {};
const credits = async (uid) => (await entitlement(uid)).credits ?? 0;

/** A sandbox webhook signed exactly like the provider adapter expects (raw-body HMAC). */
function signedEvent(e) {
  const body = JSON.stringify({ event_id: e.eventId, order_id: e.orderId, status: e.status, amount_som: e.amountSom, currency: e.currency ?? 'KGS' });
  return { body, signature: 'sha256=' + createHmac('sha256', SANDBOX_SECRET).update(body).digest('hex') };
}
async function postWebhook(e, signature) {
  const s = signedEvent(e);
  const res = await fetch(`${FN_BASE}/paymentWebhook`, {
    method: 'POST', headers: { 'content-type': 'application/json', 'x-sandbox-signature': signature ?? s.signature }, body: s.body,
  });
  return { status: res.status, body: await res.json().catch(() => null) };
}
/** Presses a button on the sandbox checkout page (form POST, redirect not followed). */
async function pressCheckout(orderId, action) {
  return fetch(`${FN_BASE}/paymentSandboxCheckout`, {
    method: 'POST', redirect: 'manual', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ order: orderId, return: RETURN_URL, action }).toString(),
  });
}
const createOrder = (productId = 'exam_single') => call('paymentCreateOrder')({ productId, returnUrl: RETURN_URL });

let chemCells;
let buyerUid;
let firstAttempt;
let firstQuestionIds;
const orders = {};

before(async () => {
  for (const bp of blueprints) await db.doc(`exam_blueprints/${bp.id}`).set(bp);
  await db.doc('config/pricing').set({
    free_exams_per_user: 1,
    products: { exam_single: { credits: 1 }, exam_pack_5: { credits: 5 }, exam_pack_10: { credits: 10 } },
    web_products: {
      exam_single: { credits: 1, amount_som: 100, enabled: true },
      exam_pack_5: { credits: 5, amount_som: 450, enabled: false },
      exam_pack_10: { credits: 10, amount_som: 800, enabled: false },
    },
  });
  await db.doc('config/exam_pool').set({ fresh_enabled: true, min_review_status: 'methodologist_approved' });
  chemCells = await seedChemPool();
  await seedBioScraps();

  const adminUser = await auth.createUser({ email: ADMIN.email, password: ADMIN.password, emailVerified: true });
  await auth.setCustomUserClaims(adminUser.uid, { role: 'super_admin' });

  app = initializeApp({ apiKey: 'demo-key', projectId: PROJECT, appId: '1:1:web:e2e4' }, 'client-phase4');
  cAuth = getAuth(app);
  connectAuthEmulator(cAuth, 'http://127.0.0.1:9099', { disableWarnings: true });
  cDb = getFirestore(app);
  connectFirestoreEmulator(cDb, '127.0.0.1', 8080);
  fns = getFunctions(app, REGION);
  connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  buyerUid = await signUp(BUYER, 'P4 Buyer');
});

after(async () => {
  if (app) {
    await terminate(cDb).catch(() => {});
    await deleteApp(app).catch(() => {});
  }
});

const freshStart = (extra = {}) => call('examStart')({ mode: 'fresh', blueprintId: CHEM, language: 'ru', clientAppVersion: 'e2e-p4', ...extra });

// ---------------------------------------------------------------- fresh variants

test('fresh: the first full mock is a NEW variant assembled from the bank (free), resume returns it', async () => {
  const p = await freshStart();
  firstAttempt = p.attemptId;
  assert.equal(p.entitlementSource, 'free_first');
  assert.equal(p.source, 'fresh');
  assert.equal(p.examStyle, 'standard');
  assert.deepEqual(p.freshness, { total: 40, repeated: 0 });
  assert.equal(p.variantId, `fresh_${p.attemptId}`);
  assert.equal(p.section.questions.length, 40);
  assert.ok(!/"correct"|explanation/.test(JSON.stringify(p)), 'payload must not leak keys');
  firstQuestionIds = p.section.questions.map((q) => q.id);

  // Stored variant: generated for this attempt, same questions in the same order.
  const v = (await db.doc(`exam_variants/${p.variantId}`).get()).data();
  assert.deepEqual([v.status, v.source, v.generated_for, v.attempt_id, v.blueprint_id, v.language], ['generated', 'fresh', buyerUid, p.attemptId, CHEM, 'ru']);
  assert.match(v.seed, /^[0-9a-f]{24}$/);
  assert.deepEqual(v.sections[0].question_ids, firstQuestionIds);
  assert.equal(v.assembly.matrix_fit['chemistry/chemistry'], 'exact_cells');
  const att = (await db.doc(`exam_attempts/${p.attemptId}`).get()).data();
  assert.deepEqual([att.source, att.exam_style, att.variant_id, att.freshness.total], ['fresh', 'standard', p.variantId, 40]);

  // Exactly the matrix: every topic × difficulty cell, easy -> hard.
  const qs = await Promise.all(firstQuestionIds.map((id) => db.doc(`exam_questions/${id}`).get()));
  const difficulties = qs.map((s) => s.get('difficulty'));
  assert.deepEqual(difficulties, [...difficulties].sort((a, b) => a - b), 'easy -> hard');
  for (const c of chemCells) {
    assert.equal(qs.filter((s) => s.get('topic_id') === c.topic && s.get('difficulty') === c.difficulty).length, c.n, `${c.topic}/${c.difficulty}`);
  }

  // Students never read generated variants (not even their own).
  await expectDenied(getDoc(doc(cDb, 'exam_variants', p.variantId)));

  // Resume: same attempt, nothing charged, no second variant.
  const again = await freshStart();
  assert.equal(again.attemptId, p.attemptId);
  assert.equal(again.entitlementSource, 'resume');
  assert.deepEqual(again.freshness, { total: 40, repeated: 0 });
  assert.equal((await entitlement(buyerUid)).free_exams_used_count, 1);
  assert.equal((await db.collection('exam_variants').where('generated_for', '==', buyerUid).get()).size, 1);
});

test('fresh: the generated variant completes, scores and reviews like a library one', async () => {
  const answers = Object.fromEntries(firstQuestionIds.map((id, k) => [id, k < 10 ? 'A' : 'B']));
  const r = await call('examSubmitSection')({ attemptId: firstAttempt, sectionId: 'chemistry', answers, flags: [firstQuestionIds[0]], clientElapsedSec: 60 });
  assert.equal(r.completed, true);
  assert.deepEqual([r.result.total, r.result.correct, r.result.incorrect], [40, 10, 30]);
  const state = await call('examGetState')({ attemptId: firstAttempt });
  assert.deepEqual([state.status, state.source, state.examStyle], ['completed', 'fresh', 'standard']);
  const review = await call('examGetReview')({ attemptId: firstAttempt });
  assert.equal(review.items.length, 40);
  assert.ok(review.items.every((i) => i.correct === 'A'));
  // Standard style keeps the flags.
  assert.deepEqual((await db.doc(`exam_attempts/${firstAttempt}/answers/chemistry`).get()).get('flags'), [firstQuestionIds[0]]);
});

test('fresh: without free exams or credits a new fresh attempt is NO_ENTITLEMENT', async () => {
  await expectReason(freshStart(), 'NO_ENTITLEMENT');
  // Checked before the pool is loaded: the 5-question biology pool would be POOL_TOO_SMALL.
  await expectReason(call('examStart')({ mode: 'fresh', blueprintId: BIO, language: 'ru' }), 'NO_ENTITLEMENT');
});

// ---------------------------------------------------------------- web payments (sandbox)

test('web payment (sandbox): order -> checkout page -> paid -> +1 credit, ledger web_{orderId}', async () => {
  await expectReason(call('paymentCreateOrder')({ productId: 'exam_single', returnUrl: 'https://evil.example/pay' }), 'VALIDATION_FAILED');
  await expectReason(createOrder('exam_pack_5'), 'PRODUCT_UNAVAILABLE');
  await expectReason(createOrder('no_such_product'), 'PRODUCT_UNAVAILABLE');

  const o = await createOrder();
  orders.first = o.orderId;
  assert.deepEqual([o.amountSom, o.credits, o.currency, o.productId], [100, 1, 'KGS', 'exam_single']);
  assert.ok(Math.abs(o.expiresAt - (Date.now() + 24 * 3600e3)) < 120e3, 'expires in 24 h');
  const checkout = new URL(o.checkoutUrl);
  assert.match(checkout.pathname, /\/paymentSandboxCheckout$/);
  assert.equal(checkout.searchParams.get('order'), o.orderId);
  assert.equal(new URL(checkout.searchParams.get('return')).searchParams.get('order'), o.orderId);

  // The owner reads the order (rules), it waits for payment.
  const own = (await getDoc(doc(cDb, 'payment_orders', o.orderId))).data();
  assert.deepEqual([own.uid, own.status, own.provider, own.amount_som, own.granted], [buyerUid, 'pending', 'sandbox', 100, false]);
  await expectDenied(setDoc(doc(cDb, 'payment_orders', o.orderId), { status: 'paid' }, { merge: true }));

  // The sandbox checkout page (fetched on the local functions URL).
  const pageRes = await fetch(`${FN_BASE}/paymentSandboxCheckout${checkout.search}`);
  assert.equal(pageRes.status, 200);
  const html = await pageRes.text();
  for (const s of ['Тестовая оплата — только эмулятор', 'Оплатить (тест)', 'Отменить', '100 сом']) assert.ok(html.includes(s), `page shows ${s}`);

  // "Оплатить (тест)" -> signed webhook -> redirect back to the app.
  const pay = await pressCheckout(o.orderId, 'pay');
  assert.equal(pay.status, 303);
  assert.equal(pay.headers.get('location'), `${RETURN_URL}?order=${o.orderId}`);

  const st = await call('paymentGetOrder')({ orderId: o.orderId });
  assert.deepEqual([st.status, st.credits, st.balance, st.granted], ['paid', 1, 1, true]);
  const ent = await entitlement(buyerUid);
  assert.deepEqual([ent.credits, ent.lifetime_credits_purchased], [1, 1]);
  const ledger = await db.collection(`entitlements/${buyerUid}/ledger`).where('reason', '==', 'purchase').get();
  assert.deepEqual(ledger.docs.map((d) => [d.get('ref'), d.get('delta'), d.get('product_id')]), [[`web_${o.orderId}`, 1, 'exam_single']]);
  const events = await db.collection('payment_events').where('order_id', '==', o.orderId).get();
  assert.equal(events.size, 1);
  assert.equal(events.docs[0].get('result'), 'granted');
  assert.equal(events.docs[0].get('uid'), undefined, 'payment_events keep no uid');
  await expectDenied(getDoc(doc(cDb, 'payment_events', events.docs[0].id)));

  // The page of a paid order offers no second payment.
  assert.ok(!(await (await fetch(`${FN_BASE}/paymentSandboxCheckout${checkout.search}`)).text()).includes('Оплатить (тест)'));
});

test('web payment: a replayed webhook grants once; a bad signature is rejected', async () => {
  const o = await createOrder();
  orders.second = o.orderId;
  const event = { eventId: 'e2e_p4_evt_fixed_1', orderId: o.orderId, status: 'paid', amountSom: 100 };
  assert.equal((await postWebhook(event, 'sha256=' + '0'.repeat(64))).status, 401);
  const first = await postWebhook(event);
  assert.deepEqual([first.status, first.body?.result], [200, 'granted']);
  const replay = await postWebhook(event);
  assert.deepEqual([replay.status, replay.body?.result], [200, 'duplicate']);
  // A different event id for the same paid order changes nothing either.
  assert.equal((await postWebhook({ ...event, eventId: 'e2e_p4_evt_fixed_2' })).body?.result, 'noop_already_granted');
  assert.equal(await credits(buyerUid), 2);
  assert.equal((await db.collection(`entitlements/${buyerUid}/ledger`).where('reason', '==', 'purchase').get()).size, 2);
});

test('web payment: a wrong amount fails the order without credits (admin_logs); cancel fails it too', async () => {
  const o = await createOrder();
  orders.wrongAmount = o.orderId;
  const r = await postWebhook({ eventId: 'e2e_p4_evt_amount', orderId: o.orderId, status: 'paid', amountSom: 50 });
  assert.equal(r.body?.result, 'amount_mismatch');
  const st = await call('paymentGetOrder')({ orderId: o.orderId });
  assert.deepEqual([st.status, st.balance], ['failed', 2]);
  const failure = (await db.doc(`payment_orders/${o.orderId}`).get()).get('failure');
  assert.deepEqual([failure.code, failure.got.amount_som, failure.expected.amount_som], ['amount_mismatch', 50, 100]);
  const logs = await db.collection('admin_logs').where('action', '==', 'payment_amount_mismatch').get();
  assert.ok(logs.docs.some((d) => d.get('target').orderId === o.orderId), 'logged for the admins');

  const c = await createOrder();
  const cancel = await pressCheckout(c.orderId, 'cancel');
  assert.equal(cancel.status, 303);
  assert.equal((await call('paymentGetOrder')({ orderId: c.orderId })).status, 'failed');
  assert.equal(await credits(buyerUid), 2);
});

test('web payment: at most 10 orders a day per user (RATE_LIMITED)', async () => {
  // 4 orders so far today (the rejected product / return-URL calls never counted).
  for (let i = 0; i < 6; i++) await createOrder();
  await expectReason(createOrder(), 'RATE_LIMITED');
});

// ---------------------------------------------------------------- pool admin + POOL_TOO_SMALL

test('POOL_TOO_SMALL charges nothing and names the part', async () => {
  const before = await entitlement(buyerUid);
  const attemptsBefore = (await db.collection('exam_attempts').where('uid', '==', buyerUid).get()).size;
  const e = await expectReason(call('examStart')({ mode: 'fresh', blueprintId: BIO, language: 'ru' }), 'POOL_TOO_SMALL');
  assert.deepEqual([e.details.section_id, e.details.part_id], ['biology', 'biology']);
  const afterEnt = await entitlement(buyerUid);
  assert.deepEqual([afterEnt.credits, afterEnt.free_exams_used_count], [before.credits, before.free_exams_used_count]);
  assert.equal((await db.collection('exam_attempts').where('uid', '==', buyerUid).get()).size, attemptsBefore);
  assert.equal((await db.collection('exam_variants').where('generated_for', '==', buyerUid).get()).size, 1);
  // Validation of the new inputs.
  await expectReason(call('examStart')({ mode: 'fresh', blueprintId: CHEM, language: 'de' }), 'VALIDATION_FAILED');
  await expectReason(call('examStart')({ mode: 'fresh', blueprintId: 'ort_state_language_2026', language: 'ru' }), 'VALIDATION_FAILED');
  await expectReason(call('examStart')({ mode: 'fresh', blueprintId: CHEM, language: 'ru', examStyle: 'turbo' }), 'VALIDATION_FAILED');
  // An unknown blueprint is VARIANT_NOT_AVAILABLE {why}; the English subject test takes `en` (no en pool here).
  const unknown = await expectReason(call('examStart')({ mode: 'fresh', blueprintId: 'ort_no_such_2026', language: 'ru' }), 'VARIANT_NOT_AVAILABLE');
  assert.equal(unknown.details.why, 'blueprint_not_found');
  const en = await expectReason(call('examStart')({ mode: 'fresh', blueprintId: 'ort_subject_english_2026', language: 'en' }), 'POOL_TOO_SMALL');
  assert.equal(en.details.section_id, 'english');
  assert.equal((await entitlement(buyerUid)).credits, before.credits, 'still nothing charged');
});

test('config/exam_pool: super_admin switches fresh variants; pool health for content roles', async () => {
  await expectReason(call('adminUpdateExamPool')({ freshEnabled: false }), 'FORBIDDEN_ROLE');
  await expectReason(call('adminExamPoolHealth')({ blueprintId: CHEM, language: 'ru' }), 'FORBIDDEN_ROLE');
  assert.equal((await getDoc(doc(cDb, 'config', 'exam_pool'))).data().fresh_enabled, true, 'signed-in users read the switch');

  await signInAs(ADMIN);
  assert.deepEqual(await call('adminUpdateExamPool')({ freshEnabled: false }), { ok: true, freshEnabled: false, minReviewStatus: 'methodologist_approved' });
  await expectReason(call('adminUpdateExamPool')({ minReviewStatus: 'draft' }), 'VALIDATION_FAILED');
  const health = await call('adminExamPoolHealth')({ blueprintId: CHEM, language: 'ru' });
  const part = health.sections[0].parts[0];
  assert.equal(part.needed, 40);
  assert.equal(part.eligible, chemCells.reduce((a, c) => a + c.ids.length, 0));
  assert.equal(part.available_by_status.methodologist_approved >= part.eligible, true);
  assert.equal(health.disjoint_variants, 1, '1.5 variants worth of questions = 1 disjoint variant');
  assert.ok(health.shortfalls.length > 0 && health.shortfalls.every((s) => s.kind === 'cell'), 'what is missing for variant 2');
  const bio = await call('adminExamPoolHealth')({ blueprintId: BIO, language: 'ru' });
  assert.equal(bio.disjoint_variants, 0);
  // The biology scraps have 2 options where the part needs 4: they fail the per-question checks.
  assert.equal(bio.sections[0].parts[0].available_by_status.methodologist_approved, 0);
  const logs = await db.collection('admin_logs').where('action', '==', 'update_exam_pool').get();
  assert.equal(logs.size, 1);

  // adminUpdatePricing with only webProducts (the web pricing page) is logged too (no undefined in the details).
  const web = {
    exam_single: { credits: 1, amountSom: 100, enabled: true },
    exam_pack_5: { credits: 5, amountSom: 450, enabled: false },
    exam_pack_10: { credits: 10, amountSom: 800, enabled: false },
  };
  assert.deepEqual(await call('adminUpdatePricing')({ webProducts: web }), { ok: true });
  const pricingLogs = (await db.collection('admin_logs').where('action', '==', 'update_pricing').get()).docs.map((d) => d.get('details'));
  const webOnly = pricingLogs.find((d) => d?.after?.products === null);
  assert.ok(webOnly, 'an update_pricing admin_logs entry for the webProducts-only call');
  assert.deepEqual([webOnly.after.free_exams_per_user, webOnly.base_price_changed], [null, false]);
  assert.deepEqual(webOnly.after.web_products.exam_single, { credits: 1, amount_som: 100, enabled: true });
  const pricing = (await db.doc('config/pricing').get()).data();
  assert.equal(pricing.free_exams_per_user, 1, 'fields not sent are untouched');
  assert.deepEqual(pricing.web_products.exam_single, { credits: 1, amount_som: 100, enabled: true });

  await signInAs(BUYER);
  const off = await expectReason(freshStart(), 'VARIANT_NOT_AVAILABLE');
  assert.equal(off.details.why, 'fresh_disabled');
  await signInAs(ADMIN);
  await call('adminUpdateExamPool')({ freshEnabled: true });
  await signInAs(BUYER);
});

test('fresh: the second attempt prefers unseen questions and reports the repeats honestly (1 credit)', async () => {
  const p = await freshStart();
  assert.equal(p.entitlementSource, 'credit');
  const expectedRepeats = chemCells.reduce((a, c) => a + Math.floor(c.n / 2), 0);
  assert.deepEqual(p.freshness, { total: 40, repeated: expectedRepeats });
  const ids = new Set(p.section.questions.map((q) => q.id));
  const seen = new Set(firstQuestionIds);
  const unseenPool = chemCells.flatMap((c) => c.ids).filter((id) => !seen.has(id));
  for (const id of unseenPool) assert.ok(ids.has(id), `unseen ${id} used first`);
  assert.equal([...ids].filter((id) => seen.has(id)).length, expectedRepeats);
  assert.equal(await credits(buyerUid), 1);
  const ledger = await db.collection(`entitlements/${buyerUid}/ledger`).where('reason', '==', 'exam_start').get();
  assert.deepEqual(ledger.docs.map((d) => d.get('ref')), [p.attemptId]);
  await call('examSubmitSection')({ attemptId: p.attemptId, sectionId: 'chemistry', answers: {}, flags: [] });
});

// ---------------------------------------------------------------- refunds

test('refunds: adminRefundOrder and a provider `refunded` webhook claw back (debt when spent)', async () => {
  await expectReason(call('adminRefundOrder')({ orderId: orders.first, reason: 'e2e' }), 'FORBIDDEN_ROLE');
  await signInAs(ADMIN);
  const r = await call('adminRefundOrder')({ orderId: orders.first, reason: 'e2e refund' });
  assert.deepEqual(r, { status: 'refunded', creditsClawedBack: 1 });
  await expectReason(call('adminRefundOrder')({ orderId: orders.first, reason: 'again' }), 'VALIDATION_FAILED');
  await expectReason(call('adminRefundOrder')({ orderId: orders.wrongAmount, reason: 'never paid' }), 'VALIDATION_FAILED');
  await expectReason(call('adminRefundOrder')({ orderId: 'no_such_order', reason: 'missing' }), 'ORDER_NOT_FOUND');
  assert.ok((await db.collection('admin_logs').where('action', '==', 'refund_order').get()).size >= 1);

  // A refund already asked of the provider (reserved, waiting for its webhook): a second request is refused.
  await db.doc(`payment_orders/${orders.second}`).set({ refund_requested: { id: 'e2e_pending', by: 'e2e', reason: 'pending at the provider' } }, { merge: true });
  const busy = await expectReason(call('adminRefundOrder')({ orderId: orders.second, reason: 'twice' }), 'VALIDATION_FAILED');
  assert.equal(busy.details.why, 'refund_in_progress');

  // Paid after the account was deleted (never granted): the provider refund only, nothing to claw back.
  const ungranted = 'e2e_p4_paid_ungranted';
  await db.doc(`payment_orders/${ungranted}`).set({
    uid: 'deleted:e2e', product_id: 'exam_single', credits: 1, amount_som: 100, currency: 'KGS', provider: 'sandbox',
    status: 'paid', granted: false, provider_ref: `sbx_${ungranted}`, failure: { code: 'account_deleted' }, refund: null,
    created_at: AdminTimestamp.now(),
  });
  assert.deepEqual(await call('adminRefundOrder')({ orderId: ungranted, reason: 'paid after deletion' }), { status: 'refunded', creditsClawedBack: 0 });
  const closed = (await db.doc(`payment_orders/${ungranted}`).get()).data();
  assert.deepEqual([closed.status, closed.refund.source, closed.refund.credits_clawed_back], ['refunded', 'admin', 0]);
  assert.deepEqual(Object.keys(closed.refund_requested).sort(), ['at', 'id'], 'the owner-readable order keeps no admin uid or reason');
  assert.equal((await expectReason(call('adminRefundOrder')({ orderId: ungranted, reason: 'again' }), 'VALIDATION_FAILED')).details.why, 'not_refundable');
  const ungrantedLog = (await db.collection('admin_logs').where('action', '==', 'refund_order').get()).docs.find((d) => d.get('target').orderId === ungranted);
  assert.equal(ungrantedLog?.get('details').kind, 'provider_only');
  assert.equal(ungrantedLog?.get('details').reason, 'paid after deletion');

  await signInAs(BUYER);
  assert.equal(await credits(buyerUid), 0);
  const refunded = (await db.doc(`payment_orders/${orders.first}`).get()).data();
  assert.deepEqual([refunded.status, refunded.refund.source, refunded.refund.credits_clawed_back], ['refunded', 'admin', 1]);
  assert.equal(typeof refunded.refund_requested?.id, 'string', 'the refund was reserved before the provider was called');

  // The provider refunds the second order (the admin request above was pending there): the credit is already spent -> debt.
  const w = await postWebhook({ eventId: 'e2e_p4_evt_refund_2', orderId: orders.second, status: 'refunded', amountSom: 100 });
  assert.equal(w.body?.result, 'refunded');
  const ent = await entitlement(buyerUid);
  assert.deepEqual([ent.credits, ent.debt_credits], [0, 1]);
  const refunds = await db.collection(`entitlements/${buyerUid}/ledger`).where('reason', '==', 'refund').get();
  assert.deepEqual(refunds.docs.map((d) => d.get('ref')).sort(), [`web_${orders.first}`, `web_${orders.second}`].sort());
  assert.equal((await postWebhook({ eventId: 'e2e_p4_evt_refund_3', orderId: orders.second, status: 'refunded', amountSom: 100 })).body?.result, 'noop_refunded');
});

test('paymentGetOrder: another user\'s or an unknown order is ORDER_NOT_FOUND', async () => {
  await signUp(REFERRER, 'P4 Referrer');
  await expectReason(call('paymentGetOrder')({ orderId: orders.first }), 'ORDER_NOT_FOUND');
  await expectReason(call('paymentGetOrder')({ orderId: 'no_such_order' }), 'ORDER_NOT_FOUND');
  await expectReason(call('paymentGetOrder')({ orderId: '../users/x' }), 'ORDER_NOT_FOUND');
  await expectDenied(getDoc(doc(cDb, 'payment_orders', orders.first)));
});

test('referral reward on the first web payment follows the Google Play rules; the refund claws it back', async () => {
  const referrerUid = cAuth.currentUser.uid;
  const { code } = await call('referralGetCode')({});
  const refereeUid = await signUp(REFEREE, 'P4 Referee');
  assert.deepEqual(await call('referralApply')({ code }), { ok: true });

  const o = await createOrder();
  assert.equal((await pressCheckout(o.orderId, 'pay')).status, 303);
  assert.equal((await call('paymentGetOrder')({ orderId: o.orderId })).balance, 2, '+1 purchase +1 referral');
  assert.equal(await credits(referrerUid), 1, 'the referrer is rewarded too');
  const item = (await db.doc(`referrals/${referrerUid}/items/${refereeUid}`).get()).data();
  assert.equal(item.status, 'rewarded');
  assert.equal((await db.doc(`payment_orders/${o.orderId}`).get()).get('referral_referrer_uid'), referrerUid);
  const bonus = await db.collection(`entitlements/${refereeUid}/ledger`).where('reason', '==', 'referral').get();
  assert.equal(bonus.docs[0]?.get('purchase_ref'), `web_${o.orderId}`);

  await signInAs(ADMIN);
  assert.deepEqual(await call('adminRefundOrder')({ orderId: o.orderId, reason: 'e2e referral refund' }), { status: 'refunded', creditsClawedBack: 1 });
  assert.equal(await credits(refereeUid), 0, 'purchase and referral credit clawed back');
  assert.equal(await credits(referrerUid), 0, 'the referrer bonus is clawed back');
  assert.equal((await db.doc(`referrals/${referrerUid}/items/${refereeUid}`).get()).get('status'), 'revoked');
  assert.deepEqual((await db.doc(`payment_orders/${o.orderId}`).get()).get('refund.referral_clawed_back'), { referee: 1, referrer: 1 });
});

// ---------------------------------------------------------------- strict ORT style

test('strict ORT style: SECTION_NOT_OVER before the deadline; flags are ignored', async () => {
  const strictUid = await signUp(STRICT, 'P4 Strict');
  const p = await freshStart({ examStyle: 'strict' });
  assert.equal(p.examStyle, 'strict');
  assert.equal(p.entitlementSource, 'free_first');
  const qid = p.section.questions[0].id;
  const e = await expectReason(call('examSubmitSection')({ attemptId: p.attemptId, sectionId: 'chemistry', answers: { [qid]: 'A' }, flags: [qid] }), 'SECTION_NOT_OVER');
  assert.equal(e.details.deadlineAt, p.section.deadlineAt);
  assert.equal((await db.doc(`exam_attempts/${p.attemptId}`).get()).get('status'), 'in_progress', 'nothing was submitted');

  // Let the section time run out (move the server deadline to 2 s from now).
  const ref = db.doc(`exam_attempts/${p.attemptId}`);
  const att = (await ref.get()).data();
  const deadline = AdminTimestamp.fromMillis(Date.now() + 2_000);
  att.sections[0].deadline_at = deadline;
  await ref.update({ sections: att.sections, current_deadline_at: deadline });
  const done = await call('examSubmitSection')({ attemptId: p.attemptId, sectionId: 'chemistry', answers: { [qid]: 'A' }, flags: [qid] });
  assert.equal(done.completed, true);
  assert.equal(done.result.correct, 1);
  const stored = (await db.doc(`exam_attempts/${p.attemptId}/answers/chemistry`).get()).data();
  assert.deepEqual(stored.flags, [], 'no flags in strict style');
  assert.equal((await db.doc(`exam_attempts/${p.attemptId}`).get()).get('exam_style'), 'strict');
  assert.ok(strictUid);
});

// ---------------------------------------------------------------- account deletion

test('accountDelete: payment orders are kept but anonymized; generated variants are deleted', async () => {
  const anon = `deleted:${createHash('sha256').update(buyerUid, 'utf8').digest('hex')}`;
  const ownOrders = (await db.collection('payment_orders').where('uid', '==', buyerUid).get()).size;
  assert.ok(ownOrders >= 10);
  await signInAs(BUYER);
  assert.equal((await call('accountDelete')({})).ok, true);
  assert.equal((await db.collection('payment_orders').where('uid', '==', buyerUid).get()).size, 0);
  assert.equal((await db.collection('payment_orders').where('uid', '==', anon).get()).size, ownOrders, 'financial records kept, anonymized');
  assert.equal((await db.collection('exam_variants').where('generated_for', '==', buyerUid).get()).size, 0, 'fresh variants deleted');
  assert.equal((await db.collection('payment_attempts').where('uid', '==', buyerUid).get()).size, 0, 'order counters deleted');
  assert.ok((await db.collection('payment_events').where('order_id', '==', orders.first).get()).size >= 1, 'provider events kept (no uid)');
  await assert.rejects(createOrder());
});
