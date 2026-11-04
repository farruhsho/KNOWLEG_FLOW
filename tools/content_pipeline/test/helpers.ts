import assert from 'node:assert/strict';
import { assembleVariant, usedIds } from '../src/assemble';
import { PipelineFirestore } from '../src/firestore';
import { CollectionName, MAX_BATCH, nestedArrayPaths } from '../src/importer';
import { BankItem, BankPassage, Language, VariantFile } from '../src/schema';
import { ValidationContext } from '../src/validate';
import { real, realBlueprint, realMatrix, T0 } from './fixtures';

export function ctxFor(items: BankItem[], passages: BankPassage[]): ValidationContext {
  const im = new Map(items.map((i) => [i.id, i]));
  const pm = new Map(passages.map((p) => [p.id, p]));
  return {
    blueprints: real().blueprints,
    question: (id) => im.get(id)?.question,
    key: (id) => im.get(id)?.key,
    passage: (id) => {
      const p = pm.get(id);
      return p ? { ...p.passage, layout: p.layout } : undefined;
    },
    partOf: (id) => im.get(id)?.target.part_id,
  };
}

/** Assembles `count` variants in sequence (the no-reuse rule applies across them). */
export function assembleMany(
  bpId: string,
  language: Language,
  items: BankItem[],
  passages: BankPassage[],
  count: number,
  opts: { allowUnapproved?: boolean; allowReuse?: boolean } = {},
): { files: VariantFile[]; failures: string[][] } {
  const bp = realBlueprint(bpId);
  const matrix = realMatrix(bpId);
  const itemMap = new Map(items.map((i) => [i.id, i]));
  const passageMap = new Map(passages.map((p) => [p.id, p]));
  const files: VariantFile[] = [];
  const failures: string[][] = [];
  for (let n = 1; n <= count; n++) {
    const used = usedIds(files, itemMap);
    const res = assembleVariant({
      blueprint: bp, matrix, language, number: n, items, passages: passageMap,
      usedQuestionIds: used.questions, usedPassageIds: used.passages,
      allowUnapproved: opts.allowUnapproved ?? false, allowReuse: opts.allowReuse ?? false, seed: `test|${n}`, now: T0,
    });
    if (res.ok && res.file) files.push(res.file);
    else failures.push(res.problems);
  }
  return { files, failures };
}

/**
 * In-memory FirestorePort. Like the real backend it rejects a whole batch
 * that holds an array inside an array (INVALID_ARGUMENT at commit time).
 */
export class FakeFirestore implements PipelineFirestore {
  readonly docs = new Map<string, Record<string, unknown>>();
  readonly batches: number[] = [];
  get(collection: CollectionName, id: string): Record<string, unknown> | undefined {
    return this.docs.get(`${collection}/${id}`);
  }
  set(collection: CollectionName, id: string, data: Record<string, unknown>): void {
    this.docs.set(`${collection}/${id}`, data);
  }
  async exportCollection(): Promise<Array<Record<string, unknown>>> {
    return [];
  }
  async getExisting(collection: CollectionName, ids: string[]): Promise<Map<string, Record<string, unknown>>> {
    const out = new Map<string, Record<string, unknown>>();
    for (const id of ids) {
      const d = this.docs.get(`${collection}/${id}`);
      if (d) out.set(id, structuredClone(d));
    }
    return out;
  }
  async commitBatch(writes: Array<{ collection: CollectionName; id: string; data: Record<string, unknown>; merge: boolean }>): Promise<void> {
    assert.ok(writes.length <= MAX_BATCH);
    for (const w of writes) {
      const bad = nestedArrayPaths(w.data);
      if (bad.length) throw new Error(`INVALID_ARGUMENT: Cannot convert an array value in an array value (${w.collection}/${w.id} ${bad[0]})`);
    }
    this.batches.push(writes.length);
    for (const w of writes) {
      const k = `${w.collection}/${w.id}`;
      this.docs.set(k, w.merge ? { ...(this.docs.get(k) ?? {}), ...structuredClone(w.data) } : structuredClone(w.data));
    }
  }
}
