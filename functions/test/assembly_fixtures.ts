/**
 * Synthetic banks for the fresh-variant assembly tests, built from the REAL
 * ORT 2026 blueprints (assets/data/exam_blueprints.json) and topic matrices
 * (content/matrix/*.json).
 */
import { readFileSync } from 'node:fs';
import path from 'node:path';
import type { PoolItem, PoolPassage } from '../src/domain/assembly';
import { DIFFICULTIES, dkey, parseBlueprintMatrix, partMatricesFor, type PartMatrix } from '../src/domain/exam_matrix';
import { assemblySections } from '../src/domain/exam_pool';
import type { AssemblySection } from '../src/domain/exam_matrix';
import { blueprint, rawBlueprints } from './fixtures';

const MATRIX_DIR = path.resolve(__dirname, '..', '..', 'content', 'matrix');

export function realMatrix(blueprintId: string, language: string): Map<string, PartMatrix> {
  const m = parseBlueprintMatrix(JSON.parse(readFileSync(path.join(MATRIX_DIR, `${blueprintId}.json`), 'utf8')));
  if (!m) throw new Error(`no matrix ${blueprintId}`);
  const parts = partMatricesFor(m, language);
  if (!parts) throw new Error(`no ${language} matrix for ${blueprintId}`);
  return parts;
}

export function realSections(blueprintId: string): AssemblySection[] {
  return assemblySections(blueprint(blueprintId));
}

/** Every blueprint × language of the real 2026 set. */
export function combos(): Array<[string, string]> {
  return rawBlueprints().flatMap((b) => (b['languages'] as string[]).map((l) => [b['id'] as string, l] as [string, string]));
}

export interface SynthBank {
  items: PoolItem[];
  passages: Map<string, PoolPassage>;
}

/** Difficulty list of `counts` (1s, then 2s, then 3s). */
function difficultyList(counts: Record<string, number>): number[] {
  return DIFFICULTIES.flatMap((d) => Array.from({ length: counts[dkey(d)] ?? 0 }, () => d));
}

/**
 * A bank that fits `copies` disjoint variants exactly: every topic ×
 * difficulty cell holds `copies × target` standalone items; parts with a
 * passage plan get `copies` sets of texts (standalone + paired) with
 * questions_per_text items each whose difficulties follow the part's mix,
 * plus the standalone cells for any remainder. `layout: false` stores no
 * passage layout (`unknown`, as the pipeline importer writes today).
 */
export function synthBank(
  blueprintId: string,
  language: string,
  opts: { copies?: number; prefix?: string; layout?: boolean; status?: string } = {},
): SynthBank {
  const copies = opts.copies ?? 1;
  const prefix = opts.prefix ?? 'q';
  const status = opts.status ?? 'methodologist_approved';
  const matrix = realMatrix(blueprintId, language);
  const items: PoolItem[] = [];
  const passages = new Map<string, PoolPassage>();
  for (const s of realSections(blueprintId)) {
    for (const p of s.parts) {
      const pm = matrix.get(`${s.id}/${p.id}`)!;
      const plan = pm.passage_plan;
      const passageQuestions = plan ? (plan.standalone_texts + plan.paired_texts) * plan.questions_per_text : 0;
      if (plan && passageQuestions > 0) {
        const texts = plan.standalone_texts + plan.paired_texts;
        // Difficulties of the passage questions proportional to the part mix.
        const share = (d: '1' | '2' | '3') => Math.round((pm.difficulty_counts[d] * passageQuestions) / pm.question_count);
        let ds = difficultyList({ '1': share('1'), '2': share('2'), '3': share('3') });
        while (ds.length < passageQuestions) ds.push(2);
        ds = ds.slice(0, passageQuestions);
        for (let c = 0; c < copies; c++) {
          for (let t = 0; t < texts; t++) {
            const pid = `${prefix}_p_${s.id}_${p.id}_${c}_${t}`;
            const layout = t < plan.standalone_texts ? 'standalone' : 'paired';
            passages.set(pid, { id: pid, layout: opts.layout === false ? 'unknown' : layout });
            for (let k = 0; k < plan.questions_per_text; k++) {
              const topic = pm.topics[(t * plan.questions_per_text + k) % pm.topics.length]!;
              items.push({
                id: `${pid}_${k}`,
                section_id: s.id,
                part_id: p.id,
                topic_id: topic.topic_id,
                // interleave difficulties across texts so every text has a mix
                difficulty: ds[(k * texts + t) % ds.length]!,
                passage_id: pid,
                passage_order: k + 1,
                review_status: status,
              });
            }
          }
        }
      }
      if (pm.question_count - passageQuestions > 0) {
        for (const t of pm.topics) {
          for (const d of DIFFICULTIES) {
            const n = t.difficulty_targets[dkey(d)] * copies;
            for (let k = 0; k < n; k++) {
              items.push({
                id: `${prefix}_${s.id}_${p.id}_${t.topic_id}_${d}_${k}`,
                section_id: s.id,
                part_id: p.id,
                topic_id: t.topic_id,
                difficulty: d,
                passage_id: null,
                passage_order: null,
                review_status: status,
              });
            }
          }
        }
      }
    }
  }
  return { items, passages };
}

/** Deterministic shuffle (mulberry32). */
export function shuffled<T>(xs: readonly T[], seed = 7): T[] {
  let a = seed >>> 0;
  const rnd = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const out = [...xs];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [out[i], out[j]] = [out[j]!, out[i]!];
  }
  return out;
}
