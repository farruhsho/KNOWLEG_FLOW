/**
 * Stage 3 — independent verification (opt-in, paid). A separate call solves
 * each item WITHOUT the key; the item passes only if the blind answer equals
 * the key, nothing blocks (ambiguity, several or no correct options, factual
 * errors, copyright risk), the language is acceptable, and — for maths with
 * plain arithmetic — the local exact checker agrees. Result: 'ai_verified'
 * or 'rejected' with notes. Nothing ever becomes methodologist_approved here.
 */
import { checkArithmetic, ArithmeticCheck } from './arith';
import { LlmClient } from './llm';
import { LANGUAGE_NAMES, VERIFY_SCHEMA, VERIFY_SYSTEM } from './prompts';
import { BankItem, BankPassage, Issue, OptionId, VerifyRecord } from './schema';
import { z } from 'zod';

export const VerifyOut = z.object({
  answer: z.string(),
  correct_options: z.array(z.string()),
  confidence: z.enum(['low', 'medium', 'high']),
  issues: z.array(z.object({ kind: z.string(), severity: z.enum(['blocker', 'major', 'minor']), note: z.string() })),
  language_quality: z.enum(['ok', 'minor_issues', 'poor']),
  solution: z.string(),
});
export type VerifyOut = z.infer<typeof VerifyOut>;

const BLOCKING_KINDS = new Set(['ambiguity', 'multiple_correct', 'no_correct', 'factual_error', 'copyright_risk', 'off_programme']);

/** The item as the blind solver sees it: no key, no explanation. */
export function verifyRequest(item: BankItem, passage: BankPassage | undefined): { user: string; schema: Record<string, unknown> } {
  const q = item.question;
  const spec = {
    task: 'solve_and_audit',
    language: LANGUAGE_NAMES[q.language],
    item_type: q.type,
    grades_hint: q.source.basis,
    passage: passage ? { title: passage.passage.title, text: passage.passage.text } : undefined,
    stem: q.stem,
    table: q.table ?? undefined,
    options: q.options,
  };
  return { user: JSON.stringify(spec, null, 2), schema: VERIFY_SCHEMA };
}

export interface Verdict {
  agrees: boolean;
  pass: boolean;
  reasons: string[];
}

export function decideVerdict(item: BankItem, out: VerifyOut, arith: ArithmeticCheck): Verdict {
  const reasons: string[] = [];
  const key = item.key.correct;
  const correctSet = new Set(out.correct_options.length ? out.correct_options : [out.answer]);
  const agrees = out.answer === key && correctSet.size === 1 && correctSet.has(key);
  if (!agrees) reasons.push(`blind answer ${out.answer}${correctSet.size > 1 ? ` (correct: ${[...correctSet].join(', ')})` : ''} ≠ key ${key}`);
  if (out.confidence === 'low') reasons.push('solver confidence is low');
  for (const i of out.issues) if (BLOCKING_KINDS.has(i.kind) && i.severity !== 'minor') reasons.push(`${i.kind} (${i.severity}): ${i.note}`);
  if (out.language_quality === 'poor') reasons.push('language quality is poor');
  if (arith.checked && arith.ok === false) reasons.push(`arithmetic check failed: ${arith.detail}`);
  return { agrees, pass: reasons.length === 0, reasons };
}

export async function verifyItem(item: BankItem, passage: BankPassage | undefined, llm: LlmClient, now: string): Promise<VerifyRecord> {
  const req = verifyRequest(item, passage);
  const res = await llm.complete({ purpose: 'verify', system: VERIFY_SYSTEM, user: req.user, schema: req.schema, maxTokens: 16000 });
  const out = VerifyOut.parse(res.json);
  return buildRecord(item, out, llm.model, now, res.usage);
}

export function buildRecord(item: BankItem, out: VerifyOut, model: string, now: string, usage: VerifyRecord['usage']): VerifyRecord {
  const arith = item.question.subject_id === 'math' ? checkArithmetic(item) : { checked: false, ok: null, detail: 'not a maths item' };
  const v = decideVerdict(item, out, arith);
  const status = item.question.review.status;
  const blind = (['A', 'B', 'C', 'D', 'E', 'NONE', 'MULTIPLE'] as const).find((x) => x === out.answer) ?? null;
  return {
    content_hash: item.question.content_hash,
    model,
    at: now,
    blind_answer: blind,
    correct_options: out.correct_options.filter((x): x is OptionId => ['A', 'B', 'C', 'D', 'E'].includes(x)),
    agrees: v.agrees,
    confidence: out.confidence,
    issues: out.issues.map((i) => ({ kind: (['ambiguity', 'multiple_correct', 'no_correct', 'factual_error', 'language_quality', 'off_programme', 'copyright_risk'].includes(i.kind) ? i.kind : 'other') as Issue['kind'], severity: i.severity, note: i.note })),
    language_quality: out.language_quality,
    arithmetic: arith,
    verdict: status === 'methodologist_approved' || status === 'rejected' ? 'unchanged' : v.pass ? 'ai_verified' : 'rejected',
    usage,
  };
}

/** Applies a verify record to the item. Approved and rejected items keep their status; the record still documents the check. */
export function applyVerifyRecord(item: BankItem, rec: VerifyRecord): void {
  item.pipeline.verify = rec;
  if (rec.verdict === 'unchanged') return;
  const arith = rec.arithmetic.checked ? ` arithmetic: ${rec.arithmetic.detail}.` : '';
  const issues = rec.issues.length ? ` Issues: ${rec.issues.map((i) => `${i.kind}/${i.severity}: ${i.note}`).join(' | ')}` : '';
  item.question.review = {
    status: rec.verdict,
    reviewed_by: null,
    reviewed_at: null,
    notes:
      rec.verdict === 'ai_verified'
        ? `AI check (${rec.model}, ${rec.at}): blind answer matches key, confidence ${rec.confidence}.${arith}${issues}`
        : `AI check (${rec.model}, ${rec.at}) REJECTED: blind ${rec.blind_answer ?? '—'} vs key; confidence ${rec.confidence}; language ${rec.language_quality}.${arith}${issues}`,
  };
  item.question.updated_at = rec.at;
}

/** Items that still need a verify pass (new or edited since the last check). */
export function needsVerify(item: BankItem, force: boolean): boolean {
  if (item.question.review.status === 'rejected' && !force) return false;
  if (force) return true;
  return !item.pipeline.verify || item.pipeline.verify.content_hash !== item.question.content_hash;
}
