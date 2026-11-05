/**
 * Topic matrix of a blueprint (content/matrix/{blueprintId}.json, produced
 * by the content pipeline's matrix stage) as the server needs it for the
 * fresh-variant assembly (ARCHITECTURE §10.1): per blueprint × language ×
 * section × part the exact difficulty counts, the passage plan and, per
 * topic, the target, the allowed [min, max] range and the exact topic ×
 * difficulty cells. Parsing is tolerant (unknown fields are ignored); a
 * matrix that does not fit the blueprint's structure is rejected.
 */
import { int, isRecord, str } from './types';

export type DifficultyKey = '1' | '2' | '3';
export type DifficultyCounts = Record<DifficultyKey, number>;
export const DIFFICULTIES = [1, 2, 3] as const;
export type Difficulty = (typeof DIFFICULTIES)[number];

export const dkey = (d: number): DifficultyKey => String(d) as DifficultyKey;
export const zeroCounts = (): DifficultyCounts => ({ '1': 0, '2': 0, '3': 0 });

export interface MatrixTopic {
  topic_id: string;
  target: number;
  min: number;
  max: number;
  difficulty_targets: DifficultyCounts;
}

export interface MatrixPassagePlan {
  standalone_texts: number;
  paired_texts: number;
  questions_per_text: number;
}

export interface PartMatrix {
  /** `${blueprintId}/${sectionId}/${partId}` (as in the pipeline). */
  slot: string;
  section_id: string;
  part_id: string;
  question_count: number;
  difficulty_counts: DifficultyCounts;
  passage_plan: MatrixPassagePlan | null;
  topics: MatrixTopic[];
}

export interface LanguageMatrix {
  language: string;
  parts: PartMatrix[];
}

export interface BlueprintMatrix {
  blueprint_id: string;
  blueprint_version: number;
  languages: LanguageMatrix[];
}

/** Section/part structure the assembly needs from a blueprint (in blueprint order). */
export interface AssemblySection {
  id: string;
  question_count: number;
  parts: Array<{ id: string; question_count: number }>;
}

export const slotKey = (sectionId: string, partId: string): string => `${sectionId}/${partId}`;

function counts(raw: unknown): DifficultyCounts {
  const r = isRecord(raw) ? raw : {};
  return { '1': Math.max(0, int(r['1'])), '2': Math.max(0, int(r['2'])), '3': Math.max(0, int(r['3'])) };
}

function parsePlan(raw: unknown): MatrixPassagePlan | null {
  if (!isRecord(raw)) return null;
  const plan = {
    standalone_texts: Math.max(0, int(raw['standalone_texts'])),
    paired_texts: Math.max(0, int(raw['paired_texts'])),
    questions_per_text: Math.max(1, int(raw['questions_per_text'], 1)),
  };
  return plan.standalone_texts + plan.paired_texts > 0 ? plan : null;
}

function parsePart(raw: unknown): PartMatrix | null {
  if (!isRecord(raw)) return null;
  const sectionId = str(raw['section_id']);
  const partId = str(raw['part_id']);
  if (!sectionId || !partId) return null;
  const topics = (Array.isArray(raw['topics']) ? raw['topics'] : [])
    .filter(isRecord)
    .map((t) => ({
      topic_id: str(t['topic_id']),
      target: Math.max(0, int(t['target'])),
      min: Math.max(0, int(t['min'])),
      max: Math.max(0, int(t['max'])),
      difficulty_targets: counts(t['difficulty_targets']),
    }))
    .filter((t) => t.topic_id.length > 0);
  return {
    slot: str(raw['slot'], slotKey(sectionId, partId)),
    section_id: sectionId,
    part_id: partId,
    question_count: Math.max(0, int(raw['question_count'])),
    difficulty_counts: counts(raw['difficulty_counts']),
    passage_plan: parsePlan(raw['passage_plan']),
    topics,
  };
}

/** content/matrix/{id}.json -> BlueprintMatrix, or null when it is not a matrix file. */
export function parseBlueprintMatrix(raw: unknown): BlueprintMatrix | null {
  if (!isRecord(raw) || typeof raw['blueprint_id'] !== 'string' || !Array.isArray(raw['languages'])) return null;
  const languages: LanguageMatrix[] = raw['languages'].filter(isRecord).map((l) => ({
    language: str(l['language']),
    parts: (Array.isArray(l['sections']) ? l['sections'] : [])
      .filter(isRecord)
      .flatMap((s) => (Array.isArray(s['parts']) ? s['parts'] : []))
      .map(parsePart)
      .filter((p): p is PartMatrix => p !== null),
  }));
  return { blueprint_id: raw['blueprint_id'], blueprint_version: int(raw['blueprint_version'], 1), languages };
}

/** Part matrices of one language keyed by `section/part`, or null when the language is missing. */
export function partMatricesFor(m: BlueprintMatrix, language: string): Map<string, PartMatrix> | null {
  const lm = m.languages.find((l) => l.language === language);
  if (!lm) return null;
  return new Map(lm.parts.map((p) => [slotKey(p.section_id, p.part_id), p]));
}

/**
 * Problems that make the matrix unusable for the blueprint: a part missing
 * from the matrix, a different question count, inconsistent difficulty
 * counts or topic targets. Empty = the matrix fits (its version number may
 * differ: a blueprint edit that keeps the structure keeps the matrix valid).
 */
export function matrixProblems(parts: ReadonlyMap<string, PartMatrix>, sections: readonly AssemblySection[]): string[] {
  const problems: string[] = [];
  for (const s of sections) {
    for (const p of s.parts) {
      const pm = parts.get(slotKey(s.id, p.id));
      if (!pm) {
        problems.push(`${s.id}/${p.id}: missing from the matrix`);
        continue;
      }
      if (pm.question_count !== p.question_count) problems.push(`${s.id}/${p.id}: matrix has ${pm.question_count} questions, blueprint ${p.question_count}`);
      const dc = pm.difficulty_counts;
      if (dc['1'] + dc['2'] + dc['3'] !== pm.question_count) problems.push(`${s.id}/${p.id}: difficulty counts do not add up`);
      if (pm.topics.length === 0) problems.push(`${s.id}/${p.id}: no topics`);
      const targets = pm.topics.reduce((a, t) => a + t.target, 0);
      if (pm.topics.length > 0 && targets !== pm.question_count) problems.push(`${s.id}/${p.id}: topic targets add up to ${targets}`);
    }
  }
  return problems;
}
