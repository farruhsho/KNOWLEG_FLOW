/**
 * Stage 8 — import into Firestore. `buildImportPlan` is pure: it turns
 * blueprints, bank items, passages and variants into an ordered list of
 * upserts with deterministic, content-hash-based ids, in batches of ≤ 400.
 * It never emits deletes. `commitPlan` reads every target document first and
 * then applies the plan through a small FirestorePort (firebase-admin adapter
 * in firestore.ts), enforcing the guards that need the live documents:
 *   - a published or archived variant is never modified, and the status of a
 *     variant that already exists in Firestore is never changed (publishing or
 *     unpublishing an existing variant is adminPublishVariant's job);
 *   - a question, key, passage or draft variant edited outside the pipeline
 *     (admin panel, console) is not overwritten unless `overwrite` is set; it
 *     is reported as a cms_conflict. A question and its key are one unit;
 *   - an existing question keeps its review if the remote one is further
 *     along (a methodologist approved it in the admin panel) or rejected;
 *   - server-maintained fields (variant stats, created_at) are not reset.
 *
 * Storage shape: Firestore cannot hold an array directly inside an array, so
 * `table.rows` (string[][] in the bank and in every stage) is stored as
 * `[{cells: string[]}]` (`toStoredTable`). Cloud Functions turn it back into
 * `rows: string[][]` in callable responses.
 */
import { passageContentHash, questionContentHash } from './bank';
import { canonicalJson, sha256Hex } from './io';
import { BankItem, BankPassage, ExamPassage, ExamQuestion, QuestionTable, REVIEW_RANK, ReviewStatus, VariantFile, VariantStatus } from './schema';
import { hasErrors, Problem, validateVariant, ValidationContext } from './validate';

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

// ---------------------------------------------------------------------------
// Storage shapes
// ---------------------------------------------------------------------------

/** `exam_questions.table` as stored in Firestore (no array inside an array). */
export interface StoredQuestionTable {
  headers: string[];
  rows: Array<{ cells: string[] }>;
}

export function toStoredTable(t: QuestionTable | null): StoredQuestionTable | null {
  return t === null ? null : { headers: [...t.headers], rows: t.rows.map((cells) => ({ cells: [...cells] })) };
}

/** Stored (`rows[i].cells`) or wire (`rows[i]` is a list) table → the bank shape. */
export function fromStoredTable(v: unknown): QuestionTable | null {
  if (!v || typeof v !== 'object') return null;
  const o = v as { headers?: unknown; rows?: unknown };
  const strings = (x: unknown): string[] => (Array.isArray(x) ? x.map((c) => (typeof c === 'string' ? c : String(c))) : []);
  const rows = Array.isArray(o.rows)
    ? o.rows.map((r) => (Array.isArray(r) ? strings(r) : r && typeof r === 'object' ? strings((r as { cells?: unknown }).cells) : []))
    : [];
  return { headers: strings(o.headers), rows };
}

/** Paths of arrays that sit directly inside arrays — values Firestore rejects at commit time. */
export function nestedArrayPaths(v: unknown, path = '$'): string[] {
  if (Array.isArray(v)) return v.flatMap((x, i) => (Array.isArray(x) ? [`${path}[${i}]`] : nestedArrayPaths(x, `${path}[${i}]`)));
  if (v && typeof v === 'object') return Object.entries(v as Record<string, unknown>).flatMap(([k, x]) => nestedArrayPaths(x, `${path}.${k}`));
  return [];
}

/** exam_questions document: the public fields of ARCHITECTURE §1.3 plus `part_id` and `pipeline_hash`. */
export function questionDoc(item: BankItem): Record<string, unknown> {
  const q = item.question;
  return {
    subject_id: q.subject_id,
    section_id: q.section_id,
    // Blueprint part the item was written for: the admin variant builder and
    // the server's variant validation group questions by it.
    part_id: item.target.part_id,
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
    table: toStoredTable(q.table),
    source: { ...q.source },
    review: { status: q.review.status, reviewed_by: q.review.reviewed_by, reviewed_at: ts(q.review.reviewed_at), notes: q.review.notes },
    content_version: q.content_version,
    content_hash: q.content_hash,
    // The content_hash this pipeline wrote; a different remote content_hash means someone else edited the document.
    pipeline_hash: q.content_hash,
    created_at: ts(q.created_at),
    updated_at: ts(q.updated_at),
  };
}

/** Hash of the four key fields (what the pipeline wrote is stored as `pipeline_hash`). */
export function keyHash(k: Record<string, unknown>): string {
  const pick = { correct: k.correct ?? null, explanation: k.explanation ?? null, wrong_option_notes: k.wrong_option_notes ?? null, solution_steps: k.solution_steps ?? null };
  return 'sha256:' + sha256Hex(canonicalJson(pick));
}

export function keyDoc(item: BankItem): Record<string, unknown> {
  const doc: Record<string, unknown> = {
    correct: item.key.correct,
    explanation: item.key.explanation,
    wrong_option_notes: { ...item.key.wrong_option_notes },
    solution_steps: [...item.key.solution_steps],
  };
  doc.pipeline_hash = keyHash(doc);
  return doc;
}

export function passageDoc(p: BankPassage): Record<string, unknown> {
  const x = p.passage;
  return {
    language: x.language,
    subject_id: x.subject_id,
    section_id: x.section_id,
    title: x.title,
    text: x.text,
    source: { ...x.source },
    content_hash: p.content_hash,
    pipeline_hash: p.content_hash,
  };
}

const VARIANT_CONTENT_FIELDS = ['blueprint_id', 'blueprint_version', 'number', 'title', 'language', 'sections', 'content_version', 'difficulty_label'] as const;

/** Hash of the variant fields the pipeline owns (status, stats and publication are not part of it). */
export function variantHash(v: Record<string, unknown>): string {
  return 'sha256:' + sha256Hex(canonicalJson(Object.fromEntries(VARIANT_CONTENT_FIELDS.map((f) => [f, v[f] ?? null]))));
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
        note = 'published if new in Firestore; an existing variant keeps its status (publish it in the admin panel)';
      }
    } else if (f.variant.status === 'published') {
      note = 'local file says published; written as draft only if absent in Firestore (the status of an existing variant is never changed)';
    }
    for (const s of f.variant.sections) for (const id of s.question_ids) itemIds.add(id);
    const v = f.variant;
    const data: Record<string, unknown> = {
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
    };
    data.pipeline_hash = variantHash(data);
    variantOps.push({
      collection: 'exam_variants',
      id: f.id,
      data,
      // Status and publication of an existing variant belong to adminPublishVariant.
      preserve_on_update: ['stats', 'created_by', 'status', 'published_at', 'published_by'],
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
  const unstorable = ops.flatMap((o) => nestedArrayPaths(o.data).map((p) => `${o.collection}/${o.id} ${p}`));
  if (unstorable.length) {
    throw new Error(`Firestore cannot store an array inside an array: ${unstorable.slice(0, 5).join('; ')}${unstorable.length > 5 ? ` (+${unstorable.length - 5} more)` : ''}`);
  }
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
// Edits made outside the pipeline
// ---------------------------------------------------------------------------

const isSet = (v: unknown): boolean => v !== undefined && v !== null;
const str = (v: unknown): string | null => (typeof v === 'string' ? v : null);

/** questionContentHash recomputed from a stored exam_questions document. */
export function remoteQuestionHash(doc: Record<string, unknown>): string {
  return questionContentHash({
    language: doc.language as ExamQuestion['language'],
    type: doc.type as ExamQuestion['type'],
    stem: doc.stem as string,
    options: (Array.isArray(doc.options) ? doc.options : []) as ExamQuestion['options'],
    table: fromStoredTable(doc.table),
    image_path: str(doc.image_path),
    passage_id: str(doc.passage_id),
  });
}

/**
 * Why a remote document no longer holds what the pipeline wrote (null = it
 * does). `data` is the document the plan would write now.
 */
export function editedOutsideReason(collection: CollectionName, data: Record<string, unknown>, remote: Record<string, unknown>): string | null {
  if (isSet(remote.edited_in_cms_at)) return 'edited in the admin panel (edited_in_cms_at is set)';
  switch (collection) {
    case 'exam_questions': {
      const expected = str(remote.pipeline_hash) ?? String(data.content_hash);
      if (remote.content_hash !== expected) return `content_hash ${String(remote.content_hash ?? 'missing')} ≠ ${expected} written by the pipeline`;
      if (remoteQuestionHash(remote) !== expected) return 'stem/options/table/image/passage changed outside the pipeline';
      return null;
    }
    case 'exam_question_keys': {
      if (isSet(remote.updated_by)) return `saved in the admin panel by ${String(remote.updated_by)}`;
      const expected = str(remote.pipeline_hash);
      if (expected !== null && keyHash(remote) !== expected) return 'key changed outside the pipeline';
      return null;
    }
    case 'exam_passages': {
      if (isSet(remote.updated_by)) return `saved in the admin panel by ${String(remote.updated_by)}`;
      const expected = str(remote.pipeline_hash) ?? String(data.content_hash);
      if (isSet(remote.content_hash) && remote.content_hash !== expected) return `content_hash ${String(remote.content_hash)} ≠ ${expected} written by the pipeline`;
      const recomputed = passageContentHash({ language: remote.language as ExamPassage['language'], title: remote.title as string, text: remote.text as string });
      if (recomputed !== expected) return 'passage title/text changed outside the pipeline';
      return null;
    }
    case 'exam_variants': {
      const expected = str(remote.pipeline_hash);
      if (expected !== null) return variantHash(remote) !== expected ? 'variant content changed outside the pipeline' : null;
      return isSet(remote.updated_by) ? `saved in the admin panel by ${String(remote.updated_by)}` : null;
    }
    case 'exam_blueprints':
      return null;
  }
}

/** Fields ignored when deciding whether an edited remote document already matches the bank. */
const SYNC_IGNORE: Record<CollectionName, readonly string[]> = {
  exam_blueprints: [],
  exam_passages: ['content_hash', 'pipeline_hash'],
  exam_questions: ['pipeline_hash', 'review', 'created_at', 'updated_at', 'content_version', 'edited_in_cms_at'],
  exam_question_keys: ['pipeline_hash'],
  exam_variants: ['pipeline_hash', 'status', 'published_at', 'published_by', 'stats', 'created_by', 'edited_in_cms_at'],
};

/**
 * A conflict is a document edited outside the pipeline whose content differs
 * from the bank: writing would revert the edit. An edited document that
 * already matches the bank (the edit was ported into git) is not a conflict.
 */
export function conflictReason(collection: CollectionName, data: Record<string, unknown>, remote: Record<string, unknown>): string | null {
  const reason = editedOutsideReason(collection, data, remote);
  if (reason === null) return null;
  const ignore = SYNC_IGNORE[collection];
  const inSync = Object.keys(data).every((k) => ignore.includes(k) || data[k] === undefined || sameValue(data[k], remote[k]));
  return inSync ? null : reason;
}

function isServerTs(v: unknown): boolean {
  return !!v && typeof v === 'object' && (v as { __server_timestamp?: unknown }).__server_timestamp === true;
}

function tsMillis(v: unknown): number | null {
  if (v && typeof v === 'object') {
    const o = v as { toDate?: () => Date; __timestamp?: unknown };
    if (typeof o.toDate === 'function') return o.toDate().getTime();
    if (typeof o.__timestamp === 'string') return Date.parse(o.__timestamp);
  }
  return null;
}

/** Deep equality of a planned value and a stored one (timestamps compared by instant; a server timestamp never matches). */
export function sameValue(a: unknown, b: unknown): boolean {
  if (isServerTs(a) || isServerTs(b)) return false;
  const ta = tsMillis(a);
  const tb = tsMillis(b);
  if (ta !== null || tb !== null) return ta === tb;
  if (Array.isArray(a) || Array.isArray(b)) {
    return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((x, i) => sameValue(x, b[i]));
  }
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    const ra = a as Record<string, unknown>;
    const rb = b as Record<string, unknown>;
    const ka = Object.keys(ra).filter((k) => ra[k] !== undefined);
    const kb = Object.keys(rb).filter((k) => rb[k] !== undefined);
    return ka.length === kb.length && ka.every((k) => k in rb && sameValue(ra[k], rb[k]));
  }
  return a === b;
}

/** True when writing `data` would not change the stored document. */
function unchangedRemote(data: Record<string, unknown>, remote: Record<string, unknown>, merge: boolean): boolean {
  const keys = Object.keys(data).filter((k) => data[k] !== undefined);
  if (!keys.every((k) => k in remote && sameValue(data[k], remote[k]))) return false;
  return merge || Object.keys(remote).filter((k) => remote[k] !== undefined).length === keys.length;
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

export interface CommitOptions {
  batchSize?: number;
  /** Overwrite documents edited outside the pipeline (never published/archived variants, never a variant's status). */
  overwrite?: boolean;
}

export interface CommitReport {
  written: number;
  unchanged: number;
  batches: number;
  skipped_published: string[];
  /** Variants unpublished in the admin panel: never written again. */
  skipped_archived: string[];
  /** Variants created in Firestore with status `published`. */
  published: string[];
  /** `--publish` for a variant that already exists in Firestore: its status is not changed here — publish it in the admin panel. */
  publish_in_admin: string[];
  /** New variants written as drafts because some of their questions differ in Firestore. */
  publish_blocked: Array<{ id: string; reason: string }>;
  review_conflicts: Array<{ id: string; local: string; remote: string }>;
  /** Documents edited outside the pipeline and left as they are. */
  cms_conflicts: Array<{ collection: CollectionName; id: string; reason: string }>;
  /** Documents edited outside the pipeline and overwritten (`overwrite`). */
  overwritten: Array<{ collection: CollectionName; id: string; reason: string }>;
}

/**
 * Questions and variants are merged (server-maintained fields survive);
 * blueprints, passages and keys are pipeline-owned and overwritten whole
 * unless they were edited outside the pipeline (then they are skipped and
 * reported, see commitPlan).
 */
export const MERGE: Record<CollectionName, boolean> = {
  exam_blueprints: false,
  exam_passages: false,
  exam_questions: true,
  exam_question_keys: false,
  exam_variants: true,
};

const rankOf = (s: unknown): number => (typeof s === 'string' && s in REVIEW_RANK ? REVIEW_RANK[s as ReviewStatus] : 0);
const docKey = (collection: CollectionName, id: string): string => `${collection}/${id}`;

export async function commitPlan(plan: ImportPlan, db: FirestorePort, options: number | CommitOptions = {}): Promise<CommitReport> {
  const opts: CommitOptions = typeof options === 'number' ? { batchSize: options } : options;
  const batchSize = opts.batchSize ?? MAX_BATCH;
  if (batchSize < 1 || batchSize > MAX_BATCH) throw new Error(`batch size must be 1..${MAX_BATCH}`);
  const report: CommitReport = {
    written: 0, unchanged: 0, batches: 0, skipped_published: [], skipped_archived: [], published: [], publish_in_admin: [],
    publish_blocked: [], review_conflicts: [], cms_conflicts: [], overwritten: [],
  };

  // 1. Read every target document before writing anything.
  const existing = new Map<CollectionName, Map<string, Record<string, unknown>>>();
  for (const collection of COLLECTIONS) {
    const ids = plan.ops.filter((o) => o.collection === collection).map((o) => o.id);
    existing.set(collection, ids.length ? await db.getExisting(collection, ids) : new Map());
  }
  const remoteOf = (op: WriteOp): Record<string, unknown> | undefined => existing.get(op.collection)!.get(op.id);
  const frozenVariant = (remote: Record<string, unknown>): boolean => remote.status === 'published' || remote.status === 'archived';

  // 2. Documents edited outside the pipeline. The admin panel saves a question
  //    and its key together, so a conflict on either one holds back both.
  const conflicts = new Map<string, string>();
  for (const op of plan.ops) {
    const remote = remoteOf(op);
    if (!remote || (op.collection === 'exam_variants' && frozenVariant(remote))) continue;
    const reason = conflictReason(op.collection, op.data, remote);
    if (reason) conflicts.set(docKey(op.collection, op.id), reason);
  }
  const paired = new Map<string, string>();
  for (const op of plan.ops) {
    if (op.collection !== 'exam_questions' && op.collection !== 'exam_question_keys') continue;
    const other = op.collection === 'exam_questions' ? 'exam_question_keys' : 'exam_questions';
    const otherReason = conflicts.get(docKey(other, op.id));
    if (otherReason && !conflicts.has(docKey(op.collection, op.id))) {
      paired.set(docKey(op.collection, op.id), `${other === 'exam_questions' ? 'its question' : 'its key'}: ${otherReason}`);
    }
  }
  for (const [k, v] of paired) conflicts.set(k, v);

  // 3. Writes.
  const heldBack = new Set<string>(); // question and passage ids left as edited outside the pipeline
  const remoteRejected = new Set<string>();
  const passageOf = new Map(plan.ops.filter((o) => o.collection === 'exam_questions').map((o) => [o.id, str(o.data.passage_id)]));
  const final: Array<{ collection: CollectionName; id: string; data: Record<string, unknown>; merge: boolean }> = [];
  for (const collection of COLLECTIONS) {
    for (const op of plan.ops.filter((o) => o.collection === collection)) {
      const remote = remoteOf(op);
      const data = { ...op.data };
      const conflict = conflicts.get(docKey(collection, op.id));
      if (conflict) {
        if (!opts.overwrite) {
          report.cms_conflicts.push({ collection, id: op.id, reason: conflict });
          if (collection === 'exam_questions' || collection === 'exam_passages') heldBack.add(op.id);
          continue;
        }
        report.overwritten.push({ collection, id: op.id, reason: conflict });
        if (MERGE[collection] && remote && isSet(remote.edited_in_cms_at)) data.edited_in_cms_at = null;
      }
      if (remote) {
        for (const f of op.preserve_on_update) delete data[f];
        if (op.guard === 'published_variant') {
          if (remote.status === 'published') {
            report.skipped_published.push(op.id);
            continue;
          }
          if (remote.status === 'archived') {
            report.skipped_archived.push(op.id);
            continue;
          }
          if (op.data.status === 'published') report.publish_in_admin.push(op.id);
        }
        if (op.guard === 'review') {
          const localReview = data.review as { status: string } | undefined;
          const rStatus = (remote.review as { status?: unknown } | undefined)?.status;
          if (localReview && typeof rStatus === 'string') {
            if (rStatus === localReview.status) {
              delete data.review; // same decision: keep who made it and when
            } else if (rStatus === 'rejected' || rankOf(rStatus) > rankOf(localReview.status)) {
              report.review_conflicts.push({ id: op.id, local: localReview.status, remote: rStatus });
              if (rStatus === 'rejected') remoteRejected.add(op.id);
              delete data.review;
            }
          }
        }
        if (unchangedRemote(data, remote, MERGE[collection])) {
          report.unchanged++;
          continue;
        }
      } else if (op.guard === 'published_variant' && data.status === 'published') {
        const qids = (data.sections as Array<{ question_ids: string[] }>).flatMap((s) => s.question_ids);
        const edited = qids.filter((id) => heldBack.has(id) || heldBack.has(passageOf.get(id) ?? ''));
        const rejected = qids.filter((id) => remoteRejected.has(id));
        if (edited.length || rejected.length) {
          data.status = 'draft';
          data.published_at = null;
          data.published_by = null;
          const why = [edited.length ? `${edited.length} question(s) or their passages edited outside the pipeline (${edited.slice(0, 3).join(', ')})` : '', rejected.length ? `${rejected.length} question(s) rejected in Firestore (${rejected.slice(0, 3).join(', ')})` : '']
            .filter(Boolean)
            .join('; ');
          report.publish_blocked.push({ id: op.id, reason: why });
        } else {
          report.published.push(op.id);
        }
      }
      final.push({ collection, id: op.id, data, merge: MERGE[collection] });
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

// ---------------------------------------------------------------------------
// review-sync: decisions made in the admin panel → local bank
// ---------------------------------------------------------------------------

export interface RemoteReviewUpdate {
  id: string;
  from: ReviewStatus;
  to: ReviewStatus;
  reviewed_by: string | null;
}

export interface ReviewSyncResult {
  updates: RemoteReviewUpdate[];
  /** Items whose Firestore question or key was edited outside the pipeline: their review is not pulled. */
  cms_conflicts: Array<{ id: string; reason: string }>;
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
 * than the local one, or a rejection — and only for the same content: same
 * content_hash, no edit outside the pipeline of the question or (when
 * `remoteKeys` is given) of its key. Never touches Firestore.
 */
export function applyRemoteReviews(
  items: BankItem[],
  remote: Map<string, Record<string, unknown>>,
  now: string,
  remoteKeys?: Map<string, Record<string, unknown>>,
): ReviewSyncResult {
  const updates: RemoteReviewUpdate[] = [];
  const cmsConflicts: ReviewSyncResult['cms_conflicts'] = [];
  for (const it of items) {
    const doc = remote.get(it.id);
    if (!doc) continue;
    const qConflict = conflictReason('exam_questions', questionDoc(it), doc);
    const keyRemote = remoteKeys?.get(it.id);
    const kConflict = keyRemote ? conflictReason('exam_question_keys', keyDoc(it), keyRemote) : null;
    if (qConflict || kConflict) {
      cmsConflicts.push({ id: it.id, reason: qConflict ?? `key: ${kConflict}` });
      continue;
    }
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
  return { updates, cms_conflicts: cmsConflicts };
}

export interface RemoteVariantUpdate {
  id: string;
  from: VariantStatus;
  to: VariantStatus;
}

/**
 * Pulls variant statuses set in the admin panel (adminPublishVariant) into the
 * local variant files (in place), so validate, assemble and registry see them:
 * `archived` always wins (the variant was withdrawn); `published` is pulled
 * into a local draft only when the published questions are the local ones.
 */
export function applyRemoteVariantStatuses(
  files: VariantFile[],
  remote: Map<string, Record<string, unknown>>,
  now: string,
): { updates: RemoteVariantUpdate[]; mismatched: string[] } {
  const updates: RemoteVariantUpdate[] = [];
  const mismatched: string[] = [];
  for (const f of files) {
    const doc = remote.get(f.id);
    if (!doc) continue;
    const local = f.variant.status;
    if (doc.status === 'archived' && local !== 'archived') {
      f.variant.status = 'archived';
      updates.push({ id: f.id, from: local, to: 'archived' });
    } else if (doc.status === 'published' && (local === 'draft' || local === 'in_review')) {
      const localSections = f.variant.sections.map((s) => ({ section_id: s.section_id, question_ids: s.question_ids }));
      const remoteSections = Array.isArray(doc.sections)
        ? (doc.sections as Array<Record<string, unknown>>).map((s) => ({ section_id: s.section_id, question_ids: s.question_ids }))
        : null;
      if (!sameValue(localSections, remoteSections)) {
        mismatched.push(f.id);
        continue;
      }
      f.variant.status = 'published';
      f.variant.published_at = isoOf(doc.published_at) ?? now;
      f.variant.published_by = typeof doc.published_by === 'string' ? doc.published_by : null;
      updates.push({ id: f.id, from: local, to: 'published' });
    }
  }
  return { updates, mismatched };
}
