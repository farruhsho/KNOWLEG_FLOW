/**
 * Stage 2 — generation (opt-in, paid). Plans the deficit per
 * (section, part, topic, difficulty, language) from the matrix and the bank,
 * then asks Claude for ORIGINAL items with a strict JSON schema. Every
 * result is converted into a BankItem, re-validated with zod and saved as
 * review.status 'draft' — nothing generated is ever approved automatically.
 * The bank file is rewritten after every request, so an interrupted run
 * resumes by simply running the same command again.
 */
import { Blueprint, BlueprintPart, fixedOptionsFor, findPart } from './blueprints';
import { Bank, LoadedBankFile, passageContentHash, passageIdFromHash, questionContentHash, questionIdFromHash, saveBankFile, translationGroupFor } from './bank';
import { isDedupExcluded } from './dedup';
import { CostMeter, LlmClient, LlmError } from './llm';
import { BlueprintMatrix, DifficultyKey, languageMatrix, PartMatrix, SectionMatrix, TopicCell } from './matrix';
import {
  choiceItemSchema,
  comparisonItemSchema,
  GENERATION_SYSTEM,
  itemsEnvelope,
  LANGUAGE_NAMES,
  passageGroupSchema,
  PROMPT_VERSION,
  TRANSLATION_SYSTEM,
  translationSchema,
} from './prompts';
import { BankItem, BankPassage, DIFFICULTIES, Difficulty, ExamQuestion, ExamQuestionKey, Language, OPTION_IDS, OptionId, QuestionTable } from './schema';
import { z } from 'zod';

export const COMPARISON_INSTRUCTION: Record<string, string> = {
  ru: 'Сравните величины в колонках А и Б.',
  ky: 'А жана Б мамычаларындагы чоңдуктарды салыштырыңыз.',
  en: 'Compare the quantities in columns A and B.',
};
export const COMPARISON_HEADERS: Record<string, [string, string]> = {
  ru: ['Колонка А', 'Колонка Б'],
  ky: ['А мамычасы', 'Б мамычасы'],
  en: ['Column A', 'Column B'],
};

export interface PlanRow {
  kind: 'items' | 'passage_group';
  slot: string;
  section_id: string;
  part_id: string;
  language: Language;
  topic_id: string | null;
  difficulty: Difficulty | null;
  layout: 'standalone' | 'paired' | null;
  have: number;
  target: number;
  deficit: number;
}

export interface PlanFilter {
  section?: string;
  part?: string;
  topic?: string;
}

const isPassageTopic = (p: PartMatrix, topicId: string): boolean => {
  if (!p.passage_plan) return false;
  const pt = p.passage_plan.passage_topics;
  return pt ? pt.includes(topicId) : true;
};

/** Deficits per cell for `variants` variants with `overgeneration` headroom (default 1.3 = 30 % spare for rejections). */
export function planGeneration(matrix: BlueprintMatrix, language: Language, bank: Bank, variants: number, overgeneration: number, filter: PlanFilter = {}): PlanRow[] {
  const items = [...bank.items.values()].map((v) => v.item).filter((it) => it.question.language === language && it.question.review.status !== 'rejected' && !isDedupExcluded(it));
  const rows: PlanRow[] = [];
  for (const s of languageMatrix(matrix, language).sections) {
    if (filter.section && filter.section !== s.section_id) continue;
    for (const p of s.parts) {
      if (filter.part && filter.part !== p.part_id) continue;
      const inSlot = items.filter((it) => `${it.target.blueprint_id}/${it.target.section_id}/${it.target.part_id}` === p.slot);
      for (const t of p.topics) {
        if (filter.topic && filter.topic !== t.topic_id) continue;
        if (isPassageTopic(p, t.topic_id)) continue;
        for (const d of DIFFICULTIES) {
          const per = t.difficulty_targets[String(d) as DifficultyKey];
          if (per <= 0) continue;
          const have = inSlot.filter((it) => it.question.passage_id === null && it.question.topic_id === t.topic_id && it.question.difficulty === d).length;
          const target = Math.ceil(per * variants * overgeneration);
          rows.push({ kind: 'items', slot: p.slot, section_id: s.section_id, part_id: p.part_id, language, topic_id: t.topic_id, difficulty: d, layout: null, have, target, deficit: Math.max(0, target - have) });
        }
      }
      const plan = p.passage_plan;
      if (plan && !filter.topic) {
        for (const layout of ['standalone', 'paired'] as const) {
          const texts = layout === 'standalone' ? plan.standalone_texts : plan.paired_texts;
          if (texts <= 0) continue;
          const passageIds = new Set(inSlot.map((it) => it.question.passage_id).filter((x): x is string => x !== null));
          const have = [...passageIds].filter((pid) => bank.passages.get(pid)?.passage.layout === layout).length;
          const target = Math.ceil(texts * variants * overgeneration);
          rows.push({ kind: 'passage_group', slot: p.slot, section_id: s.section_id, part_id: p.part_id, language, topic_id: null, difficulty: null, layout, have, target, deficit: Math.max(0, target - have) });
        }
      }
    }
  }
  return rows;
}

/** Rough tokens per request for the cost preview (output dominates). */
export function estimateRequestTokens(row: PlanRow, perRequest: number): { input: number; output: number } {
  if (row.kind === 'passage_group') return { input: 2500, output: row.layout === 'paired' ? 9000 : 7000 };
  return { input: 2200, output: 900 * perRequest + 1500 };
}

// ---------------------------------------------------------------------------
// Conversion of model output into bank items
// ---------------------------------------------------------------------------

const WrongNotes = z.array(z.object({ option: z.string(), note: z.string() }));
const ChoiceOut = z.object({
  subtopic_id: z.string(),
  stem: z.string().min(1),
  options: z.array(z.string().min(1)),
  correct: z.string(),
  explanation: z.string().min(1),
  solution_steps: z.array(z.string()),
  wrong_option_notes: WrongNotes,
  basis: z.string().min(1),
});
const ComparisonOut = z.object({
  subtopic_id: z.string(),
  condition: z.string(),
  column_a: z.string().min(1),
  column_b: z.string().min(1),
  correct: z.string(),
  explanation: z.string().min(1),
  solution_steps: z.array(z.string()),
  wrong_option_notes: WrongNotes,
  basis: z.string().min(1),
});
const PassageGroupOut = z.object({
  texts: z.array(z.object({ title: z.string(), text: z.string().min(1) })).min(1).max(2),
  basis: z.string().min(1),
  questions: z.array(
    z.object({
      topic_id: z.string(),
      difficulty: z.enum(['1', '2', '3']),
      stem: z.string().min(1),
      options: z.array(z.string().min(1)),
      correct: z.string(),
      explanation: z.string().min(1),
      solution_steps: z.array(z.string()),
      wrong_option_notes: WrongNotes,
    }),
  ),
});

export interface CellContext {
  blueprint: Blueprint;
  section: SectionMatrix;
  part: PartMatrix;
  bpPart: BlueprintPart;
  language: Language;
  batchId: string;
  model: string;
  now: string;
}

function notesRecord(notes: z.infer<typeof WrongNotes>, ids: readonly string[], correct: string): ExamQuestionKey['wrong_option_notes'] {
  const out: ExamQuestionKey['wrong_option_notes'] = {};
  for (const n of notes) if (ids.includes(n.option) && n.option !== correct && n.note.trim()) out[n.option as OptionId] = n.note.trim();
  return out;
}

function finishItem(ctx: CellContext, q: Omit<ExamQuestion, 'content_hash' | 'translation_group_id'> & { translation_group_id?: string | null }, key: ExamQuestionKey, passageOrder: number | null, generatedBy: string): BankItem {
  const content_hash = questionContentHash(q);
  const question: ExamQuestion = { ...q, translation_group_id: q.translation_group_id ?? translationGroupFor(content_hash), content_hash };
  return {
    id: questionIdFromHash(content_hash),
    target: { blueprint_id: ctx.blueprint.id, section_id: ctx.section.section_id, part_id: ctx.part.part_id },
    question,
    key,
    passage_order: passageOrder,
    pipeline: { batch_id: ctx.batchId, generated_by: generatedBy, prompt_version: PROMPT_VERSION },
  };
}

function baseQuestion(ctx: CellContext, topic: TopicCell, subtopic: string | null, difficulty: Difficulty, basis: string): Omit<ExamQuestion, 'content_hash' | 'stem' | 'options' | 'table' | 'translation_group_id'> {
  return {
    subject_id: ctx.section.subject_id,
    section_id: ctx.section.section_id,
    topic_id: topic.topic_id,
    subtopic_id: subtopic && topic.subtopics.includes(subtopic) ? subtopic : null,
    difficulty,
    language: ctx.language,
    type: ctx.part.item_type,
    passage_id: null,
    image_path: null,
    source: { kind: 'original', basis: basis.trim(), author: `pipeline:${PROMPT_VERSION}` },
    review: { status: 'draft', reviewed_by: null, reviewed_at: null, notes: '' },
    content_version: 1,
    created_at: ctx.now,
    updated_at: ctx.now,
  };
}

export function convertChoice(ctx: CellContext, topic: TopicCell, difficulty: Difficulty, raw: unknown): BankItem {
  const o = ChoiceOut.parse(raw);
  const ids = OPTION_IDS.slice(0, ctx.part.options_per_question);
  if (o.options.length !== ids.length) throw new Error(`expected ${ids.length} options, got ${o.options.length}`);
  if (!ids.includes(o.correct as OptionId)) throw new Error(`correct ${o.correct} is not one of ${ids.join('')}`);
  const q = {
    ...baseQuestion(ctx, topic, o.subtopic_id, difficulty, o.basis),
    stem: o.stem.trim(),
    options: o.options.map((text, i) => ({ id: ids[i]!, text: text.trim() })),
    table: null,
  };
  const key: ExamQuestionKey = { correct: o.correct as OptionId, explanation: o.explanation.trim(), wrong_option_notes: notesRecord(o.wrong_option_notes, ids, o.correct), solution_steps: o.solution_steps.map((s) => s.trim()).filter(Boolean) };
  return finishItem(ctx, q, key, null, `model:${ctx.model}`);
}

export function comparisonQuestionParts(language: string, condition: string, a: string, b: string, bpPart: BlueprintPart): { stem: string; table: QuestionTable; options: Array<{ id: OptionId; text: string }> } {
  const fixed = fixedOptionsFor(bpPart, language);
  if (!fixed || fixed.length !== 4) throw new Error('comparison part has no fixed options for this language');
  const instruction = COMPARISON_INSTRUCTION[language] ?? COMPARISON_INSTRUCTION.ru!;
  return {
    stem: condition.trim() ? `${condition.trim()}\n\n${instruction}` : instruction,
    table: { headers: [...(COMPARISON_HEADERS[language] ?? COMPARISON_HEADERS.ru!)], rows: [[a.trim(), b.trim()]] },
    options: fixed.map((f) => ({ id: f.id as OptionId, text: f.text })),
  };
}

export function convertComparison(ctx: CellContext, topic: TopicCell, difficulty: Difficulty, raw: unknown): BankItem {
  const o = ComparisonOut.parse(raw);
  const ids = OPTION_IDS.slice(0, 4);
  if (!ids.includes(o.correct as OptionId)) throw new Error(`correct ${o.correct} is not one of ABCD`);
  const parts = comparisonQuestionParts(ctx.language, o.condition, o.column_a, o.column_b, ctx.bpPart);
  const q = { ...baseQuestion(ctx, topic, o.subtopic_id, difficulty, o.basis), ...parts };
  const key: ExamQuestionKey = { correct: o.correct as OptionId, explanation: o.explanation.trim(), wrong_option_notes: notesRecord(o.wrong_option_notes, ids, o.correct), solution_steps: o.solution_steps.map((s) => s.trim()).filter(Boolean) };
  return finishItem(ctx, q, key, null, `model:${ctx.model}`);
}

export function convertPassageGroup(ctx: CellContext, layout: 'standalone' | 'paired', raw: unknown): { passage: BankPassage; items: BankItem[] } {
  const o = PassageGroupOut.parse(raw);
  if (layout === 'paired' && o.texts.length !== 2) throw new Error('paired group needs exactly 2 texts');
  if (layout === 'standalone' && o.texts.length !== 1) throw new Error('standalone group needs exactly 1 text');
  const label = ctx.language === 'ky' ? 'Текст' : ctx.language === 'en' ? 'Text' : 'Текст';
  const title = o.texts.map((t) => t.title.trim()).join(' / ');
  const text = o.texts.length === 1 ? o.texts[0]!.text.trim() : o.texts.map((t, i) => `${label} ${i + 1}. ${t.title.trim()}\n\n${t.text.trim()}`).join('\n\n');
  const passageDoc = {
    language: ctx.language,
    subject_id: ctx.section.subject_id,
    section_id: ctx.section.section_id,
    title,
    text,
    source: { kind: 'original' as const, basis: o.basis.trim(), author: `pipeline:${PROMPT_VERSION}` },
  };
  const content_hash = passageContentHash(passageDoc);
  const passage: BankPassage = { id: passageIdFromHash(content_hash), layout, translation_group_id: translationGroupFor(content_hash), content_hash, passage: passageDoc };
  const ids = OPTION_IDS.slice(0, ctx.part.options_per_question);
  const items: BankItem[] = [];
  o.questions.forEach((qo, idx) => {
    const topic = ctx.part.topics.find((t) => t.topic_id === qo.topic_id);
    if (!topic) throw new Error(`question ${idx + 1}: unknown topic ${qo.topic_id}`);
    if (qo.options.length !== ids.length) throw new Error(`question ${idx + 1}: expected ${ids.length} options`);
    if (!ids.includes(qo.correct as OptionId)) throw new Error(`question ${idx + 1}: bad key ${qo.correct}`);
    const difficulty = Number(qo.difficulty) as Difficulty;
    const q = {
      ...baseQuestion(ctx, topic, null, difficulty, o.basis),
      stem: qo.stem.trim(),
      options: qo.options.map((t, i) => ({ id: ids[i]!, text: t.trim() })),
      table: null,
      passage_id: passage.id,
    };
    const key: ExamQuestionKey = { correct: qo.correct as OptionId, explanation: qo.explanation.trim(), wrong_option_notes: notesRecord(qo.wrong_option_notes, ids, qo.correct), solution_steps: qo.solution_steps.map((s) => s.trim()).filter(Boolean) };
    items.push(finishItem(ctx, q, key, idx + 1, `model:${ctx.model}`));
  });
  return { passage, items };
}

// ---------------------------------------------------------------------------
// Prompts per cell
// ---------------------------------------------------------------------------

function topicBrief(topic: TopicCell): Record<string, unknown> {
  return { id: topic.topic_id, title_ru: topic.title_ru, grades: topic.grades, subtopics: topic.subtopics };
}

export function itemsRequest(ctx: CellContext, topic: TopicCell, difficulty: Difficulty, count: number, avoid: string[]): { user: string; schema: Record<string, unknown> } {
  const comparison = ctx.part.item_type === 'quantitative_comparison';
  const spec = {
    task: 'generate_items',
    count,
    language: LANGUAGE_NAMES[ctx.language],
    exam: { blueprint_id: ctx.blueprint.id, section_id: ctx.section.section_id, part_id: ctx.part.part_id, item_type: ctx.part.item_type, options_per_question: ctx.part.options_per_question },
    fixed_options: comparison ? fixedOptionsFor(ctx.bpPart, ctx.language) : undefined,
    topic: topicBrief(topic),
    difficulty,
    vary: 'Use different subtopics, contexts and numbers across the items; vary which option is correct.',
    do_not_repeat_these_existing_stems: avoid,
  };
  const item = comparison ? comparisonItemSchema(topic.subtopics) : choiceItemSchema(OPTION_IDS.slice(0, ctx.part.options_per_question), topic.subtopics);
  return { user: JSON.stringify(spec, null, 2), schema: itemsEnvelope(item) };
}

export function passageRequest(ctx: CellContext, layout: 'standalone' | 'paired', avoidTitles: string[]): { user: string; schema: Record<string, unknown> } {
  const plan = ctx.part.passage_plan!;
  const topics = ctx.part.topics.filter((t) => isPassageTopic(ctx.part, t.topic_id) && (layout === 'paired' || t.topic_id !== 'reading.paired_comparison'));
  const questions = plan.questions_per_text + 2;
  const spec = {
    task: 'generate_passage_group',
    language: LANGUAGE_NAMES[ctx.language],
    layout: layout === 'paired' ? 'two related texts on one theme (paired passage) with questions on each and on their comparison' : 'one text',
    words_per_text: plan.words ?? [400, 850],
    genres: 'humanities, social science, natural science, or literary prose — pick one that differs from the avoided titles',
    questions,
    questions_note: `Order questions as they follow the text. Spread difficulty about 30% level 1, 50% level 2, 20% level 3. Use these topics: ${topics.map((t) => t.topic_id).join(', ')}.`,
    options_per_question: ctx.part.options_per_question,
    do_not_reuse_these_titles: avoidTitles,
  };
  return { user: JSON.stringify(spec, null, 2), schema: passageGroupSchema(OPTION_IDS.slice(0, ctx.part.options_per_question), topics.map((t) => t.topic_id)) };
}

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

export interface GenerateRunOptions {
  blueprint: Blueprint;
  matrix: BlueprintMatrix;
  language: Language;
  bank: Bank;
  file: LoadedBankFile;
  llm: LlmClient;
  rows: PlanRow[];
  perRequest: number;
  maxItems: number;
  meter: CostMeter;
  now: () => string;
  log: (line: string) => void;
}

export interface GenerateRunResult {
  items_added: number;
  passages_added: number;
  failures: Array<{ cell: string; error: string }>;
}

function addToBank(bank: Bank, file: LoadedBankFile, items: BankItem[], passage?: BankPassage): number {
  let added = 0;
  if (passage && !bank.passages.has(passage.id)) {
    file.data.passages.push(passage);
    bank.passages.set(passage.id, { passage, file });
  }
  for (const it of items) {
    if (bank.items.has(it.id)) continue;
    file.data.items.push(it);
    bank.items.set(it.id, { item: it, file });
    added++;
  }
  return added;
}

export async function runGeneration(o: GenerateRunOptions): Promise<GenerateRunResult> {
  const res: GenerateRunResult = { items_added: 0, passages_added: 0, failures: [] };
  const lm = languageMatrix(o.matrix, o.language);
  for (const row of o.rows) {
    if (row.deficit <= 0) continue;
    const section = lm.sections.find((s) => s.section_id === row.section_id)!;
    const part = section.parts.find((p) => p.part_id === row.part_id)!;
    const { part: bpPart } = findPart(o.blueprint, row.section_id, row.part_id);
    let remaining = row.deficit;
    while (remaining > 0) {
      if (res.items_added >= o.maxItems) return res;
      if (o.meter.exhausted()) {
        o.log(`cost limit reached: ${o.meter}`);
        return res;
      }
      const ctx: CellContext = { blueprint: o.blueprint, section, part, bpPart, language: o.language, batchId: o.file.data.batch.id, model: o.llm.model, now: o.now() };
      const cellName = `${row.slot}/${row.topic_id ?? row.layout}/${row.difficulty ?? ''}`;
      try {
        if (row.kind === 'passage_group') {
          const avoid = [...o.bank.passages.values()].filter((p) => p.passage.passage.language === o.language && p.passage.passage.section_id === row.section_id).map((p) => p.passage.passage.title).slice(-40);
          const req = passageRequest(ctx, row.layout!, avoid);
          const out = await o.llm.complete({ purpose: 'generate', system: GENERATION_SYSTEM, user: req.user, schema: req.schema });
          o.meter.add(out.usage);
          const group = convertPassageGroup(ctx, row.layout!, out.json);
          const n = addToBank(o.bank, o.file, group.items, group.passage);
          res.items_added += n;
          res.passages_added++;
          remaining -= 1;
          o.log(`+ passage ${group.passage.id} (${row.layout}) with ${n} questions — ${o.meter}`);
        } else {
          const topic = part.topics.find((t) => t.topic_id === row.topic_id)!;
          const count = Math.min(o.perRequest, remaining, o.maxItems - res.items_added);
          const avoid = [...o.bank.items.values()]
            .map((v) => v.item)
            .filter((it) => it.question.language === o.language && it.question.topic_id === topic.topic_id && it.target.part_id === row.part_id)
            .map((it) => (it.question.table ? `${it.question.table.rows[0]?.join(' | ')}` : it.question.stem).slice(0, 140))
            .slice(-25);
          const req = itemsRequest(ctx, topic, row.difficulty!, count, avoid);
          const out = await o.llm.complete({ purpose: 'generate', system: GENERATION_SYSTEM, user: req.user, schema: req.schema });
          o.meter.add(out.usage);
          const rawItems = (out.json as { items?: unknown[] }).items ?? [];
          const converted: BankItem[] = [];
          for (const raw of rawItems) {
            try {
              converted.push(part.item_type === 'quantitative_comparison' ? convertComparison(ctx, topic, row.difficulty!, raw) : convertChoice(ctx, topic, row.difficulty!, raw));
            } catch (e) {
              res.failures.push({ cell: cellName, error: `item rejected by schema: ${(e as Error).message}` });
            }
          }
          const n = addToBank(o.bank, o.file, converted);
          res.items_added += n;
          remaining -= Math.max(1, n);
          o.log(`+ ${n}/${count} ${cellName} — ${o.meter}`);
        }
        saveBankFile(o.file);
      } catch (e) {
        const msg = e instanceof LlmError ? `${e.kind}: ${e.message}` : (e as Error).message;
        res.failures.push({ cell: cellName, error: msg });
        o.log(`! ${cellName}: ${msg}`);
        if (e instanceof LlmError && e.kind === 'api') return res;
        remaining -= 1;
      }
    }
  }
  return res;
}

// ---------------------------------------------------------------------------
// Translation (generate --translate-from)
// ---------------------------------------------------------------------------

const TranslationOut = z.object({
  translatable: z.boolean(),
  reason: z.string(),
  stem: z.string(),
  table_rows: z.array(z.array(z.string())),
  options: z.array(z.string()),
  correct: z.string(),
  explanation: z.string(),
  solution_steps: z.array(z.string()),
  wrong_option_notes: WrongNotes,
});

/** Standalone source items (verified or approved) that have no version in `target` yet. */
export function translationCandidates(bank: Bank, from: Language, target: Language, blueprintId: string, filter: PlanFilter = {}): BankItem[] {
  const items = [...bank.items.values()].map((v) => v.item);
  const haveTarget = new Set(items.filter((i) => i.question.language === target && i.question.translation_group_id).map((i) => i.question.translation_group_id!));
  return items
    .filter(
      (i) =>
        i.question.language === from &&
        i.target.blueprint_id === blueprintId &&
        i.question.passage_id === null &&
        (i.question.review.status === 'ai_verified' || i.question.review.status === 'methodologist_approved') &&
        !isDedupExcluded(i) &&
        (!filter.section || i.target.section_id === filter.section) &&
        (!filter.part || i.target.part_id === filter.part) &&
        (!filter.topic || i.question.topic_id === filter.topic) &&
        !(i.question.translation_group_id && haveTarget.has(i.question.translation_group_id)),
    )
    .sort((a, b) => a.id.localeCompare(b.id));
}

export function convertTranslation(source: BankItem, target: Language, bpPart: BlueprintPart, raw: unknown, ctx: { batchId: string; model: string; now: string }): BankItem {
  const o = TranslationOut.parse(raw);
  if (!o.translatable) throw new Error(`not translatable: ${o.reason}`);
  const sq = source.question;
  if (o.correct !== source.key.correct) throw new Error(`translation changed the key ${source.key.correct} → ${o.correct}`);
  let stem = o.stem.trim();
  let table: QuestionTable | null = null;
  let options: ExamQuestion['options'];
  if (sq.type === 'quantitative_comparison') {
    const row = o.table_rows[0];
    if (!row || row.length !== 2) throw new Error('comparison translation needs one table row with 2 cells');
    const parts = comparisonQuestionParts(target, stem, row[0]!, row[1]!, bpPart);
    stem = parts.stem;
    table = parts.table;
    options = parts.options;
  } else {
    if (o.options.length !== sq.options.length) throw new Error(`translation has ${o.options.length} options, source ${sq.options.length}`);
    options = o.options.map((text, i) => ({ id: sq.options[i]!.id, text: text.trim() }));
    if (sq.table) {
      if (o.table_rows.length !== sq.table.rows.length) throw new Error('translation changed the table shape');
      table = { headers: sq.table.headers, rows: o.table_rows };
    }
  }
  const ids = options.map((x) => x.id);
  const q = {
    ...sq,
    language: target,
    stem,
    options,
    table,
    source: { ...sq.source, author: `pipeline:${PROMPT_VERSION}:translate_from_${sq.language}` },
    review: { status: 'draft' as const, reviewed_by: null, reviewed_at: null, notes: '' },
    content_version: 1,
    created_at: ctx.now,
    updated_at: ctx.now,
  };
  const content_hash = questionContentHash(q);
  return {
    id: questionIdFromHash(content_hash),
    target: { ...source.target },
    question: { ...q, content_hash },
    key: { correct: source.key.correct, explanation: o.explanation.trim(), wrong_option_notes: notesRecord(o.wrong_option_notes, ids, source.key.correct), solution_steps: o.solution_steps.map((s) => s.trim()).filter(Boolean) },
    passage_order: null,
    pipeline: { batch_id: ctx.batchId, generated_by: `model:${ctx.model}`, prompt_version: PROMPT_VERSION, translated_from: source.id },
  };
}

export function translationRequest(source: BankItem, target: Language): { user: string; schema: Record<string, unknown> } {
  const q = source.question;
  const spec = {
    task: 'translate_item',
    from: LANGUAGE_NAMES[q.language],
    to: LANGUAGE_NAMES[target],
    item: {
      type: q.type,
      stem: q.type === 'quantitative_comparison' ? q.stem.replace(COMPARISON_INSTRUCTION[q.language] ?? '', '').trim() : q.stem,
      table_rows: q.table?.rows ?? [],
      options: q.type === 'quantitative_comparison' ? [] : q.options.map((o) => o.text),
      correct: source.key.correct,
      explanation: source.key.explanation,
      solution_steps: source.key.solution_steps,
      wrong_option_notes: Object.entries(source.key.wrong_option_notes).map(([option, note]) => ({ option, note })),
    },
    note: q.type === 'quantitative_comparison' ? 'stem holds only the condition (it may be empty): return only the translated condition in stem; translate the two column cells into table_rows; options are fixed by the blueprint, return an empty options list.' : undefined,
  };
  return { user: JSON.stringify(spec, null, 2), schema: translationSchema(OPTION_IDS.slice(0, Math.max(4, q.options.length))) };
}

export { TRANSLATION_SYSTEM };
