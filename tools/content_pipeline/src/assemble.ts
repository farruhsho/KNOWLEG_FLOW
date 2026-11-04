/**
 * Stage 6 — assembly. Builds one exam variant for blueprint × language from
 * eligible bank items so every section/part matches the blueprint exactly:
 * question counts, the topic matrix (exact cells → exact totals → ranges),
 * the difficulty mix (exact outside passage parts), and the passage layout
 * (e.g. reading: 2 standalone texts + 1 paired, ~10 questions each).
 * Items are never reused across variants of the same blueprint + language
 * unless `allowReuse` is set.
 */
import { Blueprint, sectionsInOrder } from './blueprints';
import { isAssemblyEligible } from './bank';
import { isDedupExcluded } from './dedup';
import { boundedMatrix } from './flow';
import { seededKey } from './io';
import { BlueprintMatrix, dkey, DifficultyCounts, languageMatrix, PartMatrix } from './matrix';
import { BankItem, BankPassage, DIFFICULTIES, ExamVariant, Language, REVIEW_RANK, VariantFile } from './schema';

export interface AssembleInput {
  blueprint: Blueprint;
  matrix: BlueprintMatrix;
  language: Language;
  number: number;
  items: BankItem[];
  passages: Map<string, BankPassage>;
  /** Question/passage ids already used by other variants of this blueprint + language. */
  usedQuestionIds: Set<string>;
  usedPassageIds: Set<string>;
  allowUnapproved: boolean;
  allowReuse: boolean;
  seed: string;
  now: string;
}

export type FitTier = 'exact_cells' | 'exact_totals' | 'topic_ranges' | 'difficulty_tolerance' | 'passages';

/**
 * In parts that mix passage groups and standalone items, the passage groups
 * cannot be split freely, so the standalone remainder may miss the exact
 * difficulty columns; it may then deviate by this much per level (the same
 * tolerance validateVariant applies to passage parts).
 */
export const PASSAGE_DIFFICULTY_TOLERANCE = 2;

export interface AssembleResult {
  ok: boolean;
  file?: VariantFile;
  problems: string[];
  fit: Record<string, FitTier>;
}

export const variantIdFor = (blueprintId: string, language: string, n: number): string => `v_${blueprintId}_${language}_${String(n).padStart(3, '0')}`;

export function variantTitle(n: number): ExamVariant['title'] {
  return { ru: `Вариант ${n}`, ky: `${n}-вариант`, en: `Variant ${n}` };
}

interface PartContext {
  input: AssembleInput;
  part: PartMatrix;
  selected: Set<string>;
  problems: string[];
  selectedTier?: FitTier;
}

function preference(input: AssembleInput) {
  return (a: BankItem, b: BankItem): number => {
    const ua = input.usedQuestionIds.has(a.id) ? 1 : 0;
    const ub = input.usedQuestionIds.has(b.id) ? 1 : 0;
    return (
      ua - ub ||
      REVIEW_RANK[b.question.review.status] - REVIEW_RANK[a.question.review.status] ||
      seededKey(input.seed, a.id).localeCompare(seededKey(input.seed, b.id))
    );
  };
}

function eligibleForPart(ctx: PartContext): BankItem[] {
  const { input, part } = ctx;
  return input.items.filter((it) => {
    if (`${it.target.blueprint_id}/${it.target.section_id}/${it.target.part_id}` !== part.slot) return false;
    if (it.question.language !== input.language) return false;
    if (!isAssemblyEligible(it, input.allowUnapproved)) return false;
    if (isDedupExcluded(it)) return false;
    if (it.pipeline.translate_check?.status === 'failed') return false;
    if (!input.allowReuse && input.usedQuestionIds.has(it.id)) return false;
    if (it.question.passage_id && !input.allowReuse && input.usedPassageIds.has(it.question.passage_id)) return false;
    return !ctx.selected.has(it.id);
  });
}

const zeroCounts = (): DifficultyCounts => ({ '1': 0, '2': 0, '3': 0 });

/** Picks passage groups; returns ordered item ids per group, or null with a problem. */
function pickPassageGroups(ctx: PartContext, pool: BankItem[]): { groups: BankItem[][]; counts: DifficultyCounts } | null {
  const { input, part } = ctx;
  const plan = part.passage_plan!;
  const perText = plan.questions_per_text;
  const byPassage = new Map<string, BankItem[]>();
  for (const it of pool) {
    const pid = it.question.passage_id;
    if (!pid) continue;
    byPassage.set(pid, [...(byPassage.get(pid) ?? []), it]);
  }
  const pref = preference(input);
  const candidates = [...byPassage.entries()]
    .map(([pid, items]) => ({ pid, items: items.sort((a, b) => (a.passage_order ?? 0) - (b.passage_order ?? 0)), passage: input.passages.get(pid) }))
    .filter((c) => c.passage && c.items.length >= Math.max(1, perText - 2))
    .sort((a, b) => {
      const ra = a.items.reduce((s, x) => s + REVIEW_RANK[x.question.review.status], 0) / a.items.length;
      const rb = b.items.reduce((s, x) => s + REVIEW_RANK[x.question.review.status], 0) / b.items.length;
      return rb - ra || b.items.length - a.items.length || seededKey(input.seed, a.pid).localeCompare(seededKey(input.seed, b.pid));
    });
  const standalone = candidates.filter((c) => c.passage!.layout === 'standalone').slice(0, plan.standalone_texts);
  const paired = candidates.filter((c) => c.passage!.layout === 'paired').slice(0, plan.paired_texts);
  if (standalone.length < plan.standalone_texts || paired.length < plan.paired_texts) {
    ctx.problems.push(
      `${part.slot}: need ${plan.standalone_texts} standalone + ${plan.paired_texts} paired passages with ≥ ${Math.max(1, perText - 2)} eligible questions; found ${standalone.length} + ${paired.length}`,
    );
    return null;
  }
  const chosen = [...standalone, ...paired];
  const need = chosen.length * perText;
  const counts = chosen.map((c) => Math.min(c.items.length, perText));
  let deficit = need - counts.reduce((a, b) => a + b, 0);
  for (let round = 0; deficit > 0 && round < 2; round++) {
    for (let i = 0; i < chosen.length && deficit > 0; i++) {
      if (counts[i]! < chosen[i]!.items.length && counts[i]! < perText + 2) {
        counts[i]!++;
        deficit--;
      }
    }
  }
  if (deficit > 0) {
    ctx.problems.push(`${part.slot}: chosen passages hold ${need - deficit} eligible questions, need ${need}`);
    return null;
  }
  // Within a passage keep the difficulty spread close to the part's mix.
  const mixTotal = part.question_count || 1;
  const groups: BankItem[][] = [];
  const total = zeroCounts();
  chosen.forEach((c, i) => {
    const n = counts[i]!;
    let picked: BankItem[];
    if (c.items.length <= n) picked = c.items;
    else {
      const desire: DifficultyCounts = {
        '1': Math.round((n * part.difficulty_counts['1']) / mixTotal),
        '2': Math.round((n * part.difficulty_counts['2']) / mixTotal),
        '3': Math.round((n * part.difficulty_counts['3']) / mixTotal),
      };
      const have = zeroCounts();
      const ranked = [...c.items].sort(pref);
      picked = [];
      for (const it of ranked) {
        const k = dkey(it.question.difficulty);
        if (picked.length < n && have[k] < desire[k]) {
          picked.push(it);
          have[k]++;
        }
      }
      for (const it of ranked) if (picked.length < n && !picked.includes(it)) picked.push(it);
      picked.sort((a, b) => (a.passage_order ?? 0) - (b.passage_order ?? 0));
    }
    for (const it of picked) total[dkey(it.question.difficulty)]++;
    groups.push(picked);
  });
  return { groups, counts: total };
}

/** Chooses standalone items for one part with the flow tiers; returns them in easy→hard order. */
function pickStandalone(
  ctx: PartContext,
  pool: BankItem[],
  count: number,
  diffTarget: DifficultyCounts | null,
  topicAdjust: Map<string, number>,
  diffTolerance = 0,
): BankItem[] | null {
  const { input, part } = ctx;
  if (count === 0) return [];
  const topics = part.topics;
  const standalonePool = pool.filter((it) => it.question.passage_id === null);
  const cell = new Map<string, BankItem[]>();
  for (const it of standalonePool) {
    const k = `${it.question.topic_id}|${it.question.difficulty}`;
    cell.set(k, [...(cell.get(k) ?? []), it]);
  }
  const avail = topics.map((t) => DIFFICULTIES.map((d) => cell.get(`${t.topic_id}|${d}`)?.length ?? 0));
  const exactCols = diffTarget ? DIFFICULTIES.map((d) => ({ lo: diffTarget[dkey(d)], hi: diffTarget[dkey(d)] })) : null;
  const looseCols = DIFFICULTIES.map(() => ({ lo: 0, hi: count }));
  const tiers: Array<{ tier: FitTier; rows: Array<{ lo: number; hi: number }>; cols: Array<{ lo: number; hi: number }>; lo: number[][]; hi: number[][] }> = [];
  const adj = (t: string): number => topicAdjust.get(t) ?? 0;
  if (exactCols && topicAdjust.size === 0) {
    tiers.push({
      tier: 'exact_cells',
      rows: topics.map((t) => ({ lo: t.target, hi: t.target })),
      cols: exactCols,
      lo: topics.map((t) => DIFFICULTIES.map((d) => t.difficulty_targets[dkey(d)])),
      hi: topics.map((t) => DIFFICULTIES.map((d) => t.difficulty_targets[dkey(d)])),
    });
    tiers.push({ tier: 'exact_totals', rows: topics.map((t) => ({ lo: t.target, hi: t.target })), cols: exactCols, lo: avail.map((r) => r.map(() => 0)), hi: avail });
  }
  tiers.push({
    tier: 'topic_ranges',
    rows: topics.map((t) => ({ lo: Math.max(0, t.min - adj(t.topic_id)), hi: Math.max(0, t.max - adj(t.topic_id)) })),
    cols: exactCols ?? looseCols,
    lo: avail.map((r) => r.map(() => 0)),
    hi: avail,
  });
  if (exactCols && diffTolerance > 0) {
    tiers.push({
      tier: 'difficulty_tolerance',
      rows: topics.map((t) => ({ lo: Math.max(0, t.min - adj(t.topic_id)), hi: Math.max(0, t.max - adj(t.topic_id)) })),
      cols: exactCols.map((c) => ({ lo: Math.max(0, c.lo - diffTolerance), hi: c.hi + diffTolerance })),
      lo: avail.map((r) => r.map(() => 0)),
      hi: avail,
    });
  }
  for (const tier of tiers) {
    const feasibleCells = tier.lo.every((r, i) => r.every((lo, j) => lo <= avail[i]![j]!));
    if (!feasibleCells) continue;
    const x = boundedMatrix(tier.rows, tier.cols, tier.lo, tier.hi.map((r, i) => r.map((h, j) => Math.min(h, avail[i]![j]!))), count);
    if (!x) continue;
    const pref = preference(input);
    const picked: BankItem[] = [];
    topics.forEach((t, i) => {
      DIFFICULTIES.forEach((d, j) => {
        const n = x[i]![j]!;
        if (n > 0) picked.push(...[...(cell.get(`${t.topic_id}|${d}`) ?? [])].sort(pref).slice(0, n));
      });
    });
    ctx.selectedTier = tier.tier;
    const order = new Map(topics.map((t, i) => [t.topic_id, i]));
    return picked.sort(
      (a, b) =>
        a.question.difficulty - b.question.difficulty ||
        (order.get(a.question.topic_id) ?? 0) - (order.get(b.question.topic_id) ?? 0) ||
        seededKey(input.seed, a.id).localeCompare(seededKey(input.seed, b.id)),
    );
  }
  const have = avail.map((r, i) => `${topics[i]!.topic_id}:${r.join('/')}`).join(', ');
  ctx.problems.push(`${part.slot}: cannot pick ${count} standalone items matching the matrix (available per topic d1/d2/d3: ${have || 'none'})`);
  return null;
}

export function assembleVariant(input: AssembleInput): AssembleResult {
  const problems: string[] = [];
  const fit: Record<string, FitTier> = {};
  const lm = languageMatrix(input.matrix, input.language);
  if (input.matrix.blueprint_version !== input.blueprint.version) {
    problems.push(`matrix is for v${input.matrix.blueprint_version}, blueprint is v${input.blueprint.version}: re-run the matrix stage`);
    return { ok: false, problems, fit };
  }
  const selected = new Set<string>();
  const sections: ExamVariant['sections'] = [];
  for (const bs of sectionsInOrder(input.blueprint)) {
    const sm = lm.sections.find((s) => s.section_id === bs.id);
    if (!sm) {
      problems.push(`${bs.id}: missing from matrix`);
      continue;
    }
    const ids: string[] = [];
    for (const part of sm.parts) {
      const ctx: PartContext = { input, part, selected, problems };
      const pool = eligibleForPart(ctx);
      let passageItems: BankItem[][] = [];
      let passageCounts = zeroCounts();
      const plan = part.passage_plan;
      const passageQuestions = plan ? (plan.standalone_texts + plan.paired_texts) * plan.questions_per_text : 0;
      if (plan && passageQuestions > 0) {
        const res = pickPassageGroups(ctx, pool);
        if (!res) continue;
        passageItems = res.groups;
        passageCounts = res.counts;
        fit[part.slot] = 'passages';
      }
      const remainder = part.question_count - passageQuestions;
      let standalone: BankItem[] | null = [];
      if (remainder > 0) {
        const topicAdjust = new Map<string, number>();
        for (const it of passageItems.flat()) topicAdjust.set(it.question.topic_id, (topicAdjust.get(it.question.topic_id) ?? 0) + 1);
        let diffTarget: DifficultyCounts | null = part.difficulty_counts;
        if (passageQuestions > 0) {
          const adjusted: DifficultyCounts = {
            '1': part.difficulty_counts['1'] - passageCounts['1'],
            '2': part.difficulty_counts['2'] - passageCounts['2'],
            '3': part.difficulty_counts['3'] - passageCounts['3'],
          };
          const ok = Object.values(adjusted).every((v) => v >= 0) && adjusted['1'] + adjusted['2'] + adjusted['3'] === remainder;
          diffTarget = ok ? adjusted : null;
        }
        standalone = pickStandalone(ctx, pool, remainder, diffTarget, topicAdjust, passageQuestions > 0 ? PASSAGE_DIFFICULTY_TOLERANCE : 0);
        if (!standalone) continue;
        if (!plan || passageQuestions === 0) fit[part.slot] = ctx.selectedTier ?? 'topic_ranges';
      }
      const ordered = [...standalone, ...passageItems.flat()];
      for (const it of ordered) {
        selected.add(it.id);
        ids.push(it.id);
      }
    }
    sections.push({ section_id: bs.id, question_ids: ids });
    if (ids.length !== bs.question_count) problems.push(`${bs.id}: assembled ${ids.length} of ${bs.question_count}`);
  }
  if (problems.length) return { ok: false, problems, fit };

  const chosen = input.items.filter((it) => selected.has(it.id));
  const statusSummary: Record<string, number> = {};
  for (const it of chosen) statusSummary[it.question.review.status] = (statusSummary[it.question.review.status] ?? 0) + 1;
  const variant: ExamVariant = {
    blueprint_id: input.blueprint.id,
    blueprint_version: input.blueprint.version,
    number: input.number,
    title: variantTitle(input.number),
    language: input.language,
    status: 'draft',
    sections,
    content_version: 1,
    difficulty_label: 'standard',
    created_by: 'pipeline',
    published_at: null,
    published_by: null,
    stats: { attempts: 0, avg_percent: 0 },
  };
  return {
    ok: true,
    problems,
    fit,
    file: {
      id: variantIdFor(input.blueprint.id, input.language, input.number),
      variant,
      assembly: {
        assembled_at: input.now,
        seed: input.seed,
        allow_unapproved: input.allowUnapproved,
        allow_reuse: input.allowReuse,
        matrix_fit: fit,
        review_status_summary: statusSummary,
      },
    },
  };
}

/** Question and passage ids used by a list of variant files (for the no-reuse rule). */
export function usedIds(files: VariantFile[], items: Map<string, BankItem>): { questions: Set<string>; passages: Set<string> } {
  const questions = new Set<string>();
  const passages = new Set<string>();
  for (const f of files) {
    if (f.variant.status === 'archived') continue;
    for (const s of f.variant.sections) {
      for (const id of s.question_ids) {
        questions.add(id);
        const pid = items.get(id)?.question.passage_id;
        if (pid) passages.add(pid);
      }
    }
  }
  return { questions, passages };
}
