/**
 * Shapes of the exam content documents (ARCHITECTURE §1.1–1.3) plus tolerant
 * parsers. Parsers never throw on unknown extra fields and fill sensible
 * defaults for missing optional ones, so older/hand-edited documents keep
 * working.
 */

export type LocalizedText = Record<string, string>;

export type ItemType =
  | 'single_choice'
  | 'quantitative_comparison'
  | 'analogy'
  | 'completion'
  | 'text_based';

export interface FixedOption {
  id: string;
  text: LocalizedText;
}

export interface BlueprintPart {
  id: string;
  title: LocalizedText;
  question_count: number;
  options_per_question: number;
  item_type: ItemType;
  verified: boolean;
  fixed_options: FixedOption[] | null;
}

export interface BlueprintSection {
  id: string;
  order: number;
  title: LocalizedText;
  question_count: number;
  duration_minutes: number;
  points_per_question: number;
  subject_area: string | null;
  uses_passages: boolean;
  parts: BlueprintPart[];
}

export interface Blueprint {
  id: string;
  kind: 'main' | 'subject' | 'state_language' | string;
  subject_id: string | null;
  exam_year: number;
  version: number;
  status: string;
  title: LocalizedText;
  languages: string[];
  options_per_question: number;
  sections: BlueprintSection[];
  /** The full original document, returned to the client as-is. */
  raw: Record<string, unknown>;
}

export interface VariantSection {
  section_id: string;
  question_ids: string[];
}

export interface Variant {
  id: string;
  blueprint_id: string;
  blueprint_version: number;
  number: number;
  title: LocalizedText;
  language: string;
  status: 'draft' | 'in_review' | 'published' | 'archived' | string;
  sections: VariantSection[];
}

export interface QuestionOption {
  id: string;
  text: string;
}

/**
 * Question table in the callable wire shape (ARCHITECTURE §1.3, decision D2):
 * `rows` is a list of rows, each a list of cell strings. Firestore cannot
 * store an array directly inside an array, so documents store rows as
 * `[{cells: [...]}]`; normalizeTable accepts both shapes.
 */
export interface QuestionTable {
  headers: string[];
  rows: string[][];
}

export interface ExamQuestion {
  id: string;
  subject_id: string | null;
  section_id: string | null;
  part_id: string | null;
  topic_id: string | null;
  difficulty: number;
  language: string | null;
  type: string;
  stem: string;
  options: QuestionOption[];
  passage_id: string | null;
  image_path: string | null;
  table: QuestionTable | null;
  column_a: string | null;
  column_b: string | null;
  review_status: string | null;
}

export interface QuestionKey {
  correct: string | null;
  explanation: string | null;
  wrong_option_notes: Record<string, string>;
  solution_steps: string[];
}

export interface Passage {
  id: string;
  title: string;
  text: string;
}

// ---------------------------------------------------------------------------
// Primitive coercion helpers

export function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

export function str(v: unknown, fallback = ''): string {
  return typeof v === 'string' ? v : fallback;
}

export function strOrNull(v: unknown): string | null {
  return typeof v === 'string' && v.length > 0 ? v : null;
}

export function num(v: unknown, fallback = 0): number {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string' && v.trim() !== '' && Number.isFinite(Number(v))) return Number(v);
  return fallback;
}

export function int(v: unknown, fallback = 0): number {
  return Math.trunc(num(v, fallback));
}

export function bool(v: unknown, fallback = false): boolean {
  return typeof v === 'boolean' ? v : fallback;
}

export function strList(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string' && x.length > 0) : [];
}

export function localized(v: unknown): LocalizedText {
  if (typeof v === 'string') return { ru: v };
  if (!isRecord(v)) return {};
  const out: LocalizedText = {};
  for (const [k, val] of Object.entries(v)) if (typeof val === 'string') out[k] = val;
  return out;
}

/** Picks `lang`, then ru, ky, en, then any value. */
export function pickLang(text: LocalizedText, lang: string): string {
  return text[lang] ?? text['ru'] ?? text['ky'] ?? text['en'] ?? Object.values(text)[0] ?? '';
}

// ---------------------------------------------------------------------------
// Parsers

const ITEM_TYPES: ReadonlySet<string> = new Set([
  'single_choice',
  'quantitative_comparison',
  'analogy',
  'completion',
  'text_based',
]);

function parsePart(raw: unknown, sectionId: string, sectionCount: number, defaultOptions: number): BlueprintPart {
  const r = isRecord(raw) ? raw : {};
  const itemType = str(r['item_type'], 'single_choice');
  const fixed = Array.isArray(r['fixed_options'])
    ? r['fixed_options']
        .filter(isRecord)
        .map((o) => ({ id: str(o['id']), text: localized(o['text']) }))
        .filter((o) => o.id.length > 0)
    : null;
  return {
    id: str(r['id'], sectionId),
    title: localized(r['title']),
    question_count: int(r['question_count'], sectionCount),
    options_per_question: int(r['options_per_question'], defaultOptions),
    item_type: (ITEM_TYPES.has(itemType) ? itemType : 'single_choice') as ItemType,
    verified: bool(r['verified'], false),
    fixed_options: fixed && fixed.length > 0 ? fixed : null,
  };
}

export function parseBlueprint(id: string, raw: unknown): Blueprint {
  if (!isRecord(raw)) throw new Error(`blueprint ${id}: not an object`);
  const defaultOptions = int(raw['options_per_question'], 4);
  const sectionsRaw = Array.isArray(raw['sections']) ? raw['sections'] : [];
  const sections: BlueprintSection[] = sectionsRaw
    .filter(isRecord)
    .map((s, i) => {
      const sid = str(s['id']);
      const count = int(s['question_count']);
      const partsRaw = Array.isArray(s['parts']) && s['parts'].length > 0 ? s['parts'] : [{ id: sid }];
      return {
        id: sid,
        order: int(s['order'], i + 1),
        title: localized(s['title']),
        question_count: count,
        duration_minutes: num(s['duration_minutes']),
        points_per_question: num(s['points_per_question'], 1),
        subject_area: strOrNull(s['subject_area']),
        uses_passages: bool(s['uses_passages'], false),
        parts: partsRaw.map((p) => parsePart(p, sid, count, defaultOptions)),
      };
    })
    .filter((s) => s.id.length > 0)
    .sort((a, b) => a.order - b.order);
  if (sections.length === 0) throw new Error(`blueprint ${id}: no sections`);
  for (const s of sections) {
    if (!(s.duration_minutes > 0) || !(s.question_count > 0)) {
      throw new Error(`blueprint ${id}: section ${s.id} needs question_count and duration_minutes`);
    }
  }
  return {
    id: str(raw['id'], id) || id,
    kind: str(raw['kind'], 'main'),
    subject_id: strOrNull(raw['subject_id']),
    exam_year: int(raw['exam_year']),
    version: int(raw['version'], 1),
    status: str(raw['status'], 'active'),
    title: localized(raw['title']),
    languages: strList(raw['languages']),
    options_per_question: defaultOptions,
    sections,
    raw,
  };
}

export function parseVariant(id: string, raw: unknown): Variant {
  if (!isRecord(raw)) throw new Error(`variant ${id}: not an object`);
  const sections = (Array.isArray(raw['sections']) ? raw['sections'] : [])
    .filter(isRecord)
    .map((s) => ({ section_id: str(s['section_id']), question_ids: strList(s['question_ids']) }))
    .filter((s) => s.section_id.length > 0);
  return {
    id,
    blueprint_id: str(raw['blueprint_id']),
    blueprint_version: int(raw['blueprint_version'], 1),
    number: int(raw['number']),
    title: localized(raw['title']),
    language: str(raw['language'], 'ru'),
    status: str(raw['status'], 'draft'),
    sections,
  };
}

function cellText(v: unknown): string {
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  return '';
}

function rowCells(row: unknown): string[] | null {
  if (Array.isArray(row)) return row.map(cellText);
  if (isRecord(row) && Array.isArray(row['cells'])) return row['cells'].map(cellText);
  return null;
}

/**
 * Stored table (Firestore `{headers, rows: [{cells}]}`, or the legacy /
 * bundled `{headers, rows: [[...]]}`) -> wire shape `{headers, rows: [[...]]}`.
 * Anything without headers or rows becomes null.
 */
export function normalizeTable(raw: unknown): QuestionTable | null {
  if (!isRecord(raw)) return null;
  const headers = Array.isArray(raw['headers']) ? raw['headers'].map(cellText) : [];
  const rows = (Array.isArray(raw['rows']) ? raw['rows'] : []).map(rowCells).filter((r): r is string[] => r !== null);
  if (headers.length === 0 && rows.length === 0) return null;
  return { headers, rows };
}

/** Plain-text rendering of a table for prompts (`a | b` per line). */
export function tableToText(table: QuestionTable | null): string {
  if (!table) return '';
  const lines: string[] = [];
  if (table.headers.length > 0) lines.push(table.headers.join(' | '));
  for (const r of table.rows) lines.push(r.join(' | '));
  return lines.join('\n');
}

export function parseQuestion(id: string, raw: unknown): ExamQuestion {
  const r = isRecord(raw) ? raw : {};
  const options = (Array.isArray(r['options']) ? r['options'] : [])
    .map((o, i): QuestionOption | null => {
      if (typeof o === 'string') return { id: String.fromCharCode(65 + i), text: o };
      if (!isRecord(o)) return null;
      return { id: str(o['id'], String.fromCharCode(65 + i)), text: str(o['text']) };
    })
    .filter((o): o is QuestionOption => o !== null);
  const review = isRecord(r['review']) ? r['review'] : {};
  return {
    id,
    subject_id: strOrNull(r['subject_id']),
    section_id: strOrNull(r['section_id']),
    part_id: strOrNull(r['part_id']),
    topic_id: strOrNull(r['topic_id']),
    difficulty: int(r['difficulty'], 2),
    language: strOrNull(r['language']),
    type: str(r['type'], 'single_choice'),
    stem: str(r['stem']),
    options,
    passage_id: strOrNull(r['passage_id']),
    image_path: strOrNull(r['image_path']),
    table: normalizeTable(r['table']),
    column_a: strOrNull(r['column_a']),
    column_b: strOrNull(r['column_b']),
    review_status: strOrNull(review['status']),
  };
}

export function parseKey(raw: unknown): QuestionKey {
  const r = isRecord(raw) ? raw : {};
  const notes: Record<string, string> = {};
  if (isRecord(r['wrong_option_notes'])) {
    for (const [k, v] of Object.entries(r['wrong_option_notes'])) if (typeof v === 'string') notes[k] = v;
  }
  return {
    correct: strOrNull(typeof r['correct'] === 'string' ? r['correct'].trim() : null),
    explanation: strOrNull(r['explanation']),
    wrong_option_notes: notes,
    solution_steps: strList(r['solution_steps']),
  };
}

export function parsePassage(id: string, raw: unknown): Passage {
  const r = isRecord(raw) ? raw : {};
  return { id, title: str(r['title']), text: str(r['text']) };
}

/**
 * Part a question belongs to: explicit `part_id` when the question has one,
 * otherwise by position (parts are laid out consecutively in the section).
 */
export function partForIndex(section: BlueprintSection, index: number): BlueprintPart | undefined {
  let offset = 0;
  for (const part of section.parts) {
    if (index < offset + part.question_count) return part;
    offset += part.question_count;
  }
  return section.parts[section.parts.length - 1];
}

/** `ort_main_2026` -> `ort_main` (direction key for best_exam_percent). */
export function directionKey(blueprintId: string): string {
  return blueprintId.replace(/_\d{4}$/, '');
}
