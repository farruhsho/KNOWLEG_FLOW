import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { loadRawBlueprints } from '../src/blueprints';
import { applyRemoteReviews, buildImportPlan, CollectionName, commitPlan, FirestorePort, ImportInput, MAX_BATCH } from '../src/importer';
import { BankItem, VariantFile } from '../src/schema';
import { REPO_PATHS, syntheticBank } from './fixtures';
import { assembleMany, ctxFor } from './helpers';

class FakeFirestore implements FirestorePort {
  readonly docs = new Map<string, Record<string, unknown>>();
  readonly batches: number[] = [];
  async getExisting(collection: CollectionName, ids: string[]): Promise<Map<string, Record<string, unknown>>> {
    const out = new Map<string, Record<string, unknown>>();
    for (const id of ids) {
      const d = this.docs.get(`${collection}/${id}`);
      if (d) out.set(id, structuredClone(d));
    }
    return out;
  }
  async commitBatch(writes: Array<{ collection: CollectionName; id: string; data: Record<string, unknown>; merge: boolean }>): Promise<void> {
    assert.ok(writes.length <= MAX_BATCH);
    this.batches.push(writes.length);
    for (const w of writes) {
      const k = `${w.collection}/${w.id}`;
      this.docs.set(k, w.merge ? { ...(this.docs.get(k) ?? {}), ...structuredClone(w.data) } : structuredClone(w.data));
    }
  }
}

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
    assert.deepEqual(Object.keys(k.data).sort(), ['correct', 'explanation', 'solution_steps', 'wrong_option_notes']);
    assert.deepEqual(Object.keys(q.data).sort(), [
      'content_hash', 'content_version', 'created_at', 'difficulty', 'image_path', 'language', 'options', 'passage_id', 'review', 'section_id',
      'source', 'stem', 'subject_id', 'subtopic_id', 'table', 'topic_id', 'translation_group_id', 'type', 'updated_at',
    ]);
    assert.deepEqual(q.data.created_at, { __timestamp: items.find((i) => i.id === q.id)!.question.created_at });
    assert.match(q.id, /^q_[0-9a-f]{20}$/);
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
    const local = structuredClone(items.slice(0, 4)).map((i) => ({ ...i, question: { ...i.question, review: { status: 'ai_verified' as const, reviewed_by: null, reviewed_at: null, notes: 'AI' } } }));
    const ts = { toDate: () => new Date('2026-11-03T09:00:00.000Z') };
    const remote = new Map<string, Record<string, unknown>>([
      [local[0]!.id, { content_hash: local[0]!.question.content_hash, review: { status: 'methodologist_approved', reviewed_by: 'uid_m', reviewed_at: ts, notes: 'ок' } }],
      [local[1]!.id, { content_hash: local[1]!.question.content_hash, review: { status: 'rejected', reviewed_by: 'uid_m', reviewed_at: ts, notes: 'два ответа' } }],
      [local[2]!.id, { content_hash: local[2]!.question.content_hash, review: { status: 'draft' } }],
      [local[3]!.id, { content_hash: 'sha256:' + '0'.repeat(64), review: { status: 'methodologist_approved' } }],
    ]);
    const updates = applyRemoteReviews(local, remote, '2026-11-04T00:00:00.000Z');
    assert.deepEqual(updates.map((u) => [u.id, u.to]), [[local[0]!.id, 'methodologist_approved'], [local[1]!.id, 'rejected']]);
    assert.deepEqual(local[0]!.question.review, { status: 'methodologist_approved', reviewed_by: 'uid_m', reviewed_at: '2026-11-03T09:00:00.000Z', notes: 'ок' });
    assert.equal(local[2]!.question.review.status, 'ai_verified', 'a remote downgrade is ignored');
    assert.equal(local[3]!.question.review.status, 'ai_verified', 'different content is ignored');
  });

  it('commit: writes in ≤ 400 batches, then is a no-op for unchanged questions and never touches published variants', async () => {
    const db = new FakeFirestore();
    const plan = buildImportPlan(input(items, passages, files, { batchSize: 150 }));
    const first = await commitPlan(plan, db, 150);
    assert.equal(first.written, 305);
    assert.deepEqual(db.batches, [150, 150, 5]);

    // A methodologist approved/rejected in the admin panel; the variant got published by the server.
    const qid = plan.ops.find((o) => o.collection === 'exam_questions')!.id;
    (db.docs.get(`exam_questions/${qid}`)!.review as { status: string }).status = 'rejected';
    db.docs.get(`exam_variants/${variant.id}`)!.status = 'published';
    db.docs.get(`exam_variants/${variant.id}`)!.stats = { attempts: 12, avg_percent: 61 };

    const second = await commitPlan(plan, db, 150);
    assert.deepEqual(second.skipped_published, [variant.id]);
    assert.equal(second.unchanged, 150, 'questions with the same content hash are skipped');
    assert.deepEqual(second.review_conflicts, [{ id: qid, local: 'methodologist_approved', remote: 'rejected' }]);
    assert.equal((db.docs.get(`exam_questions/${qid}`)!.review as { status: string }).status, 'rejected', 'remote review wins');
    assert.deepEqual(db.docs.get(`exam_variants/${variant.id}`)!.stats, { attempts: 12, avg_percent: 61 });
    assert.equal(db.docs.get(`exam_variants/${variant.id}`)!.status, 'published');
  });
});
