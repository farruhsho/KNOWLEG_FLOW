import { assembleVariant, usedIds } from '../src/assemble';
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
