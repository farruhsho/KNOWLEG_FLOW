/**
 * Stage 4 — translation consistency for items that share a
 * translation_group_id (ru ↔ ky). Structural checks are free and always run;
 * the bilingual meaning/quality check is an opt-in paid call.
 */
import { LlmClient } from './llm';
import { LANGUAGE_NAMES, TRANSLATE_CHECK_SCHEMA, TRANSLATE_CHECK_SYSTEM } from './prompts';
import { BankItem, BankPassage, TranslateCheckRecord } from './schema';
import { z } from 'zod';

const numbersOf = (s: string): string[] => (s.match(/\d+(?:[.,]\d+)?/g) ?? []).map((n) => n.replace(',', '.'));
const latexOf = (s: string): string[] => [...s.matchAll(/\$([^$]+)\$/g)].map((m) => m[1]!.replace(/\s+/g, ''));
const sortedEq = (a: string[], b: string[]): boolean => a.length === b.length && [...a].sort().every((x, i) => x === [...b].sort()[i]);

function publicText(it: BankItem): string {
  const q = it.question;
  return [q.stem, ...q.options.map((o) => o.text), ...(q.table ? q.table.rows.flat() : [])].join(' \n ');
}

/** Structural differences between two language versions of one item. */
export function structuralProblems(a: BankItem, b: BankItem, passages: Map<string, BankPassage>): string[] {
  const p: string[] = [];
  const qa = a.question;
  const qb = b.question;
  if (qa.type !== qb.type) p.push(`type ${qa.type} ≠ ${qb.type}`);
  if (qa.options.length !== qb.options.length) p.push(`options count ${qa.options.length} ≠ ${qb.options.length}`);
  if (a.key.correct !== b.key.correct) p.push(`key ${a.key.correct} ≠ ${b.key.correct}`);
  if (qa.difficulty !== qb.difficulty) p.push(`difficulty ${qa.difficulty} ≠ ${qb.difficulty}`);
  if (qa.topic_id !== qb.topic_id) p.push(`topic ${qa.topic_id} ≠ ${qb.topic_id}`);
  if (`${a.target.blueprint_id}/${a.target.section_id}/${a.target.part_id}` !== `${b.target.blueprint_id}/${b.target.section_id}/${b.target.part_id}`) p.push('different blueprint slot');
  const shape = (t: BankItem['question']['table']): string => (t ? `${t.rows.length}x${t.headers.length}` : 'none');
  if (shape(qa.table) !== shape(qb.table)) p.push(`table ${shape(qa.table)} ≠ ${shape(qb.table)}`);
  if (!sortedEq(numbersOf(publicText(a)), numbersOf(publicText(b)))) p.push(`numbers differ: [${numbersOf(publicText(a)).join(' ')}] vs [${numbersOf(publicText(b)).join(' ')}]`);
  if (!sortedEq(latexOf(publicText(a)), latexOf(publicText(b)))) p.push('formulas ($…$) differ');
  if ((qa.passage_id === null) !== (qb.passage_id === null)) p.push('only one version has a passage');
  if (qa.passage_id && qb.passage_id) {
    const pa = passages.get(qa.passage_id);
    const pb = passages.get(qb.passage_id);
    if (!pa || !pb) p.push('passage missing');
    else if (!pa.translation_group_id || pa.translation_group_id !== pb.translation_group_id) p.push('passages are not translations of each other');
  }
  return p;
}

export interface TranslationPair {
  a: BankItem;
  b: BankItem;
}

/** ru ↔ ky pairs (any two languages) inside each translation group. */
export function translationPairs(items: BankItem[]): TranslationPair[] {
  const groups = new Map<string, BankItem[]>();
  for (const it of items) {
    const tg = it.question.translation_group_id;
    if (tg) groups.set(tg, [...(groups.get(tg) ?? []), it]);
  }
  const pairs: TranslationPair[] = [];
  for (const g of groups.values()) {
    const sorted = [...g].sort((x, y) => x.question.created_at.localeCompare(y.question.created_at) || x.id.localeCompare(y.id));
    for (let i = 0; i < sorted.length; i++) for (let j = i + 1; j < sorted.length; j++) if (sorted[i]!.question.language !== sorted[j]!.question.language) pairs.push({ a: sorted[i]!, b: sorted[j]! });
  }
  return pairs;
}

const CheckOut = z.object({
  equivalent: z.boolean(),
  target_language_quality: z.enum(['ok', 'minor_issues', 'poor']),
  issues: z.array(z.object({ field: z.string(), severity: z.enum(['blocker', 'major', 'minor']), note: z.string() })),
});

function itemView(it: BankItem, passages: Map<string, BankPassage>): Record<string, unknown> {
  const q = it.question;
  const p = q.passage_id ? passages.get(q.passage_id) : undefined;
  return {
    language: LANGUAGE_NAMES[q.language],
    passage: p ? { title: p.passage.title, text: p.passage.text } : undefined,
    stem: q.stem,
    table: q.table ?? undefined,
    options: q.options,
    correct: it.key.correct,
    explanation: it.key.explanation,
    wrong_option_notes: it.key.wrong_option_notes,
  };
}

export async function apiCheck(pair: TranslationPair, passages: Map<string, BankPassage>, llm: LlmClient): Promise<NonNullable<TranslateCheckRecord['api']>> {
  const user = JSON.stringify({ task: 'compare_translations', source: itemView(pair.a, passages), target: itemView(pair.b, passages) }, null, 2);
  const res = await llm.complete({ purpose: 'translate_check', system: TRANSLATE_CHECK_SYSTEM, user, schema: TRANSLATE_CHECK_SCHEMA, maxTokens: 16000 });
  const out = CheckOut.parse(res.json);
  return { model: llm.model, equivalent: out.equivalent, target_language_quality: out.target_language_quality, issues: out.issues, usage: res.usage };
}

export function pairRecord(pair: TranslationPair, structural: string[], api: TranslateCheckRecord['api'], now: string, self: BankItem): TranslateCheckRecord {
  const apiFailed = api !== null && (!api.equivalent || api.target_language_quality === 'poor' || api.issues.some((i) => i.severity !== 'minor'));
  return {
    at: now,
    counterpart_ids: [self.id === pair.a.id ? pair.b.id : pair.a.id],
    structural_ok: structural.length === 0,
    structural_problems: structural,
    api,
    status: structural.length === 0 && !apiFailed ? 'passed' : 'failed',
  };
}

/** Merges a pair result into an item's record (an item can be in several pairs). A failure anywhere stays a failure. */
export function mergeRecord(prev: TranslateCheckRecord | undefined, next: TranslateCheckRecord): TranslateCheckRecord {
  if (!prev || prev.at !== next.at) return next;
  return {
    at: next.at,
    counterpart_ids: [...new Set([...prev.counterpart_ids, ...next.counterpart_ids])],
    structural_ok: prev.structural_ok && next.structural_ok,
    structural_problems: [...prev.structural_problems, ...next.structural_problems],
    api: next.api ?? prev.api,
    status: prev.status === 'failed' || next.status === 'failed' ? 'failed' : 'passed',
  };
}
