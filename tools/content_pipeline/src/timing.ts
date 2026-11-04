/**
 * Stage 7 — timing. Estimated solving time per item from type, subject,
 * difficulty and length, plus one read of each passage per variant. A
 * section "fits" when its estimate is within duration × (1 − margin).
 *
 * The constants are a calibrated starting point (a standard 30/50/20
 * difficulty mix of every blueprint fits with a 10 % margin); replace them
 * with medians from real attempts once exam_attempts data exists.
 */
import { Blueprint, sectionsInOrder } from './blueprints';
import { BankItem, BankPassage, ExamQuestion, ExamVariant } from './schema';
import { wordCount } from './text';

type Triple = readonly [number, number, number];

/** Base seconds by difficulty 1/2/3 for a typical-length item. */
const BASE_BY_SUBJECT_TYPE: Record<string, Triple> = {
  'math:quantitative_comparison': [40, 55, 75],
  'math:single_choice': [70, 100, 140],
  'verbal:analogy': [35, 45, 60],
  'verbal:completion': [40, 55, 70],
  'reading:text_based': [35, 50, 65],
  'grammar:single_choice': [40, 50, 65],
  'chemistry:single_choice': [75, 105, 140],
  'physics:single_choice': [75, 105, 140],
  'biology:single_choice': [45, 60, 80],
  'history:single_choice': [40, 55, 75],
  'english:single_choice': [30, 40, 55],
  'english:text_based': [35, 45, 60],
  'kyrgyz_lit:single_choice': [40, 55, 75],
  'russian_lit:single_choice': [40, 55, 75],
  'state_language:single_choice': [35, 45, 60],
  'state_language:text_based': [35, 45, 60],
};
const BASE_BY_TYPE: Record<string, Triple> = {
  quantitative_comparison: [40, 55, 75],
  single_choice: [50, 70, 95],
  analogy: [35, 45, 60],
  completion: [40, 55, 70],
  text_based: [35, 50, 65],
};
/** Words already covered by the base time; longer items add reading time. */
const BASELINE_WORDS: Record<string, number> = { quantitative_comparison: 25, single_choice: 45, analogy: 25, completion: 35, text_based: 40 };

export const TIMING_MODEL = {
  wpm_items: { ru: 150, ky: 150, en: 120 } as Record<string, number>,
  wpm_passages: { ru: 180, ky: 170, en: 130 } as Record<string, number>,
  passage_reread_factor: 1.2,
  default_margin: 0.1,
};

export function itemWords(q: Pick<ExamQuestion, 'stem' | 'options' | 'table'>): number {
  let w = wordCount(q.stem) + q.options.reduce((a, o) => a + wordCount(o.text), 0);
  if (q.table) w += q.table.rows.flat().reduce((a, c) => a + wordCount(c), 0);
  return w;
}

export function estimateItemSeconds(q: ExamQuestion): number {
  const base = BASE_BY_SUBJECT_TYPE[`${q.subject_id}:${q.type}`] ?? BASE_BY_TYPE[q.type] ?? [60, 80, 100];
  const words = q.type === 'quantitative_comparison' ? wordCount(q.stem) + (q.table ? q.table.rows.flat().reduce((a, c) => a + wordCount(c), 0) : 0) : itemWords(q);
  const extraWords = Math.max(0, words - (BASELINE_WORDS[q.type] ?? 40));
  const wpm = TIMING_MODEL.wpm_items[q.language] ?? 150;
  return base[q.difficulty - 1]! + (extraWords / wpm) * 60;
}

export function passageSeconds(p: BankPassage): number {
  const words = wordCount(p.passage.text) + wordCount(p.passage.title);
  const wpm = TIMING_MODEL.wpm_passages[p.passage.language] ?? 170;
  return (words / wpm) * 60 * TIMING_MODEL.passage_reread_factor;
}

export interface SectionTiming {
  section_id: string;
  items: number;
  passages: number;
  estimated_minutes: number;
  duration_minutes: number;
  budget_minutes: number;
  fits: boolean;
}

export interface VariantTiming {
  sections: SectionTiming[];
  fits: boolean;
  missing_items: string[];
}

const round1 = (x: number): number => Math.round(x * 10) / 10;

export function estimateVariantTiming(
  variant: ExamVariant,
  blueprint: Blueprint,
  items: Map<string, BankItem>,
  passages: Map<string, BankPassage>,
  margin: number = TIMING_MODEL.default_margin,
): VariantTiming {
  const missing: string[] = [];
  const sections: SectionTiming[] = [];
  for (const bs of sectionsInOrder(blueprint)) {
    const vs = variant.sections.find((s) => s.section_id === bs.id);
    const ids = vs?.question_ids ?? [];
    let seconds = 0;
    const seenPassages = new Set<string>();
    for (const id of ids) {
      const it = items.get(id);
      if (!it) {
        missing.push(id);
        continue;
      }
      seconds += estimateItemSeconds(it.question);
      const pid = it.question.passage_id;
      if (pid && !seenPassages.has(pid)) {
        seenPassages.add(pid);
        const p = passages.get(pid);
        if (p) seconds += passageSeconds(p);
      }
    }
    const budget = bs.duration_minutes * (1 - margin);
    const est = seconds / 60;
    sections.push({
      section_id: bs.id,
      items: ids.length,
      passages: seenPassages.size,
      estimated_minutes: round1(est),
      duration_minutes: bs.duration_minutes,
      budget_minutes: round1(budget),
      fits: est <= budget,
    });
  }
  return { sections, fits: sections.every((s) => s.fits) && missing.length === 0, missing_items: missing };
}
