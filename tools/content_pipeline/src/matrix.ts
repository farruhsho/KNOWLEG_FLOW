/**
 * Stage 1 — topic matrix. For every blueprint × language × section × part:
 * target items per topic in ONE variant, the allowed [min, max] range, the
 * exact difficulty counts derived from the blueprint's difficulty_mix, and a
 * topic × difficulty split (controlled rounding, so rows and columns add up).
 */
import { Blueprint, BlueprintPart, BlueprintSection, sectionsInOrder } from './blueprints';
import { Curriculum, PassagePlan, topicsForSlot } from './curriculum';
import { apportion, boundedMatrix } from './flow';
import { DIFFICULTIES, ItemType, Language } from './schema';

export type DifficultyKey = '1' | '2' | '3';
export type DifficultyCounts = Record<DifficultyKey, number>;

export interface TopicCell {
  topic_id: string;
  subject_id: string;
  title_ru: string;
  grades: [number, number];
  weight: number;
  target: number;
  min: number;
  max: number;
  difficulty_targets: DifficultyCounts;
  subtopics: string[];
}

export interface PartMatrix {
  slot: string;
  section_id: string;
  part_id: string;
  item_type: ItemType;
  question_count: number;
  options_per_question: number;
  fixed_options: boolean;
  verified: boolean;
  difficulty_counts: DifficultyCounts;
  passage_plan: PassagePlan | null;
  topics: TopicCell[];
}

export interface SectionMatrix {
  section_id: string;
  order: number;
  subject_id: string;
  duration_minutes: number;
  question_count: number;
  parts: PartMatrix[];
}

export interface LanguageMatrix {
  language: Language;
  sections: SectionMatrix[];
}

export interface BlueprintMatrix {
  schema_version: 1;
  blueprint_id: string;
  blueprint_version: number;
  languages: LanguageMatrix[];
  warnings: string[];
}

export const dkey = (d: number): DifficultyKey => String(d) as DifficultyKey;

/** subject_id written on questions of a section: subject area for the main test, the subject for subject tests. */
export function subjectIdFor(bp: Blueprint, section: BlueprintSection): string {
  return bp.kind === 'main' ? section.subject_area : (bp.subject_id ?? section.subject_area);
}

export const slotOf = (bp: Blueprint, section: BlueprintSection, part: BlueprintPart): string => `${bp.id}/${section.id}/${part.id}`;

export function difficultyCounts(total: number, mix: Record<string, number>): DifficultyCounts {
  const w = DIFFICULTIES.map((d) => mix[dkey(d)] ?? 0);
  const [a, b, c] = apportion(total, w);
  return { '1': a ?? 0, '2': b ?? 0, '3': c ?? 0 };
}

export function topicRange(target: number): { min: number; max: number } {
  const delta = Math.max(1, Math.round(target / 3));
  return { min: Math.max(0, target - delta), max: target + delta };
}

function passagePlanFor(bp: Blueprint, section: BlueprintSection, part: BlueprintPart, c: Curriculum, warnings: string[]): PassagePlan | null {
  const slot = slotOf(bp, section, part);
  if (part.item_type === 'text_based' && section.passage_layout) {
    const texts = section.passage_layout.standalone_texts + section.passage_layout.paired_texts;
    return {
      standalone_texts: section.passage_layout.standalone_texts,
      paired_texts: section.passage_layout.paired_texts,
      questions_per_text: Math.round(part.question_count / Math.max(1, texts)),
      words: [section.passage_layout.words_min, section.passage_layout.words_max],
    };
  }
  const configured = c.slot_settings[slot]?.passage_plan;
  if (configured) return configured;
  if (part.item_type === 'text_based') {
    const texts = Math.max(1, Math.ceil(part.question_count / 10));
    warnings.push(`${slot}: text_based part without passage plan; assuming ${texts} standalone text(s)`);
    return { standalone_texts: texts, paired_texts: 0, questions_per_text: Math.round(part.question_count / texts) };
  }
  return null;
}

export function buildPartMatrix(bp: Blueprint, section: BlueprintSection, part: BlueprintPart, language: Language, c: Curriculum, warnings: string[]): PartMatrix {
  const slot = slotOf(bp, section, part);
  const mix = section.difficulty_mix;
  const dc = difficultyCounts(part.question_count, mix);
  const topics = topicsForSlot(c, slot, language);
  if (topics.length === 0) warnings.push(`${slot} [${language}]: no topics in the curriculum catalog`);
  const weightSum = topics.reduce((a, t) => a + t.weight, 0);
  if (topics.length && weightSum !== part.question_count) {
    warnings.push(`${slot} [${language}]: topic weights sum to ${weightSum}, rescaled to ${part.question_count}`);
  }
  const targets = apportion(part.question_count, topics.map((t) => t.weight));

  // Controlled rounding of target × mix: row sums = topic targets, column sums = difficulty counts.
  const p = DIFFICULTIES.map((d) => mix[dkey(d)] ?? 0);
  const pSum = p.reduce((a, b) => a + b, 0) || 1;
  const cellLo = targets.map((t) => p.map((pk) => Math.floor((t * pk) / pSum)));
  const cellHi = targets.map((t) => p.map((pk) => Math.ceil((t * pk) / pSum)));
  const rows = targets.map((t) => ({ lo: t, hi: t }));
  const cols = DIFFICULTIES.map((d) => ({ lo: dc[dkey(d)], hi: dc[dkey(d)] }));
  let split = topics.length ? boundedMatrix(rows, cols, cellLo, cellHi) : [];
  if (topics.length && !split) {
    split = boundedMatrix(rows, cols, targets.map(() => [0, 0, 0]), targets.map((t) => [t, t, t]));
    warnings.push(`${slot} [${language}]: topic × difficulty split needed widened cells`);
  }

  return {
    slot,
    section_id: section.id,
    part_id: part.id,
    item_type: part.item_type,
    question_count: part.question_count,
    options_per_question: part.options_per_question,
    fixed_options: Array.isArray(part.fixed_options) && part.fixed_options.length > 0,
    verified: part.verified,
    difficulty_counts: dc,
    passage_plan: passagePlanFor(bp, section, part, c, warnings),
    topics: topics.map((t, i) => {
      const target = targets[i] ?? 0;
      const row = split?.[i] ?? [0, 0, 0];
      return {
        topic_id: t.topic.id,
        subject_id: t.subjectId,
        title_ru: t.topic.title.ru,
        grades: t.topic.grades,
        weight: t.weight,
        target,
        ...topicRange(target),
        difficulty_targets: { '1': row[0] ?? 0, '2': row[1] ?? 0, '3': row[2] ?? 0 },
        subtopics: t.topic.subtopics.map((s) => s.id),
      };
    }),
  };
}

export function buildBlueprintMatrix(bp: Blueprint, c: Curriculum): BlueprintMatrix {
  const warnings: string[] = [];
  const languages: LanguageMatrix[] = bp.languages.map((language) => ({
    language,
    sections: sectionsInOrder(bp).map((section) => ({
      section_id: section.id,
      order: section.order,
      subject_id: subjectIdFor(bp, section),
      duration_minutes: section.duration_minutes,
      question_count: section.question_count,
      parts: section.parts.map((part) => buildPartMatrix(bp, section, part, language, c, warnings)),
    })),
  }));
  return { schema_version: 1, blueprint_id: bp.id, blueprint_version: bp.version, languages, warnings: [...new Set(warnings)] };
}

export function languageMatrix(m: BlueprintMatrix, language: string): LanguageMatrix {
  const lm = m.languages.find((l) => l.language === language);
  if (!lm) throw new Error(`${m.blueprint_id}: language ${language} is not in the blueprint (${m.languages.map((l) => l.language).join(', ')})`);
  return lm;
}

export function findPartMatrix(m: BlueprintMatrix, language: string, sectionId: string, partId: string): PartMatrix {
  const lm = languageMatrix(m, language);
  const s = lm.sections.find((x) => x.section_id === sectionId);
  const p = s?.parts.find((x) => x.part_id === partId);
  if (!p) throw new Error(`${m.blueprint_id}/${sectionId}/${partId}: not in matrix`);
  return p;
}

export interface CellTarget {
  slot: string;
  section_id: string;
  part_id: string;
  topic_id: string;
  difficulty: 1 | 2 | 3;
  per_variant: number;
  bank_target: number;
}

/**
 * How many items the bank needs per topic × difficulty to assemble `variants`
 * variants without reuse, with `overgeneration` headroom for rejections.
 */
export function bankTargets(m: BlueprintMatrix, language: string, variants: number, overgeneration: number): CellTarget[] {
  const out: CellTarget[] = [];
  for (const s of languageMatrix(m, language).sections) {
    for (const p of s.parts) {
      for (const t of p.topics) {
        for (const d of DIFFICULTIES) {
          const per = t.difficulty_targets[dkey(d)];
          if (per <= 0) continue;
          out.push({
            slot: p.slot,
            section_id: s.section_id,
            part_id: p.part_id,
            topic_id: t.topic_id,
            difficulty: d,
            per_variant: per,
            bank_target: Math.ceil(per * variants * overgeneration),
          });
        }
      }
    }
  }
  return out;
}

/** Plain-text summary for the CLI. */
export function describeMatrix(m: BlueprintMatrix): string {
  const lines: string[] = [`${m.blueprint_id} v${m.blueprint_version}`];
  for (const lm of m.languages) {
    lines.push(`  [${lm.language}]`);
    for (const s of lm.sections) {
      for (const p of s.parts) {
        const dc = p.difficulty_counts;
        const pp = p.passage_plan ? ` texts ${p.passage_plan.standalone_texts}+${p.passage_plan.paired_texts}paired x${p.passage_plan.questions_per_text}` : '';
        lines.push(`    ${s.section_id}/${p.part_id} ${p.item_type} ${p.question_count}q diff ${dc['1']}/${dc['2']}/${dc['3']} topics ${p.topics.length}${pp}`);
      }
    }
  }
  for (const w of m.warnings) lines.push(`  ! ${w}`);
  return lines.join('\n');
}
