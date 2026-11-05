import { readFileSync } from 'node:fs';
import path from 'node:path';
import { parseBlueprint, partForIndex, type Blueprint, type ExamQuestion, type QuestionKey, type Variant } from '../src/domain/types';

const BLUEPRINTS_FILE = path.resolve(__dirname, '..', '..', 'assets', 'data', 'exam_blueprints.json');

export function rawBlueprints(): Record<string, unknown>[] {
  const json = JSON.parse(readFileSync(BLUEPRINTS_FILE, 'utf8')) as { blueprints: Record<string, unknown>[] };
  return json.blueprints;
}

export function blueprint(id: string): Blueprint {
  const raw = rawBlueprints().find((b) => b['id'] === id);
  if (!raw) throw new Error(`no blueprint ${id}`);
  return parseBlueprint(id, raw);
}

export interface Bank {
  variant: Variant;
  questions: Map<string, ExamQuestion>;
  keys: Map<string, QuestionKey>;
}

/** A complete, valid variant (all approved, keyed) for a blueprint. */
export function buildBank(bp: Blueprint, language = 'ru', withPartIds = false): Bank {
  const questions = new Map<string, ExamQuestion>();
  const keys = new Map<string, QuestionKey>();
  const sections = bp.sections.map((s) => {
    const ids: string[] = [];
    for (let i = 0; i < s.question_count; i++) {
      const id = `${s.id}_q${i + 1}`;
      const part = partForIndex(s, i)!;
      const optionCount = part.item_type === 'quantitative_comparison' ? 0 : part.options_per_question;
      questions.set(id, {
        id,
        subject_id: s.subject_area,
        section_id: s.id,
        part_id: withPartIds ? part.id : null,
        topic_id: `${s.id}.topic_${i % 3}`,
        difficulty: 2,
        language,
        type: part.item_type,
        stem: `Question ${id}`,
        options: Array.from({ length: optionCount }, (_, k) => ({ id: String.fromCharCode(65 + k), text: `opt ${k}` })),
        passage_id: part.item_type === 'text_based' ? `${s.id}_p${Math.floor(i / 10)}` : null,
        image_path: null,
        table: null,
        column_a: part.item_type === 'quantitative_comparison' ? '2+2' : null,
        column_b: part.item_type === 'quantitative_comparison' ? '5' : null,
        review_status: 'methodologist_approved',
      });
      keys.set(id, { correct: 'A', explanation: 'because', wrong_option_notes: {}, solution_steps: [] });
      ids.push(id);
    }
    return { section_id: s.id, question_ids: ids };
  });
  const variant: Variant = {
    id: `${bp.id}_v1`,
    blueprint_id: bp.id,
    blueprint_version: bp.version,
    number: 1,
    title: { ru: 'Вариант 1' },
    language,
    status: 'draft',
    sections,
  };
  return { variant, questions, keys };
}

/** Epoch ms of a Bishkek wall-clock time (UTC+6). */
export function bishkek(y: number, mo: number, d: number, h = 0, mi = 0, s = 0): number {
  return Date.UTC(y, mo - 1, d, h - 6, mi, s);
}
