/**
 * Firestore adapters for the fresh variant per attempt (ARCHITECTURE §10.1):
 * the bundled topic matrices, config/exam_pool, the eligible pool of a
 * blueprint × language, the user's seen questions, and adminUpdateExamPool /
 * adminExamPoolHealth.
 *
 * Pool = exam_questions of the language and the blueprint slot
 * (section_id, part_id; a `blueprint_id` on the document must match), review
 * status at least config/exam_pool.min_review_status, with an answer key
 * (exam_question_keys.correct) and, for passage questions, an exam_passages
 * document. One query per slot (language, section_id, part_id,
 * review.status in [...]) with a field mask; keys and passages are read with
 * field masks too. The eligible pool is cached per instance for 2 minutes
 * (not in the emulator).
 */
import '../config';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import type { DocumentReference } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';
import { poolHealth, statusesAtLeast, type PoolItem, type PoolPassage } from '../domain/assembly';
import { matrixProblems, parseBlueprintMatrix, partMatricesFor, type PartMatrix } from '../domain/exam_matrix';
import {
  assemblySections,
  lastSeenMap,
  parseExamPoolConfig,
  parseExamPoolUpdate,
  passageLayoutOf,
  poolItemFromDoc,
  POOL_FIELDS,
  SEEN_ATTEMPTS_WINDOW,
  type ExamPoolConfig,
} from '../domain/exam_pool';
import { DomainError, Reasons } from '../domain/reasons';
import { isRecord, strList, type Blueprint } from '../domain/types';
import { adminCallableOptions, chunk, db, FieldValue, payload, reqId, requirePermission, tsToMs, wrap, writeAdminLog } from './common';
import { loadBlueprint } from './content';

const IN_EMULATOR = process.env['FUNCTIONS_EMULATOR'] === 'true';
const POOL_CACHE_TTL_MS = 2 * 60_000;
const SLOT_LIMIT = 5000;

// ---------------------------------------------------------------------------
// Matrices (copied from content/matrix by scripts/copy-assets.mjs)

const matrixCache = new Map<string, ReturnType<typeof parseBlueprintMatrix>>();

function readMatrixFile(blueprintId: string): unknown {
  const candidates = [
    path.join(__dirname, '..', 'data', 'matrix', `${blueprintId}.json`),
    path.join(__dirname, '..', '..', '..', 'content', 'matrix', `${blueprintId}.json`),
  ];
  for (const file of candidates) {
    try {
      return JSON.parse(readFileSync(file, 'utf8'));
    } catch {
      // next candidate
    }
  }
  return null;
}

/**
 * Part matrices of the blueprint in `language`, checked against the
 * blueprint's structure; VARIANT_NOT_AVAILABLE (`why: matrix_missing`) when
 * there is none that fits.
 */
export function requireMatrix(bp: Blueprint, language: string): Map<string, PartMatrix> {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(bp.id)) throw new DomainError(Reasons.VARIANT_NOT_AVAILABLE, 'invalid blueprint id');
  if (!matrixCache.has(bp.id)) matrixCache.set(bp.id, parseBlueprintMatrix(readMatrixFile(bp.id)));
  const matrix = matrixCache.get(bp.id) ?? null;
  const parts = matrix ? partMatricesFor(matrix, language) : null;
  const problems = parts ? matrixProblems(parts, assemblySections(bp)) : ['no matrix'];
  if (!parts || problems.length > 0) {
    logger.error('topic matrix unusable', { blueprintId: bp.id, language, problems: problems.slice(0, 5) });
    throw new DomainError(Reasons.VARIANT_NOT_AVAILABLE, 'no topic matrix for this blueprint', { why: 'matrix_missing' });
  }
  if (matrix && matrix.blueprint_version !== bp.version) {
    logger.warn('topic matrix version differs from the blueprint (structure matches)', { blueprintId: bp.id, matrix: matrix.blueprint_version, blueprint: bp.version });
  }
  return parts;
}

// ---------------------------------------------------------------------------
// config/exam_pool

export async function readExamPoolConfig(): Promise<ExamPoolConfig> {
  return parseExamPoolConfig((await db().doc('config/exam_pool').get()).data());
}

// ---------------------------------------------------------------------------
// Pool

export interface SlotDocs {
  section_id: string;
  part_id: string;
  /** Usable documents of the slot (any review status except rejected). */
  items: PoolItem[];
}

async function existingWithMask(collection: string, ids: readonly string[], fields: string[]): Promise<Map<string, Record<string, unknown>>> {
  const out = new Map<string, Record<string, unknown>>();
  const refs: DocumentReference[] = [...new Set(ids)].map((id) => db().collection(collection).doc(id));
  for (const part of chunk(refs, 300)) {
    if (part.length === 0) continue;
    const snaps = await db().getAll(...part, { fieldMask: fields });
    for (const s of snaps) if (s.exists) out.set(s.id, s.data() ?? {});
  }
  return out;
}

/** Questions of every slot of the blueprint in `language` (statuses = null: all). */
export async function loadSlotDocs(bp: Blueprint, language: string, statuses: readonly string[] | null): Promise<SlotDocs[]> {
  const slots = bp.sections.flatMap((s) => s.parts.map((p) => ({ section_id: s.id, part_id: p.id })));
  return Promise.all(
    slots.map(async (slot) => {
      let q = db()
        .collection('exam_questions')
        .where('language', '==', language)
        .where('section_id', '==', slot.section_id)
        .where('part_id', '==', slot.part_id);
      if (statuses) q = q.where('review.status', 'in', [...statuses]);
      const snap = await q.select(...POOL_FIELDS).limit(SLOT_LIMIT).get();
      if (snap.size >= SLOT_LIMIT) logger.warn('pool slot truncated', { blueprintId: bp.id, ...slot, limit: SLOT_LIMIT });
      const items = snap.docs.map((d) => poolItemFromDoc(d.id, d.data(), bp.id)).filter((x): x is PoolItem => x !== null);
      return { ...slot, items };
    }),
  );
}

export interface EligiblePool {
  items: PoolItem[];
  passages: Map<string, PoolPassage>;
}

/** Drops items without a key (or, for passage questions, without the passage). */
export async function eligibleFrom(items: readonly PoolItem[]): Promise<EligiblePool> {
  const keys = await existingWithMask('exam_question_keys', items.map((i) => i.id), ['correct']);
  const keyed = items.filter((i) => {
    const c = keys.get(i.id)?.['correct'];
    return typeof c === 'string' && c.trim().length > 0;
  });
  const passageIds = keyed.map((i) => i.passage_id).filter((p): p is string => !!p);
  const passageDocs = await existingWithMask('exam_passages', passageIds, ['layout']);
  const passages = new Map<string, PoolPassage>();
  for (const [id, data] of passageDocs) passages.set(id, { id, layout: passageLayoutOf(data) });
  return { items: keyed.filter((i) => !i.passage_id || passages.has(i.passage_id)), passages };
}

const poolCache = new Map<string, { at: number; value: EligiblePool }>();

/** Eligible pool of a blueprint × language for the configured review floor. */
export async function loadEligiblePool(bp: Blueprint, language: string, minStatus: string): Promise<EligiblePool> {
  const key = `${bp.id}|${bp.version}|${language}|${minStatus}`;
  const hit = poolCache.get(key);
  if (!IN_EMULATOR && hit && Date.now() - hit.at < POOL_CACHE_TTL_MS) return hit.value;
  const slots = await loadSlotDocs(bp, language, statusesAtLeast(minStatus));
  const value = await eligibleFrom(slots.flatMap((s) => s.items));
  if (!IN_EMULATOR) {
    if (poolCache.size > 40) poolCache.clear();
    poolCache.set(key, { at: Date.now(), value });
  }
  return value;
}

/**
 * question_ids of the user's last 50 attempts of the blueprint + language
 * (any status) -> time of the most recent attempt containing each.
 */
export async function loadLastSeen(uid: string, blueprintId: string, language: string): Promise<Map<string, number>> {
  const snap = await db()
    .collection('exam_attempts')
    .where('uid', '==', uid)
    .where('blueprint_id', '==', blueprintId)
    .where('language', '==', language)
    .orderBy('started_at', 'desc')
    .limit(SEEN_ATTEMPTS_WINDOW)
    .select('sections', 'started_at')
    .get();
  return lastSeenMap(
    snap.docs.map((d) => {
      const sections = d.get('sections');
      return {
        started_at: tsToMs(d.get('started_at')) ?? 0,
        question_ids: Array.isArray(sections) ? sections.filter(isRecord).flatMap((s) => strList(s['question_ids'])) : [],
      };
    }),
  );
}

// ---------------------------------------------------------------------------
// adminUpdateExamPool {freshEnabled?, minReviewStatus?} -> {ok, freshEnabled, minReviewStatus}

export const adminUpdateExamPool = onCall(
  adminCallableOptions(),
  wrap('adminUpdateExamPool', async (req) => {
    // super_admin only (manage_pricing: what a paid mock exam is made of).
    const actor = await requirePermission(req, 'manage_pricing');
    const update = parseExamPoolUpdate(payload(req));
    const ref = db().doc('config/exam_pool');
    const before = parseExamPoolConfig((await ref.get()).data());
    const after: ExamPoolConfig = { ...before, ...update };
    await ref.set({ ...after, updated_at: FieldValue.serverTimestamp(), updated_by: actor.uid }, { merge: true });
    await writeAdminLog(actor, 'update_exam_pool', { doc: 'config/exam_pool' }, { before, after });
    return { ok: true, freshEnabled: after.fresh_enabled, minReviewStatus: after.min_review_status };
  }),
);

// ---------------------------------------------------------------------------
// adminExamPoolHealth {blueprintId, language} -> {sections, disjoint_variants, shortfalls, ...}

export const adminExamPoolHealth = onCall(
  adminCallableOptions({ timeoutSeconds: 120, memory: '512MiB' }),
  wrap('adminExamPoolHealth', async (req) => {
    // super_admin, content_manager, methodologist (edit_questions).
    await requirePermission(req, 'edit_questions');
    const data = payload(req);
    const blueprintId = reqId(data['blueprintId'], 'blueprintId');
    const language = data['language'];
    if (typeof language !== 'string' || !/^[a-z]{2}$/.test(language)) {
      throw new DomainError(Reasons.VALIDATION_FAILED, 'language is invalid', { field: 'language' });
    }
    const bp = await loadBlueprint(blueprintId);
    if (!bp) throw new DomainError(Reasons.VALIDATION_FAILED, 'unknown blueprint', { field: 'blueprintId' });
    if (bp.languages.length > 0 && !bp.languages.includes(language)) {
      throw new DomainError(Reasons.VALIDATION_FAILED, `blueprint ${bp.id} has no ${language} version`, { field: 'language', languages: bp.languages });
    }
    const config = await readExamPoolConfig();
    const matrix = requireMatrix(bp, language);
    const floor = statusesAtLeast(config.min_review_status);
    const slots = await loadSlotDocs(bp, language, null);
    const eligible = await eligibleFrom(slots.flatMap((s) => s.items).filter((i) => floor.includes(i.review_status as (typeof floor)[number])));
    const health = poolHealth({ sections: assemblySections(bp), matrix, pool: eligible.items, passages: eligible.passages, maxVariants: 100 });
    const eligibleCount = new Map<string, number>();
    for (const it of eligible.items) {
      const pm = matrix.get(`${it.section_id}/${it.part_id}`);
      if (!pm || !pm.topics.some((t) => t.topic_id === it.topic_id)) continue;
      const k = `${it.section_id}/${it.part_id}`;
      eligibleCount.set(k, (eligibleCount.get(k) ?? 0) + 1);
    }
    const sections = bp.sections.map((s) => ({
      section_id: s.id,
      parts: s.parts.map((p) => {
        const k = `${s.id}/${p.id}`;
        const docs = slots.find((x) => x.section_id === s.id && x.part_id === p.id)?.items ?? [];
        const byStatus = { methodologist_approved: 0, ai_verified: 0, draft: 0 };
        for (const d of docs) if (d.review_status in byStatus) byStatus[d.review_status as keyof typeof byStatus]++;
        const ph = health.parts.find((x) => x.section_id === s.id && x.part_id === p.id);
        return {
          part_id: p.id,
          needed: p.question_count,
          available_by_status: byStatus,
          eligible: eligibleCount.get(k) ?? 0,
          passages: ph?.passages ?? { standalone: 0, paired: 0, unknown: 0 },
          disjoint_variants: ph?.disjoint ?? 0,
        };
      }),
    }));
    return {
      blueprintId: bp.id,
      language,
      freshEnabled: config.fresh_enabled,
      minReviewStatus: config.min_review_status,
      sections,
      disjoint_variants: health.disjoint_variants,
      disjoint_variants_capped: health.capped,
      shortfalls: health.shortfalls,
    };
  }),
);
