import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { loadRawBlueprints } from '../src/blueprints';
import { deletedFields, toFirestoreValue } from '../src/firestore';
import {
  applyRemoteReviews,
  applyRemoteVariantStatuses,
  buildImportPlan,
  cmsEditCaughtUp,
  cmsTranslationLink,
  commitPlan,
  conflictReason,
  DELETE_FIELD,
  fromStoredTable,
  ImportInput,
  keyDoc,
  nestedArrayPaths,
  passageDoc,
  questionDoc,
  remoteQuestionHash,
  toStoredTable,
} from '../src/importer';
import { BankItem, VariantFile } from '../src/schema';
import { REPO_PATHS, syntheticBank } from './fixtures';
import { assembleMany, ctxFor, FakeFirestore } from './helpers';

function input(items: BankItem[], passages: ReturnType<typeof syntheticBank>['passages'], variants: VariantFile[], extra: Partial<ImportInput> = {}): ImportInput {
  return {
    projectId: 'knowleg-33f36',
    rawBlueprints: loadRawBlueprints(REPO_PATHS.blueprints),
    blueprintIds: ['ort_main_2026'],
    items: new Map(items.map((i) => [i.id, i])),
    passages: new Map(passages.map((p) => [p.id, p])),
    variants,
    publish: false,
    publishedBy: 'uid_admin',
    includeAllItems: false,
    ctx: ctxFor(items, passages),
    ...extra,
  };
}

describe('import (dry run plan)', () => {
  const { items, passages } = syntheticBank('ort_main_2026', 'ru', 1);
  const { files } = assembleMany('ort_main_2026', 'ru', items, passages, 1);
  const variant = files[0]!;
  const byId = new Map(items.map((i) => [i.id, i]));

  it('produces the expected write plan: referenced docs first, variants last, ≤ 400 per batch, no deletes', () => {
    const plan = buildImportPlan(input(items, passages, files));
    assert.deepEqual(plan.summary, { exam_blueprints: 1, exam_passages: 3, exam_questions: 150, exam_question_keys: 150, exam_variants: 1 });
    assert.deepEqual(plan.batches, [305]);
    const order = [...new Set(plan.ops.map((o) => o.collection))];
    assert.deepEqual(order, ['exam_blueprints', 'exam_passages', 'exam_questions', 'exam_question_keys', 'exam_variants']);
    assert.ok(plan.ops.every((o) => typeof o.data === 'object' && !('delete' in o)));
    assert.equal(plan.project_id, 'knowleg-33f36');
    const v = plan.ops.find((o) => o.collection === 'exam_variants')!;
    assert.equal(v.id, variant.id);
    assert.equal(v.data.status, 'draft');
    assert.equal(v.data.published_at, null);
    assert.deepEqual(plan.variants, [{ id: variant.id, status: 'draft', note: 'draft' }]);
    const small = buildImportPlan(input(items, passages, files, { batchSize: 100 }));
    assert.deepEqual(small.batches, [100, 100, 100, 5]);
    assert.throws(() => buildImportPlan(input(items, passages, files, { batchSize: 401 })));
  });

  it('keeps keys out of exam_questions and writes them to exam_question_keys under the same id', () => {
    const plan = buildImportPlan(input(items, passages, files));
    const q = plan.ops.find((o) => o.collection === 'exam_questions')!;
    const k = plan.ops.find((o) => o.collection === 'exam_question_keys' && o.id === q.id)!;
    for (const secret of ['correct', 'explanation', 'wrong_option_notes', 'solution_steps', 'key', 'target', 'pipeline']) assert.equal(secret in q.data, false, secret);
    assert.deepEqual(Object.keys(k.data).sort(), ['correct', 'explanation', 'pipeline_hash', 'solution_steps', 'wrong_option_notes']);
    assert.deepEqual(Object.keys(q.data).sort(), [
      'content_hash', 'content_version', 'created_at', 'difficulty', 'image_path', 'language', 'options', 'part_id', 'passage_id', 'pipeline_hash',
      'pipeline_translation_group_id', 'review', 'section_id', 'source', 'stem', 'subject_id', 'subtopic_id', 'table', 'topic_id', 'translation_group_id', 'type',
      'updated_at',
    ]);
    assert.equal(q.data.pipeline_translation_group_id, q.data.translation_group_id, 'the link the pipeline wrote is recorded (CP-NEW-2)');
    assert.deepEqual(q.data.created_at, { __timestamp: byId.get(q.id)!.question.created_at });
    assert.match(q.id, /^q_[0-9a-f]{20}$/);
  });

  it('stores comparison tables as rows of {cells} (no array inside an array) without changing ids (EXAM-02 / CP-01)', () => {
    const plan = buildImportPlan(input(items, passages, files));
    for (const op of plan.ops) assert.deepEqual(nestedArrayPaths(op.data), [], `${op.collection}/${op.id}`);
    const qc = plan.ops.filter((o) => o.collection === 'exam_questions' && o.data.type === 'quantitative_comparison');
    assert.equal(qc.length, 30, 'one main variant carries 30 comparison items');
    for (const op of qc) {
      const item = byId.get(op.id)!;
      const [a, b] = item.question.table!.rows[0]!;
      assert.deepEqual(op.data.table, { headers: item.question.table!.headers, rows: [{ cells: [a, b] }] });
      assert.deepEqual(fromStoredTable(op.data.table), item.question.table, 'the stored shape converts back to the bank shape');
      assert.equal(op.data.content_hash, item.question.content_hash, 'the content hash (and so the id) is computed on the bank shape');
      assert.equal(remoteQuestionHash(op.data), item.question.content_hash);
    }
    // Wire shape (rows as lists) and missing tables are read too.
    assert.deepEqual(fromStoredTable({ headers: ['A', 'Б'], rows: [['1', '2']] }), { headers: ['A', 'Б'], rows: [['1', '2']] });
    assert.equal(fromStoredTable(null), null);
    assert.equal(toStoredTable(null), null);
    // Anything else that would hold a nested array is refused at plan time, not at commit time.
    const raw = loadRawBlueprints(REPO_PATHS.blueprints).map((b) => (b.id === 'ort_main_2026' ? { ...b, matrix: [[1, 2]] } : b));
    assert.throws(() => buildImportPlan(input(items, passages, files, { rawBlueprints: raw })), /array inside an array: exam_blueprints\/ort_main_2026 \$\.matrix\[0\]/);
  });

  it('writes part_id from the blueprint slot on every question (CP-06)', () => {
    const plan = buildImportPlan(input(items, passages, files));
    const qs = plan.ops.filter((o) => o.collection === 'exam_questions');
    for (const op of qs) assert.equal(op.data.part_id, byId.get(op.id)!.target.part_id, op.id);
    const parts = new Set(qs.map((o) => o.data.part_id));
    for (const p of ['math_comparison', 'math_problems', 'analogies', 'completion', 'reading', 'grammar']) assert.ok(parts.has(p), p);
    assert.ok(qs.filter((o) => o.data.type === 'quantitative_comparison').every((o) => o.data.part_id === 'math_comparison'));
  });

  it('is idempotent: the same content gives the same ids and data', () => {
    const a = buildImportPlan(input(items, passages, files));
    const b = buildImportPlan(input([...items].reverse(), [...passages].reverse(), files));
    assert.deepEqual(a.ops, b.ops);
  });

  it('publishes only with --publish and only when every item is approved; otherwise keeps the variant a draft', () => {
    const pub = buildImportPlan(input(items, passages, files, { publish: true }));
    const v = pub.ops.find((o) => o.collection === 'exam_variants')!;
    assert.equal(v.data.status, 'published');
    assert.deepEqual(v.data.published_at, { __server_timestamp: true });
    assert.equal(v.data.published_by, 'uid_admin');
    assert.match(pub.variants[0]!.note, /an existing variant keeps its status/);

    const unapproved = items.map((i, n) => (n === 0 ? { ...i, question: { ...i.question, review: { ...i.question.review, status: 'ai_verified' as const } } } : i));
    const kept = buildImportPlan(input(unapproved, passages, files, { publish: true, ctx: ctxFor(unapproved, passages) }));
    const kv = kept.ops.find((o) => o.collection === 'exam_variants')!;
    assert.equal(kv.data.status, 'draft');
    assert.match(kept.variants[0]!.note, /kept as draft: REVIEW_NOT_APPROVED/);
  });

  it('skips invalid and archived variants and never imports rejected items', () => {
    const broken: VariantFile = structuredClone(variant);
    broken.id = 'v_broken';
    broken.variant.sections[0]!.question_ids.pop();
    const archived: VariantFile = structuredClone(variant);
    archived.id = 'v_archived';
    archived.variant.status = 'archived';
    const plan = buildImportPlan(input(items, passages, [broken, archived]));
    assert.equal(plan.summary.exam_variants, 0);
    assert.deepEqual(plan.skipped.map((s) => s.id).sort(), ['v_archived', 'v_broken']);

    const rejected = items.map((i, n) => (n < 3 ? { ...i, question: { ...i.question, review: { ...i.question.review, status: 'rejected' as const } } } : i));
    const all = buildImportPlan(input(rejected, passages, [], { includeAllItems: true }));
    assert.equal(all.summary.exam_questions, items.length - 3);
  });

  it('review-sync: human decisions from Firestore win locally, only for the same content', () => {
    const local = structuredClone(items.slice(0, 6)).map((i) => ({ ...i, question: { ...i.question, review: { status: 'ai_verified' as const, reviewed_by: null, reviewed_at: null, notes: 'AI' } } }));
    const at = { __timestamp: '2026-11-03T09:00:00.000Z' };
    const stored = (i: BankItem, extra: Record<string, unknown>): Record<string, unknown> => ({ ...questionDoc(i), ...extra });
    const remote = new Map<string, Record<string, unknown>>([
      [local[0]!.id, stored(local[0]!, { review: { status: 'methodologist_approved', reviewed_by: 'uid_m', reviewed_at: at, notes: 'ок' } })],
      [local[1]!.id, stored(local[1]!, { review: { status: 'rejected', reviewed_by: 'uid_m', reviewed_at: at, notes: 'два ответа' } })],
      [local[2]!.id, stored(local[2]!, { review: { status: 'draft' } })],
      [local[3]!.id, stored(local[3]!, { content_hash: 'sha256:' + '0'.repeat(64), review: { status: 'methodologist_approved' } })],
      // Edited in the admin panel (same content_hash kept, stem changed), then approved there.
      [local[4]!.id, stored(local[4]!, { stem: 'Исправлено в админке', edited_in_cms_at: at, review: { status: 'methodologist_approved', reviewed_by: 'uid_m' } })],
      // Key changed in the admin panel, question untouched, then approved there.
      [local[5]!.id, stored(local[5]!, { review: { status: 'methodologist_approved', reviewed_by: 'uid_m' } })],
    ]);
    const k5 = keyDoc(local[5]!);
    const remoteKeys = new Map<string, Record<string, unknown>>([
      [local[0]!.id, keyDoc(local[0]!)],
      [local[5]!.id, { correct: k5.correct === 'A' ? 'B' : 'A', explanation: 'новое', wrong_option_notes: {}, solution_steps: [], updated_by: 'uid_m' }],
    ]);
    const { updates, cms_conflicts } = applyRemoteReviews(local, remote, '2026-11-04T00:00:00.000Z', remoteKeys);
    assert.deepEqual(updates.map((u) => [u.id, u.to]), [[local[0]!.id, 'methodologist_approved'], [local[1]!.id, 'rejected']]);
    assert.deepEqual(local[0]!.question.review, { status: 'methodologist_approved', reviewed_by: 'uid_m', reviewed_at: '2026-11-03T09:00:00.000Z', notes: 'ок' });
    assert.equal(local[2]!.question.review.status, 'ai_verified', 'a remote downgrade is ignored');
    assert.equal(local[3]!.question.review.status, 'ai_verified', 'different content is ignored');
    assert.equal(local[4]!.question.review.status, 'ai_verified', 'an approval of content edited in the admin panel is not pulled');
    assert.equal(local[5]!.question.review.status, 'ai_verified', 'an approval of a key edited in the admin panel is not pulled');
    assert.deepEqual(cms_conflicts.map((c) => c.id), [local[3]!.id, local[4]!.id, local[5]!.id]);
    assert.match(cms_conflicts[2]!.reason, /^key: saved in the admin panel by uid_m/);
  });

  it('review-sync: pulls archived and published variant statuses from Firestore (CP-10)', () => {
    const a = structuredClone(variant);
    const b = structuredClone(variant);
    b.id = 'v_other';
    const c = structuredClone(variant);
    c.id = 'v_changed';
    const remote = new Map<string, Record<string, unknown>>([
      [a.id, { status: 'archived', archived_by: 'uid_admin' }],
      [b.id, { status: 'published', published_at: '2026-11-03T10:00:00.000Z', published_by: 'uid_admin', sections: b.variant.sections }],
      [c.id, { status: 'published', sections: [{ section_id: 'math', question_ids: ['q_x'] }] }],
    ]);
    const res = applyRemoteVariantStatuses([a, b, c], remote, '2026-11-04T00:00:00.000Z');
    assert.deepEqual(res.updates, [{ id: a.id, from: 'draft', to: 'archived' }, { id: 'v_other', from: 'draft', to: 'published' }]);
    assert.equal(a.variant.status, 'archived');
    assert.equal(b.variant.published_at, '2026-11-03T10:00:00.000Z');
    assert.equal(b.variant.published_by, 'uid_admin');
    assert.deepEqual(res.mismatched, ['v_changed']);
    assert.equal(c.variant.status, 'draft');
  });
});

describe('import (commit)', () => {
  const { items, passages } = syntheticBank('ort_main_2026', 'ru', 1);
  const { files } = assembleMany('ort_main_2026', 'ru', items, passages, 1);
  const variant = files[0]!;

  it('writes in ≤ 400 batches, then is a no-op for unchanged documents and never touches published variants', async () => {
    const db = new FakeFirestore();
    const plan = buildImportPlan(input(items, passages, files, { batchSize: 150 }));
    const first = await commitPlan(plan, db, 150);
    assert.equal(first.written, 305, 'a main variant with 30 comparison tables commits (the fake rejects nested arrays like Firestore)');
    assert.deepEqual(db.batches, [150, 150, 5]);

    // A methodologist rejected in the admin panel; the variant got published by the server.
    const qid = plan.ops.find((o) => o.collection === 'exam_questions')!.id;
    (db.get('exam_questions', qid)!.review as { status: string }).status = 'rejected';
    db.get('exam_variants', variant.id)!.status = 'published';
    db.get('exam_variants', variant.id)!.stats = { attempts: 12, avg_percent: 61 };

    const second = await commitPlan(plan, db, 150);
    assert.deepEqual(second.skipped_published, [variant.id]);
    assert.equal(second.written, 0);
    assert.equal(second.unchanged, 1 + 3 + 150 + 150, 'blueprint, passages, questions and keys with the same content are skipped');
    assert.deepEqual(second.review_conflicts, [{ id: qid, local: 'methodologist_approved', remote: 'rejected' }]);
    assert.equal((db.get('exam_questions', qid)!.review as { status: string }).status, 'rejected', 'remote review wins');
    assert.deepEqual(db.get('exam_variants', variant.id)!.stats, { attempts: 12, avg_percent: 61 });
    assert.equal(db.get('exam_variants', variant.id)!.status, 'published');
    assert.deepEqual(second.cms_conflicts, []);
  });

  it('never changes the status of an existing variant and never revives one archived in the admin panel (CP-10)', async () => {
    const db = new FakeFirestore();
    await commitPlan(buildImportPlan(input(items, passages, files)), db);
    const publishPlan = buildImportPlan(input(items, passages, files, { publish: true }));

    // adminPublishVariant(publish: false)
    Object.assign(db.get('exam_variants', variant.id)!, { status: 'archived', archived_by: 'uid_admin' });
    const r1 = await commitPlan(publishPlan, db);
    assert.deepEqual(r1.skipped_archived, [variant.id]);
    assert.deepEqual(r1.published, []);
    assert.equal(db.get('exam_variants', variant.id)!.status, 'archived');
    assert.equal(db.get('exam_variants', variant.id)!.published_at, null);

    // An existing draft is not published by the pipeline: that is adminPublishVariant's job.
    db.get('exam_variants', variant.id)!.status = 'draft';
    const r2 = await commitPlan(publishPlan, db);
    assert.deepEqual(r2.publish_in_admin, [variant.id]);
    assert.deepEqual(r2.published, []);
    assert.equal(db.get('exam_variants', variant.id)!.status, 'draft');
    assert.equal(db.get('exam_variants', variant.id)!.published_at, null);

    // A variant that is new in Firestore is created as published.
    const fresh = new FakeFirestore();
    const r3 = await commitPlan(publishPlan, fresh);
    assert.deepEqual(r3.published, [variant.id]);
    assert.equal(fresh.get('exam_variants', variant.id)!.status, 'published');
  });

  it('backfills part_id and pipeline_hash on documents written by the previous pipeline version', async () => {
    const db = new FakeFirestore();
    const plan = buildImportPlan(input(items, passages, files));
    for (const op of plan.ops) {
      const legacy = structuredClone(op.data);
      delete legacy.part_id;
      delete legacy.pipeline_hash;
      delete legacy.pipeline_translation_group_id;
      if (op.collection === 'exam_passages') delete legacy.content_hash;
      db.set(op.collection, op.id, legacy);
    }
    const r = await commitPlan(plan, db);
    assert.deepEqual(r.cms_conflicts, []);
    assert.equal(r.written, 305 - 1, 'everything except the unchanged blueprint');
    const q = plan.ops.find((o) => o.collection === 'exam_questions')!;
    assert.equal(db.get('exam_questions', q.id)!.part_id, q.data.part_id);
    assert.equal(db.get('exam_questions', q.id)!.pipeline_translation_group_id, q.data.translation_group_id);
    assert.deepEqual(r.translation_links_kept, [], 'an unchanged link is not reported');
  });

  it('does not revert documents edited in the admin panel; reports them; --overwrite replaces them (CP-04)', async () => {
    const db = new FakeFirestore();
    const plan = buildImportPlan(input(items, passages, files));
    await commitPlan(plan, db);
    const qids = plan.ops.filter((o) => o.collection === 'exam_questions' && o.data.passage_id === null).map((o) => o.id);
    const [q1, q2, q3, q4, q5] = qids as [string, string, string, string, string];
    const at = { __timestamp: '2026-11-03T12:00:00.000Z' };
    const otherCorrect = (id: string): string => (db.get('exam_question_keys', id)!.correct === 'A' ? 'B' : 'A');

    // q1: new admin panel — stem fixed, content_hash kept, edited_in_cms_at set, review reset to draft; key re-saved.
    Object.assign(db.get('exam_questions', q1)!, { stem: 'Исправленное условие', edited_in_cms_at: at, updated_by: 'uid_m', review: { status: 'draft', reviewed_by: null, reviewed_at: null, notes: '' } });
    Object.assign(db.get('exam_question_keys', q1)!, { updated_by: 'uid_m' });
    delete db.get('exam_question_keys', q1)!.pipeline_hash;
    // q2: old admin panel — content_hash rewritten with its own scheme.
    Object.assign(db.get('exam_questions', q2)!, { content_hash: 'sha256:' + 'c'.repeat(64), updated_by: 'uid_m' });
    // q3: edited in the Firebase console, no markers at all.
    Object.assign(db.get('exam_questions', q3)!, { stem: 'Правка в консоли' });
    // q4: only the key changed in the admin panel (wrong key fixed); the question is otherwise identical.
    const fixed = otherCorrect(q4);
    Object.assign(db.get('exam_questions', q4)!, { edited_in_cms_at: at, review: { status: 'draft', reviewed_by: null, reviewed_at: null, notes: '' } });
    db.set('exam_question_keys', q4, { ...db.get('exam_question_keys', q4)!, correct: fixed, updated_by: 'uid_m' });
    delete db.get('exam_question_keys', q4)!.pipeline_hash;
    // q5: saved in the admin panel without any change — nothing to revert, not a conflict.
    Object.assign(db.get('exam_questions', q5)!, { edited_in_cms_at: at });
    db.set('exam_question_keys', q5, { ...keyDoc(items.find((i) => i.id === q5)!), updated_by: 'uid_m' });
    delete db.get('exam_question_keys', q5)!.pipeline_hash;
    // A passage text edited in the admin panel.
    const pid = passages[0]!.id;
    Object.assign(db.get('exam_passages', pid)!, { text: 'Новый текст', source: 'учебник', updated_by: 'uid_m' });
    // A draft variant edited in the variant builder.
    const v = db.get('exam_variants', variant.id)!;
    const sections = structuredClone(v.sections) as Array<{ question_ids: string[] }>;
    sections[0]!.question_ids.reverse();
    Object.assign(v, { sections, content_version: 2, updated_by: 'uid_cm' });

    const r = await commitPlan(plan, db);
    const ids = (c: string): string[] => r.cms_conflicts.filter((x) => x.collection === c).map((x) => x.id).sort();
    assert.deepEqual(ids('exam_questions'), [q1, q2, q3, q4].sort());
    assert.deepEqual(ids('exam_question_keys'), [q1, q2, q3, q4].sort(), 'a question and its key are held back together');
    assert.deepEqual(ids('exam_passages'), [pid]);
    assert.deepEqual(ids('exam_variants'), [variant.id]);
    assert.deepEqual(r.overwritten, []);
    assert.equal(db.get('exam_questions', q1)!.stem, 'Исправленное условие');
    assert.equal((db.get('exam_questions', q1)!.review as { status: string }).status, 'draft', 'the bank approval is not stamped on edited content');
    assert.equal(db.get('exam_question_keys', q4)!.correct, fixed, 'the fixed key is not reverted');
    assert.equal((db.get('exam_questions', q4)!.review as { status: string }).status, 'draft');
    assert.equal(db.get('exam_questions', q3)!.stem, 'Правка в консоли');
    assert.equal(db.get('exam_passages', pid)!.text, 'Новый текст');
    assert.equal(db.get('exam_variants', variant.id)!.content_version, 2);
    assert.equal(db.get('exam_question_keys', q5)!.updated_by, undefined, 'q5 was in sync: the key is pipeline-owned again');

    // A variant new in Firestore that uses edited questions is written as a draft, not published.
    db.docs.delete(`exam_variants/${variant.id}`);
    const pub = await commitPlan(buildImportPlan(input(items, passages, files, { publish: true })), db);
    assert.equal(pub.publish_blocked.length, 1);
    assert.match(pub.publish_blocked[0]!.reason, /edited outside the pipeline/);
    assert.deepEqual(pub.published, []);
    assert.equal(db.get('exam_variants', variant.id)!.status, 'draft');

    // --overwrite discards the edits (never a variant status); afterwards the documents are pipeline-owned again.
    Object.assign(db.get('exam_variants', variant.id)!, { content_version: 7, updated_by: 'uid_cm' });
    const o = await commitPlan(plan, db, { overwrite: true });
    assert.deepEqual(o.cms_conflicts, []);
    assert.equal(o.overwritten.length, 4 + 4 + 1 + 1);
    assert.equal(db.get('exam_questions', q1)!.stem, items.find((i) => i.id === q1)!.question.stem);
    assert.equal('edited_in_cms_at' in db.get('exam_questions', q1)!, false, 'the marker is deleted (FieldValue.delete), not set to null');
    assert.equal(db.get('exam_question_keys', q4)!.correct, items.find((i) => i.id === q4)!.key.correct);
    assert.equal(db.get('exam_passages', pid)!.text, passages[0]!.passage.text);
    assert.equal(db.get('exam_variants', variant.id)!.status, 'draft');
    const again = await commitPlan(plan, db);
    assert.deepEqual(again.cms_conflicts, []);
    assert.equal(again.written, 0);
  });

  it('takes back a question whose admin-panel edit is in the bank: hash fields only, marker deleted; later bank metadata changes are no conflict (CP-NEW-1)', async () => {
    const db = new FakeFirestore();
    const plan = buildImportPlan(input(items, passages, files));
    await commitPlan(plan, db);
    const qids = plan.ops.filter((o) => o.collection === 'exam_questions' && o.data.passage_id === null).map((o) => o.id);
    const [qa, qb, qc] = qids as [string, string, string];
    const at = { __timestamp: '2026-11-03T12:00:00.000Z' };
    const fixedExplanation = 'Исправленное объяснение';

    // qa: a methodologist fixes the key explanation in the admin panel; the save stamps the question too.
    Object.assign(db.get('exam_questions', qa)!, { edited_in_cms_at: at, updated_by: 'uid_m' });
    db.set('exam_question_keys', qa, { ...keyDoc(items.find((i) => i.id === qa)!), explanation: fixedExplanation, updated_by: 'uid_m', edited_in_cms_at: at });
    delete db.get('exam_question_keys', qa)!.pipeline_hash;
    // qb: only metadata (difficulty) changed in the admin panel.
    const bankDifficulty = items.find((i) => i.id === qb)!.question.difficulty;
    const cmsDifficulty = bankDifficulty === 3 ? 2 : 3;
    Object.assign(db.get('exam_questions', qb)!, { difficulty: cmsDifficulty, edited_in_cms_at: at, updated_by: 'uid_m' });
    // qc: the stem changed in the admin panel and was not ported: still a conflict.
    Object.assign(db.get('exam_questions', qc)!, { stem: 'Правка методиста', edited_in_cms_at: at });

    // Detection: content equal by the pipeline's hash = caught up; different content = conflict.
    const doc = (id: string): Record<string, unknown> => plan.ops.find((o) => o.collection === 'exam_questions' && o.id === id)!.data;
    assert.equal(cmsEditCaughtUp('exam_questions', doc(qb), db.get('exam_questions', qb)!), true);
    assert.equal(conflictReason('exam_questions', doc(qb), db.get('exam_questions', qb)!), null, 'metadata is ignored by the content comparison');
    assert.equal(cmsEditCaughtUp('exam_questions', doc(qc), db.get('exam_questions', qc)!), false);
    assert.match(conflictReason('exam_questions', doc(qc), db.get('exam_questions', qc)!)!, /edited in the admin panel/);

    // The operator ports the key fix into the bank (git); the question id does not change.
    const ported = items.map((i) => (i.id === qa ? { ...i, key: { ...i.key, explanation: fixedExplanation } } : i));
    const portedPlan = buildImportPlan(input(ported, passages, files, { ctx: ctxFor(ported, passages) }));
    const qbBefore = structuredClone(db.get('exam_questions', qb)!);
    const r = await commitPlan(portedPlan, db);
    assert.deepEqual(r.cms_conflicts.map((c) => `${c.collection}/${c.id}`).sort(), [`exam_question_keys/${qc}`, `exam_questions/${qc}`]);
    assert.deepEqual([...r.cms_caught_up].sort((x, y) => x.id.localeCompare(y.id)), [{ id: qa, pending_fields: [] }, { id: qb, pending_fields: ['difficulty'] }].sort((x, y) => x.id.localeCompare(y.id)));
    for (const id of [qa, qb]) {
      const stored = db.get('exam_questions', id)!;
      assert.equal('edited_in_cms_at' in stored, false, `${id}: the marker is deleted`);
      assert.equal(stored.pipeline_hash, doc(id).content_hash);
      assert.equal(stored.content_hash, doc(id).content_hash);
    }
    // Nothing but the marker changed in that step: the admin-panel difficulty and updated_by are still there.
    const { edited_in_cms_at: _marker, ...qbExpected } = qbBefore;
    assert.deepEqual(db.get('exam_questions', qb), qbExpected);
    assert.equal(db.get('exam_question_keys', qa)!.explanation, fixedExplanation);
    assert.equal(db.get('exam_question_keys', qa)!.updated_by, undefined, 'the ported key is pipeline-owned again');
    assert.equal(db.get('exam_questions', qc)!.stem, 'Правка методиста');
    assert.deepEqual(db.get('exam_questions', qc)!.edited_in_cms_at, at);

    // Later the bank changes metadata outside the content hash (same id): written, not a conflict.
    const retagged = ported.map((i) => (i.id === qa ? { ...i, question: { ...i.question, subtopic_id: 'ported_subtopic', topic_id: `${i.question.topic_id}_x` } } : i));
    const r2 = await commitPlan(buildImportPlan(input(retagged, passages, files, { ctx: ctxFor(retagged, passages) })), db);
    assert.deepEqual(r2.cms_conflicts.map((c) => c.id), [qc, qc], 'only the unported stem edit is still held back');
    assert.deepEqual(r2.cms_caught_up, []);
    assert.equal(db.get('exam_questions', qa)!.subtopic_id, 'ported_subtopic');
    assert.equal(db.get('exam_questions', qa)!.topic_id, `${items.find((i) => i.id === qa)!.question.topic_id}_x`);
    assert.equal(db.get('exam_questions', qb)!.difficulty, bankDifficulty, 'a pending field reported as caught up is written by the next import');
  });

  it('keeps translation links changed in the admin panel; reports them; --overwrite restores the bank link (CP-NEW-2)', async () => {
    const db = new FakeFirestore();
    const plan = buildImportPlan(input(items, passages, files));
    await commitPlan(plan, db);
    const qs = plan.ops.filter((o) => o.collection === 'exam_questions' && o.data.passage_id === null);
    for (const o of qs) assert.equal(db.get('exam_questions', o.id)!.pipeline_translation_group_id, o.data.translation_group_id);
    const [q1, q2, q3, q4, q5] = qs.map((o) => o.id) as [string, string, string, string, string];
    const tg = (id: string): string | null => items.find((i) => i.id === id)!.question.translation_group_id;

    // q1: linked into another group in the admin panel (link() updates translation_group_id only, no edited_in_cms_at).
    db.get('exam_questions', q1)!.translation_group_id = 'tg_q_cms_link';
    // q2: unlinked in the admin panel.
    db.get('exam_questions', q2)!.translation_group_id = null;
    // q3: written by the previous pipeline version (no record of the link it wrote), then re-linked in the admin panel.
    delete db.get('exam_questions', q3)!.pipeline_translation_group_id;
    db.get('exam_questions', q3)!.translation_group_id = 'tg_q_legacy_link';
    // q4: written by the previous pipeline version, link untouched: the record is backfilled.
    delete db.get('exam_questions', q4)!.pipeline_translation_group_id;
    // q5: re-linked through a full editor save (edited_in_cms_at), content unchanged.
    Object.assign(db.get('exam_questions', q5)!, { translation_group_id: 'tg_q_editor_link', edited_in_cms_at: { __timestamp: '2026-11-03T12:00:00.000Z' } });
    assert.deepEqual(cmsTranslationLink(qs[0]!.data, db.get('exam_questions', q1)!), { remote: 'tg_q_cms_link', local: tg(q1) });
    assert.equal(cmsTranslationLink(qs[3]!.data, db.get('exam_questions', q4)!), null);

    // The bank changes q1's metadata: everything but the link is written.
    const bank = items.map((i) => (i.id === q1 ? { ...i, question: { ...i.question, subtopic_id: 'new_subtopic' } } : i));
    const bankPlan = buildImportPlan(input(bank, passages, files, { ctx: ctxFor(bank, passages) }));
    const r = await commitPlan(bankPlan, db);
    const byId = (xs: Array<{ id: string }>): string[] => xs.map((x) => x.id).sort();
    assert.deepEqual(r.cms_conflicts, []);
    assert.deepEqual(byId(r.translation_links_kept), [q1, q2, q3, q5].sort());
    assert.deepEqual(r.translation_links_kept.find((t) => t.id === q2), { id: q2, remote: null, local: tg(q2) });
    assert.deepEqual(r.cms_caught_up, [{ id: q5, pending_fields: [] }], 'the kept link is not a pending field');
    assert.equal(db.get('exam_questions', q1)!.translation_group_id, 'tg_q_cms_link');
    assert.equal(db.get('exam_questions', q1)!.pipeline_translation_group_id, tg(q1), 'the record of what the pipeline wrote is kept');
    assert.equal(db.get('exam_questions', q1)!.subtopic_id, 'new_subtopic');
    assert.equal(db.get('exam_questions', q2)!.translation_group_id, null);
    assert.equal(db.get('exam_questions', q3)!.translation_group_id, 'tg_q_legacy_link');
    assert.equal('pipeline_translation_group_id' in db.get('exam_questions', q3)!, false);
    assert.equal(db.get('exam_questions', q4)!.pipeline_translation_group_id, tg(q4));
    assert.equal(db.get('exam_questions', q5)!.translation_group_id, 'tg_q_editor_link');
    assert.equal('edited_in_cms_at' in db.get('exam_questions', q5)!, false);

    // Stable: the next import writes nothing and reports the same links.
    const again = await commitPlan(bankPlan, db);
    assert.equal(again.written, 0);
    assert.deepEqual(byId(again.translation_links_kept), [q1, q2, q3, q5].sort());

    // The bank adopts q1's link: the pipeline owns it again.
    const adopted = bank.map((i) => (i.id === q1 ? { ...i, question: { ...i.question, translation_group_id: 'tg_q_cms_link' } } : i));
    const adoptedPlan = buildImportPlan(input(adopted, passages, files, { ctx: ctxFor(adopted, passages) }));
    const r2 = await commitPlan(adoptedPlan, db);
    assert.deepEqual(byId(r2.translation_links_kept), [q2, q3, q5].sort());
    assert.equal(db.get('exam_questions', q1)!.pipeline_translation_group_id, 'tg_q_cms_link');

    // --overwrite restores the bank's links and reports them.
    const o = await commitPlan(adoptedPlan, db, { overwrite: true });
    assert.deepEqual(o.translation_links_kept, []);
    assert.deepEqual(byId(o.overwritten), [q2, q3, q5].sort());
    for (const x of o.overwritten) assert.match(x.reason, /^translation_group_id .* set outside the pipeline, replaced by the bank's tg_/);
    for (const id of [q2, q3, q5]) {
      assert.equal(db.get('exam_questions', id)!.translation_group_id, tg(id));
      assert.equal(db.get('exam_questions', id)!.pipeline_translation_group_id, tg(id));
    }
    const quiet = await commitPlan(adoptedPlan, db);
    assert.equal(quiet.written, 0);
    assert.deepEqual(quiet.translation_links_kept, []);
  });

  it('review-sync pulls approvals of questions whose only admin-panel change is a caught-up edit or a translation link (CP-NEW-1, CP-NEW-2)', () => {
    const local = structuredClone(items.slice(0, 2)).map((i) => ({ ...i, question: { ...i.question, review: { status: 'ai_verified' as const, reviewed_by: null, reviewed_at: null, notes: '' } } }));
    const approved = { status: 'methodologist_approved', reviewed_by: 'uid_m', reviewed_at: '2026-11-03T09:00:00.000Z', notes: '' };
    const remote = new Map<string, Record<string, unknown>>([
      [local[0]!.id, { ...questionDoc(local[0]!), edited_in_cms_at: '2026-11-03T08:00:00.000Z', difficulty: 3, review: approved }],
      [local[1]!.id, { ...questionDoc(local[1]!), translation_group_id: 'tg_q_cms_link', edited_in_cms_at: '2026-11-03T08:00:00.000Z', updated_by: 'uid_m', content_hash: 'sha256:' + 'c'.repeat(64), review: approved }],
    ]);
    const { updates, cms_conflicts } = applyRemoteReviews(local, remote, '2026-11-04T00:00:00.000Z');
    assert.deepEqual(cms_conflicts, []);
    assert.deepEqual(updates.map((u) => [u.id, u.to]), [[local[0]!.id, 'methodologist_approved'], [local[1]!.id, 'methodologist_approved']]);
  });

  it('field deletes become FieldValue.delete() and are refused outside merge writes', async () => {
    const sentinels = { timestamp: (iso: string) => `ts(${iso})`, serverTimestamp: () => 'now()', deleteField: () => 'delete()' };
    assert.deepEqual(toFirestoreValue({ a: DELETE_FIELD, b: { __timestamp: '2026-01-01T00:00:00.000Z' }, c: [{ __server_timestamp: true }], d: 1 }, sentinels), {
      a: 'delete()', b: 'ts(2026-01-01T00:00:00.000Z)', c: ['now()'], d: 1,
    });
    assert.deepEqual(deletedFields({ a: DELETE_FIELD, b: null, c: { __delete_field: false } }), ['a']);
    const db = new FakeFirestore();
    db.set('exam_question_keys', 'k', { correct: 'A', edited_in_cms_at: 'x' });
    await assert.rejects(() => db.commitBatch([{ collection: 'exam_question_keys', id: 'k', data: { correct: 'A', edited_in_cms_at: DELETE_FIELD }, merge: false }]), /merge/);
    await db.commitBatch([{ collection: 'exam_question_keys', id: 'k', data: { edited_in_cms_at: DELETE_FIELD }, merge: true }]);
    assert.deepEqual(db.get('exam_question_keys', 'k'), { correct: 'A' });
  });

  it('passage documents carry the content hash the pipeline wrote', () => {
    const doc = passageDoc(passages[0]!);
    assert.equal(doc.content_hash, passages[0]!.content_hash);
    assert.equal(doc.pipeline_hash, passages[0]!.content_hash);
  });
});
