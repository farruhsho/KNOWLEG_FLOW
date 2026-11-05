/**
 * Fresh-variant assembly (ARCHITECTURE §10.1): a pure port of the content
 * pipeline's stage 6 (tools/content_pipeline/src/assemble.ts) working on
 * the server's view of the bank (exam_questions documents).
 *
 * Every part of every section gets exactly its question count and matches
 * the topic matrix with the pipeline's tiers (exact topic × difficulty cells
 * → exact topic totals → topic [min, max] ranges; exact difficulty counts in
 * all three, with a ±2 tolerance only for the standalone remainder of parts
 * that mix passages and standalone items) and the passage layout (e.g.
 * reading: 2 standalone texts + 1 paired, 10 questions each).
 *
 * Differences from the pipeline (all owner decisions of §10.1):
 *  - "used" items are not excluded, they are de-prioritised: per part the
 *    assembly first tries with items (and passages) the user has never seen;
 *    only if that cannot fill the part it allows seen items, least recently
 *    seen first (`lastSeen` = time of the most recent attempt containing the
 *    item). Freshness wins over the matrix tier: every tier is a valid ORT
 *    structure, a repeat is not a new variant.
 *  - Order inside a part: standalone items from easy to hard (difficulty
 *    ascending, seeded tie-break), then the passage groups — standalone texts
 *    (easier first) before paired ones — each in text order (passage_order).
 *  - Items whose topic is not in the part's matrix are never used.
 *  - Passages without a stored `layout` may fill either kind of text slot,
 *    after the passages whose layout is known.
 *
 * Deterministic: the same pool (as a set), seen map and seed give the same
 * variant.
 */
import { sha256Hex } from './hash';
import { boundedMatrix } from './flow';
import {
  DIFFICULTIES,
  dkey,
  slotKey,
  zeroCounts,
  type AssemblySection,
  type DifficultyCounts,
  type PartMatrix,
} from './exam_matrix';

export const REVIEW_STATUSES = ['draft', 'ai_verified', 'methodologist_approved'] as const;
export type PoolReviewStatus = (typeof REVIEW_STATUSES)[number];

/** Ordering of review statuses (`rejected` is outside the chain and never in a pool). */
export const REVIEW_RANK: Readonly<Record<string, number>> = Object.freeze({
  rejected: -1,
  draft: 0,
  ai_verified: 1,
  methodologist_approved: 2,
});

export function reviewRank(status: string): number {
  return REVIEW_RANK[status] ?? -1;
}

/** Statuses accepted by the pool for a configured minimum (`config/exam_pool.min_review_status`). */
export function statusesAtLeast(min: string): PoolReviewStatus[] {
  const floor = reviewRank(min);
  return REVIEW_STATUSES.filter((s) => reviewRank(s) >= Math.max(floor, 1));
}

export interface PoolItem {
  id: string;
  section_id: string;
  part_id: string;
  topic_id: string;
  difficulty: number;
  passage_id: string | null;
  /** Position of the question in its passage (text order); null = unknown. */
  passage_order: number | null;
  review_status: string;
}

export type PassageLayout = 'standalone' | 'paired' | 'unknown';

export interface PoolPassage {
  id: string;
  layout: PassageLayout;
}

export type FitTier = 'exact_cells' | 'exact_totals' | 'topic_ranges' | 'difficulty_tolerance' | 'passages';

/**
 * In parts that mix passage groups and standalone items, the passage groups
 * cannot be split freely, so the standalone remainder may miss the exact
 * difficulty columns by this much per level (as in the pipeline).
 */
export const PASSAGE_DIFFICULTY_TOLERANCE = 2;

export interface AssembleFreshInput {
  /** Blueprint sections in exam order. */
  sections: readonly AssemblySection[];
  /** Part matrices of the variant's language keyed by `section/part`. */
  matrix: ReadonlyMap<string, PartMatrix>;
  /** Eligible bank items (status, key and passage checks already applied). */
  pool: readonly PoolItem[];
  passages: ReadonlyMap<string, PoolPassage>;
  /** questionId -> epoch ms of the most recent attempt of the user containing it. */
  lastSeen: ReadonlyMap<string, number>;
  seed: string;
}

export interface Freshness {
  total: number;
  repeated: number;
}

export type AssembleFreshResult =
  | {
      ok: true;
      sections: Array<{ section_id: string; question_ids: string[] }>;
      freshness: Freshness;
      fit: Record<string, FitTier>;
      /** Parts that needed already-seen items. */
      repeated_parts: string[];
    }
  | { ok: false; section_id: string; part_id: string; problems: string[] };

type Mode = 'fresh_only' | 'with_repeats';

interface PartRun {
  part: PartMatrix;
  /** Slot items with a matrix topic, sorted by id. */
  pool: PoolItem[];
  passages: ReadonlyMap<string, PoolPassage>;
  lastSeen: ReadonlyMap<string, number>;
  keyOf: (id: string) => string;
  mode: Mode;
  problems: string[];
}

type PartOutcome = { items: PoolItem[]; tier: FitTier } | null;

function seededKeys(seed: string): (id: string) => string {
  const cache = new Map<string, string>();
  return (id) => {
    let k = cache.get(id);
    if (k === undefined) {
      k = sha256Hex(`${seed}|${id}`);
      cache.set(id, k);
    }
    return k;
  };
}

/** unseen first, then least recently seen, then higher review status, then the seeded key. */
function preference(run: PartRun) {
  return (a: PoolItem, b: PoolItem): number => {
    const sa = run.lastSeen.get(a.id);
    const sb = run.lastSeen.get(b.id);
    return (
      (sa === undefined ? 0 : 1) - (sb === undefined ? 0 : 1) ||
      (sa ?? 0) - (sb ?? 0) ||
      reviewRank(b.review_status) - reviewRank(a.review_status) ||
      run.keyOf(a.id).localeCompare(run.keyOf(b.id))
    );
  };
}

function difficultyOf(it: PoolItem): number {
  return it.difficulty;
}

/** Text order inside a passage (passage_order, then difficulty, then the seeded key). */
function textOrder(run: PartRun) {
  return (a: PoolItem, b: PoolItem): number =>
    (a.passage_order ?? Number.MAX_SAFE_INTEGER) - (b.passage_order ?? Number.MAX_SAFE_INTEGER) ||
    a.difficulty - b.difficulty ||
    run.keyOf(a.id).localeCompare(run.keyOf(b.id));
}

interface PassageCandidate {
  pid: string;
  layout: PassageLayout;
  items: PoolItem[];
  /** Most recent time any item of the passage was seen (0 = never). */
  seenAt: number;
  rank: number;
}

/** Picks passage groups; returns the groups in exam order with their difficulty counts, or null. */
function pickPassageGroups(run: PartRun, pool: PoolItem[]): { groups: PoolItem[][]; counts: DifficultyCounts } | null {
  const { part } = run;
  const plan = part.passage_plan!;
  const perText = plan.questions_per_text;
  const minItems = Math.max(1, perText - 2);
  const byPassage = new Map<string, PoolItem[]>();
  for (const it of pool) {
    if (!it.passage_id || !run.passages.has(it.passage_id)) continue;
    const list = byPassage.get(it.passage_id);
    if (list) list.push(it);
    else byPassage.set(it.passage_id, [it]);
  }
  const order = textOrder(run);
  const candidates: PassageCandidate[] = [...byPassage.entries()]
    .map(([pid, items]) => ({
      pid,
      layout: run.passages.get(pid)!.layout,
      items: [...items].sort(order),
      seenAt: items.reduce((m, x) => Math.max(m, run.lastSeen.get(x.id) ?? 0), 0),
      rank: items.reduce((s, x) => s + reviewRank(x.review_status), 0) / items.length,
    }))
    .filter((c) => c.items.length >= minItems)
    .sort((a, b) => a.seenAt - b.seenAt || b.rank - a.rank || b.items.length - a.items.length || run.keyOf(a.pid).localeCompare(run.keyOf(b.pid)));

  const take = (layout: 'standalone' | 'paired', n: number, exclude: Set<string>): PassageCandidate[] => {
    const known = candidates.filter((c) => c.layout === layout && !exclude.has(c.pid));
    const unknown = candidates.filter((c) => c.layout === 'unknown' && !exclude.has(c.pid));
    return [...known, ...unknown].slice(0, n);
  };
  const paired = take('paired', plan.paired_texts, new Set());
  const standalone = take('standalone', plan.standalone_texts, new Set(paired.map((c) => c.pid)));
  if (standalone.length < plan.standalone_texts || paired.length < plan.paired_texts) {
    run.problems.push(
      `${part.slot}: need ${plan.standalone_texts} standalone + ${plan.paired_texts} paired passages with ≥ ${minItems} eligible questions; found ${standalone.length} + ${paired.length}`,
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
    run.problems.push(`${part.slot}: chosen passages hold ${need - deficit} eligible questions, need ${need}`);
    return null;
  }
  // Within a passage keep the difficulty spread close to the part's mix.
  const mixTotal = part.question_count || 1;
  const pref = preference(run);
  const total = zeroCounts();
  const picked = chosen.map((c, i) => {
    const n = counts[i]!;
    if (c.items.length <= n) return c.items;
    const desire: DifficultyCounts = {
      '1': Math.round((n * part.difficulty_counts['1']) / mixTotal),
      '2': Math.round((n * part.difficulty_counts['2']) / mixTotal),
      '3': Math.round((n * part.difficulty_counts['3']) / mixTotal),
    };
    const have = zeroCounts();
    const ranked = [...c.items].sort(pref);
    const out: PoolItem[] = [];
    for (const it of ranked) {
      const k = dkey(it.difficulty);
      if (out.length < n && have[k] < desire[k]) {
        out.push(it);
        have[k]++;
      }
    }
    for (const it of ranked) if (out.length < n && !out.includes(it)) out.push(it);
    return out.sort(order);
  });
  picked.flat().forEach((it) => total[dkey(it.difficulty)]++);
  // Exam order: standalone texts (easier first), then paired texts.
  const meanDifficulty = (items: PoolItem[]): number => items.reduce((s, x) => s + x.difficulty, 0) / Math.max(1, items.length);
  const groups = chosen
    .map((c, i) => ({ c, items: picked[i]!, paired: i >= standalone.length }))
    .sort(
      (a, b) =>
        Number(a.paired) - Number(b.paired) ||
        meanDifficulty(a.items) - meanDifficulty(b.items) ||
        run.keyOf(a.c.pid).localeCompare(run.keyOf(b.c.pid)),
    )
    .map((g) => g.items);
  return { groups, counts: total };
}

interface Tier {
  tier: FitTier;
  rows: Array<{ lo: number; hi: number }>;
  cols: Array<{ lo: number; hi: number }>;
  lo: number[][];
  hi: number[][];
}

/** Chooses standalone items for one part with the flow tiers; returns them easy → hard. */
function pickStandalone(
  run: PartRun,
  pool: PoolItem[],
  count: number,
  diffTarget: DifficultyCounts | null,
  topicAdjust: Map<string, number>,
  diffTolerance: number,
): { items: PoolItem[]; tier: FitTier } | null {
  const { part } = run;
  if (count === 0) return { items: [], tier: 'exact_cells' };
  const topics = part.topics;
  const cell = new Map<string, PoolItem[]>();
  for (const it of pool) {
    if (it.passage_id !== null) continue;
    const k = `${it.topic_id}|${it.difficulty}`;
    const list = cell.get(k);
    if (list) list.push(it);
    else cell.set(k, [it]);
  }
  const avail = topics.map((t) => DIFFICULTIES.map((d) => cell.get(`${t.topic_id}|${d}`)?.length ?? 0));
  const zeros = avail.map((r) => r.map(() => 0));
  const exactCols = diffTarget ? DIFFICULTIES.map((d) => ({ lo: diffTarget[dkey(d)], hi: diffTarget[dkey(d)] })) : null;
  const looseCols = DIFFICULTIES.map(() => ({ lo: 0, hi: count }));
  const adj = (t: string): number => topicAdjust.get(t) ?? 0;
  const rangeRows = topics.map((t) => ({ lo: Math.max(0, t.min - adj(t.topic_id)), hi: Math.max(0, t.max - adj(t.topic_id)) }));
  const tiers: Tier[] = [];
  if (exactCols && topicAdjust.size === 0) {
    const exactRows = topics.map((t) => ({ lo: t.target, hi: t.target }));
    const cells = topics.map((t) => DIFFICULTIES.map((d) => t.difficulty_targets[dkey(d)]));
    tiers.push({ tier: 'exact_cells', rows: exactRows, cols: exactCols, lo: cells, hi: cells });
    tiers.push({ tier: 'exact_totals', rows: exactRows, cols: exactCols, lo: zeros, hi: avail });
  }
  tiers.push({ tier: 'topic_ranges', rows: rangeRows, cols: exactCols ?? looseCols, lo: zeros, hi: avail });
  if (exactCols && diffTolerance > 0) {
    tiers.push({
      tier: 'difficulty_tolerance',
      rows: rangeRows,
      cols: exactCols.map((c) => ({ lo: Math.max(0, c.lo - diffTolerance), hi: c.hi + diffTolerance })),
      lo: zeros,
      hi: avail,
    });
  }
  const pref = preference(run);
  for (const tier of tiers) {
    const feasibleCells = tier.lo.every((r, i) => r.every((lo, j) => lo <= avail[i]![j]!));
    if (!feasibleCells) continue;
    const hi = tier.hi.map((r, i) => r.map((h, j) => Math.min(h, avail[i]![j]!)));
    const x = boundedMatrix(tier.rows, tier.cols, tier.lo, hi, count);
    if (!x) continue;
    const picked: PoolItem[] = [];
    topics.forEach((t, i) => {
      DIFFICULTIES.forEach((d, j) => {
        const n = x[i]![j]!;
        if (n > 0) picked.push(...[...(cell.get(`${t.topic_id}|${d}`) ?? [])].sort(pref).slice(0, n));
      });
    });
    // Easy → hard; the seeded key mixes topics within a difficulty level.
    picked.sort((a, b) => difficultyOf(a) - difficultyOf(b) || run.keyOf(a.id).localeCompare(run.keyOf(b.id)));
    return { items: picked, tier: tier.tier };
  }
  const have = avail.map((r, i) => `${topics[i]!.topic_id}:${r.join('/')}`).join(', ');
  run.problems.push(`${part.slot}: cannot pick ${count} standalone items matching the matrix (available per topic d1/d2/d3: ${have || 'none'})`);
  return null;
}

/** Items (and passages) of the slot the run may use in its mode. */
function usablePool(run: PartRun): PoolItem[] {
  if (run.mode === 'with_repeats') return run.pool;
  const seenPassages = new Set(run.pool.filter((it) => it.passage_id && run.lastSeen.has(it.id)).map((it) => it.passage_id!));
  return run.pool.filter((it) => !run.lastSeen.has(it.id) && !(it.passage_id && seenPassages.has(it.passage_id)));
}

function assemblePart(run: PartRun): PartOutcome {
  const { part } = run;
  const pool = usablePool(run);
  const plan = part.passage_plan;
  const passageQuestions = plan ? (plan.standalone_texts + plan.paired_texts) * plan.questions_per_text : 0;
  let passageGroups: PoolItem[][] = [];
  let passageCounts = zeroCounts();
  let tier: FitTier = 'exact_cells';
  if (plan && passageQuestions > 0) {
    const res = pickPassageGroups(run, pool);
    if (!res) return null;
    passageGroups = res.groups;
    passageCounts = res.counts;
    tier = 'passages';
  }
  const remainder = part.question_count - passageQuestions;
  if (remainder < 0) {
    run.problems.push(`${part.slot}: passage plan needs ${passageQuestions} questions, the part has ${part.question_count}`);
    return null;
  }
  let standalone: PoolItem[] = [];
  if (remainder > 0) {
    const topicAdjust = new Map<string, number>();
    for (const it of passageGroups.flat()) topicAdjust.set(it.topic_id, (topicAdjust.get(it.topic_id) ?? 0) + 1);
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
    const picked = pickStandalone(run, pool, remainder, diffTarget, topicAdjust, passageQuestions > 0 ? PASSAGE_DIFFICULTY_TOLERANCE : 0);
    if (!picked) return null;
    standalone = picked.items;
    if (passageQuestions === 0) tier = picked.tier;
  }
  const items = [...standalone, ...passageGroups.flat()];
  if (items.length !== part.question_count || new Set(items.map((i) => i.id)).size !== items.length) {
    run.problems.push(`${part.slot}: assembled ${items.length} of ${part.question_count}`);
    return null;
  }
  return { items, tier };
}

/** Slot items whose topic is in the part's matrix, sorted by id (input order never matters). */
function slotPool(pool: readonly PoolItem[], sectionId: string, partId: string, part: PartMatrix): PoolItem[] {
  const topics = new Set(part.topics.map((t) => t.topic_id));
  return pool
    .filter((it) => it.section_id === sectionId && it.part_id === partId && topics.has(it.topic_id) && it.difficulty >= 1 && it.difficulty <= 3)
    .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
}

/** Assembles one fresh variant, or reports the first part the pool cannot fill (POOL_TOO_SMALL). */
export function assembleFreshVariant(input: AssembleFreshInput): AssembleFreshResult {
  const keyOf = seededKeys(input.seed);
  const sections: Array<{ section_id: string; question_ids: string[] }> = [];
  const fit: Record<string, FitTier> = {};
  const repeatedParts: string[] = [];
  for (const s of input.sections) {
    const ids: string[] = [];
    for (const p of s.parts) {
      const part = input.matrix.get(slotKey(s.id, p.id));
      if (!part) return { ok: false, section_id: s.id, part_id: p.id, problems: [`${s.id}/${p.id}: missing from the matrix`] };
      const problems: string[] = [];
      const base = { part, pool: slotPool(input.pool, s.id, p.id, part), passages: input.passages, lastSeen: input.lastSeen, keyOf, problems };
      let out = assemblePart({ ...base, mode: 'fresh_only' });
      if (!out) {
        out = assemblePart({ ...base, mode: 'with_repeats' });
        if (out) repeatedParts.push(slotKey(s.id, p.id));
      }
      if (!out) return { ok: false, section_id: s.id, part_id: p.id, problems };
      fit[slotKey(s.id, p.id)] = out.tier;
      ids.push(...out.items.map((i) => i.id));
    }
    sections.push({ section_id: s.id, question_ids: ids });
  }
  const all = sections.flatMap((s) => s.question_ids);
  return {
    ok: true,
    sections,
    freshness: { total: all.length, repeated: all.filter((id) => input.lastSeen.has(id)).length },
    fit,
    repeated_parts: repeatedParts,
  };
}

// ---------------------------------------------------------------------------
// Pool health (adminExamPoolHealth)

export interface CellShortfall {
  kind: 'cell';
  section_id: string;
  part_id: string;
  topic_id: string;
  difficulty: number;
  needed: number;
  available: number;
}

export interface PassageShortfall {
  kind: 'passages';
  section_id: string;
  part_id: string;
  layout: 'standalone' | 'paired';
  needed: number;
  available: number;
}

export type Shortfall = CellShortfall | PassageShortfall;

export interface PartHealth {
  section_id: string;
  part_id: string;
  /** Fully disjoint variants this part alone could supply (capped). */
  disjoint: number;
  /** Eligible passages with enough questions, by layout. */
  passages: { standalone: number; paired: number; unknown: number };
  shortfalls: Shortfall[];
}

export interface PoolHealthInput {
  sections: readonly AssemblySection[];
  matrix: ReadonlyMap<string, PartMatrix>;
  pool: readonly PoolItem[];
  passages: ReadonlyMap<string, PoolPassage>;
  /** Simulation cap (the answer is "at least cap" when reached). */
  maxVariants?: number;
}

export interface PoolHealthResult {
  parts: PartHealth[];
  disjoint_variants: number;
  capped: boolean;
  /** Shortfalls for variant number disjoint_variants + 1 (what to write next). */
  shortfalls: Shortfall[];
}

/**
 * How many fully disjoint variants the eligible pool supports (each part
 * simulated with the same assembly and no repeats, removing used items),
 * and which topic × difficulty cells / passages are missing for one more.
 */
export function poolHealth(input: PoolHealthInput): PoolHealthResult {
  const cap = Math.max(1, input.maxVariants ?? 100);
  const parts: PartHealth[] = [];
  for (const s of input.sections) {
    for (const p of s.parts) {
      const part = input.matrix.get(slotKey(s.id, p.id));
      if (!part) {
        parts.push({ section_id: s.id, part_id: p.id, disjoint: 0, passages: { standalone: 0, paired: 0, unknown: 0 }, shortfalls: [] });
        continue;
      }
      const pool = slotPool(input.pool, s.id, p.id, part);
      const used = new Map<string, number>();
      let disjoint = 0;
      while (disjoint < cap) {
        const out = assemblePart({ part, pool, passages: input.passages, lastSeen: used, keyOf: seededKeys(`health_${disjoint}`), mode: 'fresh_only', problems: [] });
        if (!out) break;
        for (const it of out.items) used.set(it.id, 1);
        disjoint++;
      }
      const remaining = pool.filter((it) => !used.has(it.id));
      const usedPassages = new Set(pool.filter((it) => it.passage_id && used.has(it.id)).map((it) => it.passage_id!));
      const shortfalls: Shortfall[] = [];
      for (const t of part.topics) {
        for (const d of DIFFICULTIES) {
          const needed = t.difficulty_targets[dkey(d)];
          if (needed <= 0) continue;
          const available = remaining.filter((it) => it.topic_id === t.topic_id && it.difficulty === d && !(it.passage_id && usedPassages.has(it.passage_id))).length;
          if (available < needed) shortfalls.push({ kind: 'cell', section_id: s.id, part_id: p.id, topic_id: t.topic_id, difficulty: d, needed, available });
        }
      }
      const plan = part.passage_plan;
      const minItems = plan ? Math.max(1, plan.questions_per_text - 2) : 1;
      const countByPassage = new Map<string, number>();
      for (const it of pool) if (it.passage_id && input.passages.has(it.passage_id)) countByPassage.set(it.passage_id, (countByPassage.get(it.passage_id) ?? 0) + 1);
      const passages = { standalone: 0, paired: 0, unknown: 0 };
      const free = { standalone: 0, paired: 0, unknown: 0 };
      for (const [pid, n] of countByPassage) {
        if (n < minItems) continue;
        const layout = input.passages.get(pid)!.layout;
        passages[layout]++;
        if (!usedPassages.has(pid)) free[layout]++;
      }
      if (plan) {
        const pairedAvail = free.paired + Math.min(free.unknown, plan.paired_texts);
        const standaloneAvail = free.standalone + Math.max(0, free.unknown - Math.max(0, plan.paired_texts - free.paired));
        if (pairedAvail < plan.paired_texts) shortfalls.push({ kind: 'passages', section_id: s.id, part_id: p.id, layout: 'paired', needed: plan.paired_texts, available: pairedAvail });
        if (standaloneAvail < plan.standalone_texts) shortfalls.push({ kind: 'passages', section_id: s.id, part_id: p.id, layout: 'standalone', needed: plan.standalone_texts, available: standaloneAvail });
      }
      parts.push({ section_id: s.id, part_id: p.id, disjoint, passages, shortfalls });
    }
  }
  const disjointVariants = parts.length ? Math.min(...parts.map((p) => p.disjoint)) : 0;
  return {
    parts,
    disjoint_variants: disjointVariants,
    capped: disjointVariants >= cap,
    // The binding parts decide the next variant.
    shortfalls: parts.filter((p) => p.disjoint === disjointVariants).flatMap((p) => p.shortfalls),
  };
}
