/**
 * Stage 8 — import into Firestore. `buildImportPlan` is pure: it turns
 * blueprints, bank items, passages and variants into an ordered list of
 * upserts with deterministic, content-hash-based ids, in batches of ≤ 400.
 * It never emits deletes. `commitPlan` applies the plan through a small
 * FirestoreLike port (firebase-admin adapter in firestore.ts) and enforces
 * the guards that need the live documents:
 *   - a published variant is never modified;
 *   - an existing question keeps its review if the remote one is further
 *     along (a methodologist approved it in the admin panel) or rejected;
 *   - server-maintained fields (variant stats, created_at) are not reset.
 */
import { BankItem, BankPassage, VariantFile } from './schema';
import { hasErrors, Problem, validateVariant, ValidationContext } from './validate';
import { REVIEW_RANK, ReviewStatus } from './schema';

export const COLLECTIONS = ['exam_blueprints', 'exam_passages', 'exam_questions', 'exam_question_keys', 'exam_variants'] as const;
export type CollectionName = (typeof COLLECTIONS)[number];
export const MAX_BATCH = 400;

/** JSON-safe markers converted to Firestore values at commit time. */
export type TimestampMarker = { __timestamp: string };
export type ServerTimestampMarker = { __server_timestamp: true };
export const ts = (iso: string | null): TimestampMarker | null => (iso === null ? null : { __timestamp: iso });
export const SERVER_TS: ServerTimestampMarker = { __server_timestamp: true };

export interface WriteOp {
  collection: CollectionName;
  id: string;
  data: Record<string, unknown>;
  /** Fields dropped when the document already exists. */
  preserve_on_update: string[];
  guard: 'none' | 'review' | 'published_variant';
}

export interface ImportPlan {
  project_id: string;
  publish: boolean;
  ops: WriteOp[];
  batches: number[];
  summary: Record<CollectionName, number>;
  variants: Array<{ id: string; status: 'draft' | 'published'; note: string }>;
  skipped: Array<{ id: string; reason: string }>;
}

export interface ImportInput {
  projectId: string;
  rawBlueprints: Array<Record<string, unknown>>;
  blueprintIds: string[] | null;
  items: Map<string, BankItem>;
  passages: Map<string, BankPassage>;
  variants: VariantFile[];
  publish: boolean;
  publishedBy: string;
  includeAllItems: boolean;
  ctx: ValidationContext;
  batchSize?: number;
}

/** exam_questions document: exactly the public fields of ARCHITECTURE §1.3. */
export function questionDoc(item: BankItem): Record<string, unknown> {
  const q = item.question;
  return {
    subject_id: q.subject_id,
    section_id: q.section_id,
    topic_id: q.topic_id,
    subtopic_id: q.subtopic_id,
    difficulty: q.difficulty,
    language: q.language,
    translation_group_id: q.translation_group_id,
    type: q.type,
    stem: q.stem,
    options: q.options.map((o) => ({ id: o.id, text: o.text })),
    passage_id: q.passage_id,
    image_path: q.image_path,
    table: q.table,
    source: { ...q.source },
    review: { status: q.review.status, reviewed_by: q.review.reviewed_by, reviewed_at: ts(q.review.reviewed_at), notes: q.review.notes },
    content_version: q.content_version,
    content_hash: q.content_hash,
    created_at: ts(q.created_at),
    updated_at: ts(q.updated_at),
  };
}

export function keyDoc(item: BankItem): Record<string, unknown> {
  return {
    correct: item.key.correct,
    explanation: item.key.explanation,
    wrong_option_notes: { ...item.key.wrong_option_notes },
    solution_steps: [...item.key.solution_steps],
  };
}

export function passageDoc(p: BankPassage): Record<string, unknown> {
  const x = p.passage;
  return { language: x.language, subject_id: x.subject_id, section_id: x.section_id, title: x.title, text: x.text, source: { ...x.source } };
}

export function buildImportPlan(input: ImportInput): ImportPlan {
  const batchSize = input.batchSize ?? MAX_BATCH;
  if (batchSize < 1 || batchSize > MAX_BATCH) throw new Error(`batch size must be 1..${MAX_BATCH}`);
  const inScope = (bpId: string): boolean => input.blueprintIds === null || input.blueprintIds.includes(bpId);
  const skipped: ImportPlan['skipped'] = [];
  const variantNotes: ImportPlan['variants'] = [];
  const variantOps: WriteOp[] = [];
  const itemIds = new Set<string>();

  for (const f of [...input.variants].sort((a, b) => a.id.localeCompare(b.id))) {
    if (!inScope(f.variant.blueprint_id)) continue;
    if (f.variant.status === 'archived') {
      skipped.push({ id: f.id, reason: 'archived' });
      continue;
    }
    const draftProblems = validateVariant(f.id, f.variant, input.ctx, { publish: false });
    if (hasErrors(draftProblems)) {
      skipped.push({ id: f.id, reason: firstErrors(draftProblems) });
      continue;
    }
    let status: 'draft' | 'published' = 'draft';
    let note = 'draft';
    if (input.publish) {
      const pubProblems = validateVariant(f.id, { ...f.variant, status: 'published' }, input.ctx, { publish: true });
      if (hasErrors(pubProblems)) note = `kept as draft: ${firstErrors(pubProblems)}`;
      else {
        status = 'published';
        note = 'published';
      }
    } else if (f.variant.status === 'published') {
      note = 'local file says published; written as draft only if absent remotely (published docs are never modified)';
    }
    for (const s of f.variant.sections) for (const id of s.question_ids) itemIds.add(id);
    const v = f.variant;
    variantOps.push({
      collection: 'exam_variants',
      id: f.id,
      data: {
        blueprint_id: v.blueprint_id,
        blueprint_version: v.blueprint_version,
        number: v.number,
        title: { ...v.title },
        language: v.language,
        status,
        sections: v.sections.map((s) => ({ section_id: s.section_id, question_ids: [...s.question_ids] })),
        content_version: v.content_version,
        difficulty_label: v.difficulty_label,
        created_by: v.created_by,
        published_at: status === 'published' ? SERVER_TS : null,
        published_by: status === 'published' ? input.publishedBy : null,
        stats: { attempts: 0, avg_percent: 0 },
      },
      preserve_on_update: ['stats', 'created_by'],
      guard: 'published_variant',
    });
    variantNotes.push({ id: f.id, status, note });
  }

  if (input.includeAllItems) {
    for (const it of input.items.values()) {
      if (inScope(it.target.blueprint_id) && it.question.review.status !== 'rejected') itemIds.add(it.id);
    }
  }

  const questionOps: WriteOp[] = [];
  const keyOps: WriteOp[] = [];
  const passageIds = new Set<string>();
  for (const id of [...itemIds].sort()) {
    const it = input.items.get(id);
    if (!it) {
      skipped.push({ id, reason: 'not in local bank' });
      continue;
    }
    if (it.question.review.status === 'rejected') {
      skipped.push({ id, reason: 'rejected' });
      continue;
    }
    if (it.question.passage_id) passageIds.add(it.question.passage_id);
    questionOps.push({ collection: 'exam_questions', id, data: questionDoc(it), preserve_on_update: ['created_at'], guard: 'review' });
    keyOps.push({ collection: 'exam_question_keys', id, data: keyDoc(it), preserve_on_update: [], guard: 'none' });
  }
  const passageOps: WriteOp[] = [];
  for (const pid of [...passageIds].sort()) {
    const p = input.passages.get(pid);
    if (!p) {
      skipped.push({ id: pid, reason: 'passage not in local bank' });
      continue;
    }
    passageOps.push({ collection: 'exam_passages', id: pid, data: passageDoc(p), preserve_on_update: [], guard: 'none' });
  }
  const blueprintOps: WriteOp[] = input.rawBlueprints
    .filter((b) => typeof b.id === 'string' && inScope(b.id))
    .sort((a, b) => String(a.id).localeCompare(String(b.id)))
    .map((b) => ({ collection: 'exam_blueprints' as const, id: String(b.id), data: structuredClone(b), preserve_on_update: [], guard: 'none' as const }));

  // Referenced documents first, variants last.
  const ops = [...blueprintOps, ...passageOps, ...questionOps, ...keyOps, ...variantOps];
  const batches: number[] = [];
  for (let i = 0; i < ops.length; i += batchSize) batches.push(Math.min(batchSize, ops.length - i));
  const summary = Object.fromEntries(COLLECTIONS.map((c) => [c, ops.filter((o) => o.collection === c).length])) as Record<CollectionName, number>;
  return { project_id: input.projectId, publish: input.publish, ops, batches, summary, variants: variantNotes, skipped };
}

function firstErrors(ps: Problem[]): string {
  const errs = ps.filter((p) => p.severity === 'error');
  return errs.slice(0, 3).map((p) => `${p.code}: ${p.message}`).join('; ') + (errs.length > 3 ? ` (+${errs.length - 3} more)` : '');
}

// ---------------------------------------------------------------------------
// Commit
// ---------------------------------------------------------------------------

export interface FirestorePort {
  /** Existing documents among `ids` (missing ids are absent from the map). */
  getExisting(collection: CollectionName, ids: string[]): Promise<Map<string, Record<string, unknown>>>;
  /** Applies ≤ 400 merge-upserts atomically. */
  commitBatch(writes: Array<{ collection: CollectionName; id: string; data: Record<string, unknown>; merge: boolean }>): Promise<void>;
}

export interface CommitReport {
  written: number;
  unchanged: number;
  skipped_published: string[];
  review_conflicts: Array<{ id: string; local: string; remote: string }>;
  batches: number;
}

/**
 * Questions and variants are merged (server-maintained fields survive);
 * blueprints, passages and keys are pipeline-owned and overwritten whole —
 * edit them in content/ (git), not in the console.
 */
export const MERGE: Record<CollectionName, boolean> = {
  exam_blueprints: false,
  exam_passages: false,
  exam_questions: true,
  exam_question_keys: false,
  exam_variants: true,
};

const rankOf = (s: unknown): number => (typeof s === 'string' && s in REVIEW_RANK ? REVIEW_RANK[s as ReviewStatus] : 0);

// ---------------------------------------------------------------------------
// review-sync: methodologist decisions made in the admin panel → local bank
// ---------------------------------------------------------------------------

export interface RemoteReviewUpdate {
  id: string;
  from: ReviewStatus;
  to: ReviewStatus;
  reviewed_by: string | null;
}

/** Firestore Timestamp, ISO string or marker → ISO string. */
function isoOf(v: unknown): string | null {
  if (typeof v === 'string') return v;
  if (v && typeof v === 'object') {
    const o = v as { toDate?: () => Date; __timestamp?: string };
    if (typeof o.toDate === 'function') return o.toDate().toISOString();
    if (typeof o.__timestamp === 'string') return o.__timestamp;
  }
  return null;
}

/**
 * Pulls review decisions from exam_questions documents into local bank items
 * (in place). A remote review wins when it is a human decision further along
 * than the local one, or a rejection — and only for the same content (same
 * content_hash). Never touches Firestore; returns what changed.
 */
export function applyRemoteReviews(items: BankItem[], remote: Map<string, Record<string, unknown>>, now: string): RemoteReviewUpdate[] {
  const updates: RemoteReviewUpdate[] = [];
  for (const it of items) {
    const doc = remote.get(it.id);
    if (!doc || doc.content_hash !== it.question.content_hash) continue;
    const r = doc.review as { status?: unknown; reviewed_by?: unknown; reviewed_at?: unknown; notes?: unknown } | undefined;
    const status = r?.status;
    if (typeof status !== 'string' || !(status in REVIEW_RANK)) continue;
    const local = it.question.review.status;
    if (status === local) continue;
    if (!(status === 'rejected' || rankOf(status) > rankOf(local))) continue;
    it.question.review = {
      status: status as ReviewStatus,
      reviewed_by: typeof r?.reviewed_by === 'string' ? r.reviewed_by : null,
      reviewed_at: isoOf(r?.reviewed_at),
      notes: typeof r?.notes === 'string' ? r.notes : it.question.review.notes,
    };
    it.question.updated_at = now;
    updates.push({ id: it.id, from: local, to: status as ReviewStatus, reviewed_by: it.question.review.reviewed_by });
  }
  return updates;
}

export async function commitPlan(plan: ImportPlan, db: FirestorePort, batchSize = MAX_BATCH): Promise<CommitReport> {
  if (batchSize < 1 || batchSize > MAX_BATCH) throw new Error(`batch size must be 1..${MAX_BATCH}`);
  const report: CommitReport = { written: 0, unchanged: 0, skipped_published: [], review_conflicts: [], batches: 0 };
  const final: Array<{ collection: CollectionName; id: string; data: Record<string, unknown>; merge: boolean }> = [];
  for (const collection of COLLECTIONS) {
    const ops = plan.ops.filter((o) => o.collection === collection);
    if (!ops.length) continue;
    const existing = await db.getExisting(collection, ops.map((o) => o.id));
    for (const op of ops) {
      const remote = existing.get(op.id);
      const data = { ...op.data };
      if (remote) {
        for (const f of op.preserve_on_update) delete data[f];
        if (op.guard === 'published_variant' && remote.status === 'published') {
          report.skipped_published.push(op.id);
          continue;
        }
        if (op.guard === 'review') {
          const localReview = data.review as { status: string } | undefined;
          const remoteReview = remote.review as { status?: string } | undefined;
          const rStatus = remoteReview?.status;
          if (localReview && rStatus && rStatus !== localReview.status && (rStatus === 'rejected' || rankOf(rStatus) > rankOf(localReview.status))) {
            report.review_conflicts.push({ id: op.id, local: localReview.status, remote: rStatus });
            delete data.review;
          }
          if (remote.content_hash === data.content_hash && (data.review === undefined || (remoteReview?.status === localReview?.status))) {
            report.unchanged++;
            continue;
          }
        }
      }
      final.push({ collection: op.collection, id: op.id, data, merge: MERGE[op.collection] });
    }
  }
  for (let i = 0; i < final.length; i += batchSize) {
    const chunk = final.slice(i, i + batchSize);
    await db.commitBatch(chunk);
    report.written += chunk.length;
    report.batches++;
  }
  return report;
}
