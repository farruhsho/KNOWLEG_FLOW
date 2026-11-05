/**
 * The local item bank: content/bank/<batch>/items.json files (BankFile).
 * Ids are derived from content hashes so re-running a stage or re-importing
 * never creates duplicates, and any edit of public content yields a new id.
 */
import { existsSync } from 'node:fs';
import { join, relative } from 'node:path';
import {
  BankFile,
  BankItem,
  BankPassage,
  ExamPassage,
  ExamQuestion,
  formatIssues,
  REVIEW_RANK,
  ReviewStatus,
} from './schema';
import { canonicalJson, listFiles, readJson, sha256Hex, writeJsonAtomic } from './io';

/** Public fields that define a question's identity. The key is deliberately excluded. */
export function questionContentHash(q: Pick<ExamQuestion, 'language' | 'type' | 'stem' | 'options' | 'table' | 'image_path' | 'passage_id'>): string {
  return (
    'sha256:' +
    sha256Hex(
      canonicalJson({
        language: q.language,
        type: q.type,
        stem: q.stem,
        options: q.options,
        table: q.table,
        // Only the file name: the folder is the question id itself, which is derived from this hash.
        image_file: q.image_path === null ? null : q.image_path.replace(/^exam_media\/[^/]+\//, ''),
        passage_id: q.passage_id,
      }),
    )
  );
}

export function questionIdFromHash(contentHash: string): string {
  return 'q_' + contentHash.replace(/^sha256:/, '').slice(0, 20);
}

export function passageContentHash(p: Pick<ExamPassage, 'language' | 'title' | 'text'>): string {
  return 'sha256:' + sha256Hex(canonicalJson({ language: p.language, title: p.title, text: p.text }));
}

export function passageIdFromHash(contentHash: string): string {
  return 'p_' + contentHash.replace(/^sha256:/, '').slice(0, 20);
}

/** Translation group of an original item: stable, derived from the first language version. */
export function translationGroupFor(contentHash: string): string {
  return 'tg_' + contentHash.replace(/^sha256:/, '').slice(0, 16);
}

export interface LoadedBankFile {
  path: string;
  data: BankFile;
}

export interface Bank {
  files: LoadedBankFile[];
  items: Map<string, { item: BankItem; file: LoadedBankFile }>;
  passages: Map<string, { passage: BankPassage; file: LoadedBankFile }>;
  problems: string[];
}

export function bankFilePaths(bankDir: string): string[] {
  return listFiles(bankDir, /^items\.json$/);
}

/** Loads and validates every bank file. Schema problems are collected, not thrown, so `lint` can report all of them. */
export function loadBank(bankDir: string, opts: { strict?: boolean } = {}): Bank {
  const bank: Bank = { files: [], items: new Map(), passages: new Map(), problems: [] };
  for (const path of bankFilePaths(bankDir)) {
    const parsed = BankFile.safeParse(readJson(path));
    const rel = relative(bankDir, path);
    if (!parsed.success) {
      for (const msg of formatIssues(parsed.error)) bank.problems.push(`${rel}: ${msg}`);
      continue;
    }
    const file: LoadedBankFile = { path, data: parsed.data };
    bank.files.push(file);
    for (const passage of parsed.data.passages) {
      const prev = bank.passages.get(passage.id);
      if (prev && prev.passage.content_hash !== passage.content_hash) {
        bank.problems.push(`${rel}: passage ${passage.id} also defined differently in ${relative(bankDir, prev.file.path)}`);
        continue;
      }
      if (!prev) bank.passages.set(passage.id, { passage, file });
    }
    for (const item of parsed.data.items) {
      const prev = bank.items.get(item.id);
      if (prev) {
        bank.problems.push(`${rel}: item ${item.id} duplicated (also in ${relative(bankDir, prev.file.path)})`);
        continue;
      }
      bank.items.set(item.id, { item, file });
    }
  }
  if (opts.strict && bank.problems.length) {
    throw new Error(`Bank has ${bank.problems.length} problem(s):\n${bank.problems.join('\n')}`);
  }
  return bank;
}

export function saveBankFile(file: LoadedBankFile): void {
  const checked = BankFile.parse(file.data);
  writeJsonAtomic(file.path, checked);
}

export function newBankFile(bankDir: string, batchId: string, kind: BankFile['batch']['kind'], note: string, createdAt: string): LoadedBankFile {
  const path = join(bankDir, batchId, 'items.json');
  if (existsSync(path)) {
    const data = BankFile.parse(readJson(path));
    return { path, data };
  }
  return { path, data: { schema_version: 1, batch: { id: batchId, kind, created_at: createdAt, note }, passages: [], items: [] } };
}

/** Consistency checks beyond the schema: hashes, ids, passages, keys and translation groups. */
export function lintBank(bank: Bank): string[] {
  const problems = [...bank.problems];
  for (const { passage } of bank.passages.values()) {
    const hash = passageContentHash(passage.passage);
    if (hash !== passage.content_hash) problems.push(`passage ${passage.id}: content_hash is stale (expected ${hash})`);
    if (passageIdFromHash(passage.content_hash) !== passage.id) problems.push(`passage ${passage.id}: id does not match content_hash`);
  }
  for (const { item } of bank.items.values()) {
    const q = item.question;
    const hash = questionContentHash(q);
    if (hash !== q.content_hash) problems.push(`${item.id}: content_hash is stale (expected ${hash})`);
    if (questionIdFromHash(q.content_hash) !== item.id) problems.push(`${item.id}: id does not match content_hash`);
    const optionIds = new Set(q.options.map((o) => o.id));
    if (!optionIds.has(item.key.correct)) problems.push(`${item.id}: key.correct ${item.key.correct} is not an option`);
    for (const k of Object.keys(item.key.wrong_option_notes)) {
      if (!optionIds.has(k as never)) problems.push(`${item.id}: wrong_option_notes has unknown option ${k}`);
      if (k === item.key.correct) problems.push(`${item.id}: wrong_option_notes must not describe the correct option`);
    }
    if (q.section_id !== item.target.section_id) problems.push(`${item.id}: question.section_id ${q.section_id} != target.section_id ${item.target.section_id}`);
    if (q.passage_id !== null) {
      const p = bank.passages.get(q.passage_id);
      if (!p) problems.push(`${item.id}: passage ${q.passage_id} not found in bank`);
      else if (p.passage.passage.language !== q.language) problems.push(`${item.id}: passage language ${p.passage.passage.language} != ${q.language}`);
      if (item.passage_order === null) problems.push(`${item.id}: passage items need passage_order`);
    } else if (item.passage_order !== null) {
      problems.push(`${item.id}: passage_order set on a standalone item`);
    }
    if (q.image_path !== null && !q.image_path.startsWith(`exam_media/${item.id}/`)) {
      problems.push(`${item.id}: image_path must live under exam_media/${item.id}/`);
    }
  }
  // Translation groups: at most one item per language per group.
  const groups = new Map<string, Map<string, string>>();
  for (const { item } of bank.items.values()) {
    const tg = item.question.translation_group_id;
    if (!tg) continue;
    const byLang = groups.get(tg) ?? new Map<string, string>();
    const prev = byLang.get(item.question.language);
    if (prev) problems.push(`${item.id}: translation group ${tg} already has a ${item.question.language} item (${prev})`);
    byLang.set(item.question.language, item.id);
    groups.set(tg, byLang);
  }
  return problems;
}

/**
 * Recomputes passage/question hashes and ids in place (after a hand edit).
 * Passage id changes are propagated to the items that reference them.
 */
export function rehashBankFile(file: LoadedBankFile): { changed: number } {
  let changed = 0;
  const passageRename = new Map<string, string>();
  for (const p of file.data.passages) {
    const hash = passageContentHash(p.passage);
    const id = passageIdFromHash(hash);
    if (p.content_hash !== hash || p.id !== id) {
      passageRename.set(p.id, id);
      p.content_hash = hash;
      p.id = id;
      changed++;
    }
  }
  for (const item of file.data.items) {
    const q = item.question;
    if (q.passage_id && passageRename.has(q.passage_id)) q.passage_id = passageRename.get(q.passage_id)!;
    const hash = questionContentHash(q);
    const id = questionIdFromHash(hash);
    if (q.content_hash !== hash || item.id !== id) {
      if (q.image_path) q.image_path = q.image_path.replace(/^exam_media\/[^/]+\//, `exam_media/${id}/`);
      q.content_hash = hash;
      item.id = id;
      changed++;
    }
  }
  return { changed };
}

export function reviewRank(status: ReviewStatus): number {
  return REVIEW_RANK[status];
}

/** Items eligible for assembly. Drafts and rejected items never are. */
export function isAssemblyEligible(item: BankItem, allowUnapproved: boolean): boolean {
  const s = item.question.review.status;
  if (s === 'methodologist_approved') return true;
  if (s === 'ai_verified') return allowUnapproved;
  return false;
}

export function bankItemsList(bank: Bank): BankItem[] {
  return [...bank.items.values()].map((v) => v.item).sort((a, b) => a.id.localeCompare(b.id));
}
