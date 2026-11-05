/**
 * Synthetic fixtures for tests: a bank that exactly covers the real topic
 * matrix of a real blueprint (assets/data/exam_blueprints.json +
 * content/curriculum/topics.json) for N variants, plus small helpers.
 * The texts are placeholders — only the structure matters here.
 */
import { copyFileSync, mkdirSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { passageContentHash, passageIdFromHash, questionContentHash, questionIdFromHash, translationGroupFor } from '../src/bank';
import { Blueprint, findPart, loadBlueprints } from '../src/blueprints';
import { Curriculum, loadCurriculum } from '../src/curriculum';
import { apportion } from '../src/flow';
import { comparisonQuestionParts } from '../src/generate';
import { findRepoRoot, pathsFor } from '../src/io';
import { BlueprintMatrix, buildBlueprintMatrix, dkey, languageMatrix, PartMatrix, SectionMatrix } from '../src/matrix';
import { BankItem, BankPassage, Difficulty, DIFFICULTIES, ExamQuestion, Language, OPTION_IDS, OptionId, ReviewStatus } from '../src/schema';

export const T0 = '2026-11-01T00:00:00.000Z';
export const REPO_ROOT = findRepoRoot(__dirname);
export const REPO_PATHS = pathsFor(REPO_ROOT);

let cached: { blueprints: Blueprint[]; curriculum: Curriculum } | null = null;
export function real(): { blueprints: Blueprint[]; curriculum: Curriculum } {
  cached ??= { blueprints: loadBlueprints(REPO_PATHS.blueprints), curriculum: loadCurriculum(REPO_PATHS.curriculum) };
  return cached;
}

export function realBlueprint(id: string): Blueprint {
  const bp = real().blueprints.find((b) => b.id === id);
  if (!bp) throw new Error(`no blueprint ${id}`);
  return bp;
}

export function realMatrix(id: string): BlueprintMatrix {
  return buildBlueprintMatrix(realBlueprint(id), real().curriculum);
}

export interface SynthItemArgs {
  bp: Blueprint;
  section: SectionMatrix;
  part: PartMatrix;
  language: Language;
  topicId: string;
  difficulty: Difficulty;
  serial: string;
  status: ReviewStatus;
  keyIndex: number;
  passageId?: string | null;
  passageOrder?: number | null;
  batchId?: string;
}

/** One schema-valid bank item with a correct content hash and id. */
export function synthItem(a: SynthItemArgs): BankItem {
  const { part: bpPart } = findPart(a.bp, a.section.section_id, a.part.part_id);
  let stem: string;
  let options: ExamQuestion['options'];
  let table: ExamQuestion['table'] = null;
  let correct: OptionId;
  if (a.part.item_type === 'quantitative_comparison') {
    const k = a.keyIndex % 3; // A, B, C — columns consistent with the key
    const n = 10 + (a.keyIndex % 50);
    const [colA, colB] = k === 0 ? [`$${n + 1}$`, `$${n}$`] : k === 1 ? [`$${n}$`, `$${n + 1}$`] : [`$${n}$`, `$${n}$`];
    const parts = comparisonQuestionParts(a.language, `Условие ${a.keyIndex}.`, colA, colB, bpPart);
    stem = parts.stem;
    table = parts.table;
    options = parts.options;
    correct = (['A', 'B', 'C'] as const)[k]!;
  } else {
    const ids = OPTION_IDS.slice(0, a.part.options_per_question);
    stem = `Задание ${a.keyIndex}, уровень ${a.difficulty}.`;
    options = ids.map((id) => ({ id, text: `ответ ${a.keyIndex}${id}` }));
    correct = ids[a.keyIndex % ids.length]!;
  }
  const q: Omit<ExamQuestion, 'content_hash' | 'translation_group_id'> = {
    subject_id: a.section.subject_id,
    section_id: a.section.section_id,
    topic_id: a.topicId,
    subtopic_id: null,
    difficulty: a.difficulty,
    language: a.language,
    type: a.part.item_type,
    stem,
    options,
    passage_id: a.passageId ?? null,
    image_path: null,
    table,
    source: { kind: 'original', basis: 'Синтетическая фикстура для тестов', author: 'test:fixtures' },
    review: {
      status: a.status,
      reviewed_by: a.status === 'methodologist_approved' || a.status === 'rejected' ? 'uid_methodologist' : null,
      reviewed_at: a.status === 'methodologist_approved' || a.status === 'rejected' ? T0 : null,
      notes: '',
    },
    content_version: 1,
    created_at: T0,
    updated_at: T0,
  };
  const content_hash = questionContentHash(q);
  const wrong = Object.fromEntries(options.filter((o) => o.id !== correct).map((o) => [o.id, `почему ${o.id} неверно`]));
  return {
    id: questionIdFromHash(content_hash),
    target: { blueprint_id: a.bp.id, section_id: a.section.section_id, part_id: a.part.part_id },
    question: { ...q, translation_group_id: translationGroupFor(content_hash), content_hash },
    key: { correct, explanation: `Объяснение ${a.serial}`, wrong_option_notes: wrong, solution_steps: [`шаг ${a.serial}`] },
    passage_order: a.passageOrder ?? null,
    pipeline: { batch_id: a.batchId ?? 'synthetic', generated_by: 'hand:test', prompt_version: null },
  };
}

export function synthPassage(language: Language, section: SectionMatrix, layout: 'standalone' | 'paired', serial: string, words: number): BankPassage {
  const sentence = `Это синтетическое предложение текста ${serial} для проверки сборки вариантов.`;
  const per = sentence.split(' ').length;
  const body = Array.from({ length: Math.max(1, Math.round(words / per)) }, () => sentence).join(' ');
  const passage = {
    language,
    subject_id: section.subject_id,
    section_id: section.section_id,
    title: `Текст ${serial}`,
    text: layout === 'paired' ? `Текст 1.\n\n${body}\n\nТекст 2.\n\n${body}` : body,
    source: { kind: 'original' as const, basis: 'Синтетическая фикстура', author: 'test:fixtures' },
  };
  const content_hash = passageContentHash(passage);
  return { id: passageIdFromHash(content_hash), layout, translation_group_id: translationGroupFor(content_hash), content_hash, passage };
}

export interface SyntheticBank {
  items: BankItem[];
  passages: BankPassage[];
}

/**
 * Items for `variants` variants of blueprint × language without reuse.
 * `spare` adds that many extra items per topic × difficulty (also for zero
 * cells) and that many extra passage sets.
 */
export function syntheticBank(bpId: string, language: Language, variants: number, opts: { spare?: number; status?: ReviewStatus; matrix?: BlueprintMatrix } = {}): SyntheticBank {
  const bp = realBlueprint(bpId);
  const matrix = opts.matrix ?? realMatrix(bpId);
  const spare = opts.spare ?? 0;
  const status = opts.status ?? 'methodologist_approved';
  const items: BankItem[] = [];
  const passages: BankPassage[] = [];
  let key = 0;
  for (const section of languageMatrix(matrix, language).sections) {
    for (const part of section.parts) {
      const plan = part.passage_plan;
      const passageTopicIds = new Set(plan ? (plan.passage_topics ?? part.topics.map((t) => t.topic_id)) : []);
      // Standalone cells.
      for (const t of part.topics) {
        if (passageTopicIds.has(t.topic_id)) continue;
        for (const d of DIFFICULTIES) {
          const n = t.difficulty_targets[dkey(d)] * variants + spare;
          for (let i = 0; i < n; i++) {
            const serial = `${bp.id}/${language}/${part.part_id}/${t.topic_id}/${d}/${i}`;
            items.push(synthItem({ bp, section, part, language, topicId: t.topic_id, difficulty: d, serial, status, keyIndex: key++ }));
          }
        }
      }
      if (!plan) continue;
      // Passage sets: one set = standalone_texts + paired_texts passages of questions_per_text items.
      const perText = plan.questions_per_text;
      const topicList: string[] = [];
      for (const t of part.topics) if (passageTopicIds.has(t.topic_id)) for (let i = 0; i < t.target; i++) topicList.push(t.topic_id);
      const mix = DIFFICULTIES.map((d) => part.difficulty_counts[dkey(d)]);
      const perPassageDiff = apportion(perText, mix);
      const diffList: Difficulty[] = DIFFICULTIES.flatMap((d, i) => Array.from({ length: perPassageDiff[i] ?? 0 }, () => d));
      const words = plan.words ? Math.round((plan.words[0] + plan.words[1]) / 2) : 300;
      for (let s = 0; s < variants + spare; s++) {
        const layouts: Array<'standalone' | 'paired'> = [
          ...Array.from({ length: plan.paired_texts }, () => 'paired' as const),
          ...Array.from({ length: plan.standalone_texts }, () => 'standalone' as const),
        ];
        const slots: string[][] = layouts.map(() => []);
        const pairedFirst = [...topicList].sort((x, y) => Number(y.includes('paired')) - Number(x.includes('paired')));
        let cursor = 0;
        for (const topic of pairedFirst) {
          // Paired-comparison questions go to paired passages; everything else round-robin.
          let idx = topic.includes('paired') ? layouts.findIndex((l, i) => l === 'paired' && slots[i]!.length < perText) : -1;
          if (idx < 0) {
            for (let tries = 0; tries < layouts.length; tries++) {
              const i = (cursor + tries) % layouts.length;
              if (slots[i]!.length < perText) {
                idx = i;
                cursor = i + 1;
                break;
              }
            }
          }
          if (idx >= 0) slots[idx]!.push(topic);
        }
        layouts.forEach((layout, pi) => {
          const serial = `${bp.id}/${language}/${part.part_id}/set${s}/text${pi}`;
          const p = synthPassage(language, section, layout, serial, words);
          passages.push(p);
          const topics = slots[pi]!;
          while (topics.length < perText) topics.push(topicList[topics.length % topicList.length]!);
          topics.forEach((topicId, qi) => {
            items.push(
              synthItem({
                bp, section, part, language, topicId, difficulty: diffList[qi % diffList.length]!, serial: `${serial}/q${qi}`, status,
                keyIndex: key++, passageId: p.id, passageOrder: qi + 1,
              }),
            );
          });
        });
      }
    }
  }
  return { items, passages };
}

const tempRoots: string[] = [];
process.on('exit', () => {
  for (const r of tempRoots) rmSync(r, { recursive: true, force: true });
});

/** A temp repo root with the real blueprints and curriculum copied in (removed when the test process exits). */
export function tempRepo(): string {
  const root = mkdtempSync(join(tmpdir(), 'ort-pipeline-'));
  tempRoots.push(root);
  const p = pathsFor(root);
  mkdirSync(join(root, 'assets', 'data'), { recursive: true });
  mkdirSync(join(root, 'content', 'curriculum'), { recursive: true });
  copyFileSync(REPO_PATHS.blueprints, p.blueprints);
  copyFileSync(REPO_PATHS.curriculum, p.curriculum);
  return root;
}

export function captureOut(): { out: (l: string) => void; lines: string[] } {
  const lines: string[] = [];
  return { out: (l) => lines.push(l), lines };
}
