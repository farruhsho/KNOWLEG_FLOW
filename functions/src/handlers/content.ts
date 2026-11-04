/**
 * Firestore adapters for exam content and attempts: blueprint loading (with
 * the bundled assets/data/exam_blueprints.json fallback), batched question /
 * key / passage reads, and AttemptState <-> document conversion.
 */
import { readFileSync } from 'node:fs';
import path from 'node:path';
import type { DocumentReference, DocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import type { AttemptSectionState, AttemptState } from '../domain/exam_session';
import {
  isRecord,
  parseBlueprint,
  parseKey,
  parsePassage,
  parseQuestion,
  parseVariant,
  str,
  strList,
  type Blueprint,
  type ExamQuestion,
  type Passage,
  type QuestionKey,
  type Variant,
} from '../domain/types';
import { int } from '../domain/types';
import { chunk, db, msToTs, tsToMs } from './common';

const CACHE_TTL_MS = 10 * 60_000;
const blueprintCache = new Map<string, { at: number; value: Blueprint }>();
let bundled: Map<string, unknown> | null = null;

/** Blueprints shipped with the functions build (copied from assets/data). */
export function bundledBlueprints(): Map<string, unknown> {
  if (bundled) return bundled;
  bundled = new Map();
  const candidates = [
    path.join(__dirname, '..', 'data', 'exam_blueprints.json'),
    path.join(__dirname, '..', '..', '..', 'assets', 'data', 'exam_blueprints.json'),
  ];
  for (const file of candidates) {
    try {
      const json: unknown = JSON.parse(readFileSync(file, 'utf8'));
      const list = isRecord(json) && Array.isArray(json['blueprints']) ? json['blueprints'] : Array.isArray(json) ? json : [];
      for (const b of list) if (isRecord(b) && typeof b['id'] === 'string') bundled.set(b['id'], b);
      if (bundled.size > 0) break;
    } catch {
      // try next candidate
    }
  }
  return bundled;
}

/** exam_blueprints/{id} from Firestore, else the bundled copy; cached 10 min. */
export async function loadBlueprint(id: string): Promise<Blueprint | null> {
  const hit = blueprintCache.get(id);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) return hit.value;
  let raw: unknown = null;
  try {
    const snap = await db().doc(`exam_blueprints/${id}`).get();
    if (snap.exists) raw = snap.data();
  } catch (e) {
    logger.warn('blueprint read failed, using bundled copy', { id, error: String(e) });
  }
  raw ??= bundledBlueprints().get(id) ?? null;
  if (!raw) return null;
  try {
    const bp = parseBlueprint(id, raw);
    blueprintCache.set(id, { at: Date.now(), value: bp });
    return bp;
  } catch (e) {
    logger.error('invalid blueprint', { id, error: String(e) });
    return null;
  }
}

export async function loadVariant(id: string): Promise<Variant | null> {
  const snap = await db().doc(`exam_variants/${id}`).get();
  return snap.exists ? parseVariant(id, snap.data()) : null;
}

async function getAllDocs(collection: string, ids: readonly string[], tx?: Transaction): Promise<DocumentSnapshot[]> {
  const unique = [...new Set(ids)];
  if (unique.length === 0) return [];
  const refs = unique.map((id) => db().collection(collection).doc(id));
  if (tx) return tx.getAll(...refs);
  const out: DocumentSnapshot[] = [];
  for (const part of chunk(refs, 300)) out.push(...(await db().getAll(...part)));
  return out;
}

export async function loadQuestions(ids: readonly string[], tx?: Transaction): Promise<Map<string, ExamQuestion>> {
  const snaps = await getAllDocs('exam_questions', ids, tx);
  const m = new Map<string, ExamQuestion>();
  for (const s of snaps) if (s.exists) m.set(s.id, parseQuestion(s.id, s.data()));
  return m;
}

export async function loadKeys(ids: readonly string[], tx?: Transaction): Promise<Map<string, QuestionKey>> {
  const snaps = await getAllDocs('exam_question_keys', ids, tx);
  const m = new Map<string, QuestionKey>();
  for (const s of snaps) if (s.exists) m.set(s.id, parseKey(s.data()));
  return m;
}

export async function loadPassages(ids: readonly string[]): Promise<Map<string, Passage>> {
  const snaps = await getAllDocs('exam_passages', ids);
  const m = new Map<string, Passage>();
  for (const s of snaps) if (s.exists) m.set(s.id, parsePassage(s.id, s.data()));
  return m;
}

/** Questions + passages of the attempt's current section (for the payload). */
export async function loadCurrentSectionContent(attempt: AttemptState): Promise<{ questions: Map<string, ExamQuestion>; passages: Map<string, Passage> }> {
  const sec = attempt.status === 'in_progress' ? attempt.sections[attempt.current_section_index] : undefined;
  if (!sec) return { questions: new Map(), passages: new Map() };
  const questions = await loadQuestions(sec.question_ids);
  const passageIds = [...questions.values()].map((q) => q.passage_id).filter((p): p is string => !!p);
  const passages = await loadPassages(passageIds);
  return { questions, passages };
}

// ---------------------------------------------------------------------------
// Attempt document mapping (Timestamps in Firestore, ms in the domain)

export function attemptRef(attemptId: string): DocumentReference {
  return db().collection('exam_attempts').doc(attemptId);
}

export function attemptToDoc(a: AttemptState): Record<string, unknown> {
  return {
    uid: a.uid,
    variant_id: a.variant_id,
    blueprint_id: a.blueprint_id,
    blueprint_version: a.blueprint_version,
    language: a.language,
    status: a.status,
    entitlement_source: a.entitlement_source,
    current_section_index: a.current_section_index,
    current_section_id: a.current_section_id,
    current_deadline_at: msToTs(a.current_deadline_at),
    sections: a.sections.map((s) => ({
      section_id: s.section_id,
      started_at: msToTs(s.started_at),
      deadline_at: msToTs(s.deadline_at),
      submitted_at: msToTs(s.submitted_at),
      late: s.late,
      question_ids: s.question_ids,
    })),
    started_at: msToTs(a.started_at),
    completed_at: msToTs(a.completed_at),
    integrity: { ...a.integrity },
  };
}

export function attemptFromDoc(data: unknown): AttemptState | null {
  if (!isRecord(data)) return null;
  const sections: AttemptSectionState[] = (Array.isArray(data['sections']) ? data['sections'] : [])
    .filter(isRecord)
    .map((s) => ({
      section_id: str(s['section_id']),
      started_at: tsToMs(s['started_at']),
      deadline_at: tsToMs(s['deadline_at']),
      submitted_at: tsToMs(s['submitted_at']),
      late: s['late'] === true,
      question_ids: strList(s['question_ids']),
    }));
  const integrity = isRecord(data['integrity']) ? data['integrity'] : {};
  const status = str(data['status'], 'in_progress');
  return {
    uid: str(data['uid']),
    variant_id: str(data['variant_id']),
    blueprint_id: str(data['blueprint_id']),
    blueprint_version: int(data['blueprint_version'], 1),
    language: str(data['language'], 'ru'),
    status: status === 'completed' || status === 'expired' ? status : 'in_progress',
    entitlement_source: (str(data['entitlement_source'], 'credit') as AttemptState['entitlement_source']),
    current_section_index: int(data['current_section_index']),
    current_section_id: typeof data['current_section_id'] === 'string' ? data['current_section_id'] : null,
    current_deadline_at: tsToMs(data['current_deadline_at']),
    sections,
    started_at: tsToMs(data['started_at']) ?? 0,
    completed_at: tsToMs(data['completed_at']),
    integrity: {
      late_sections: int(integrity['late_sections']),
      client_app_version: str(integrity['client_app_version']),
      expired_by_server: integrity['expired_by_server'] === true,
    },
  };
}
