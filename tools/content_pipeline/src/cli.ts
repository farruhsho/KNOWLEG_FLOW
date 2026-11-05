#!/usr/bin/env node
/**
 * ORT content pipeline CLI. Run from tools/content_pipeline:
 *   npm run cli -- <stage> [flags]
 * Stages: matrix, generate, verify, translate-check, dedup, assemble, timing,
 * import, validate, registry, lint, review, review-sync, schemas. See
 * docs/modernization/CONTENT_PIPELINE.md.
 */
import { existsSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { assembleVariant, usedIds, variantIdFor } from './assemble';
import { Bank, bankItemsList, lintBank, loadBank, newBankFile, rehashBankFile, saveBankFile } from './bank';
import { Blueprint, findPart, getBlueprint, loadBlueprints, loadRawBlueprints } from './blueprints';
import { loadCurriculum } from './curriculum';
import { dedupRecords, externalDocsFrom, runDedup } from './dedup';
import { DEFAULT_PROJECT_ID, openFirestore, PipelineFirestore } from './firestore';
import { convertTranslation, estimateRequestTokens, planGeneration, runGeneration, translationCandidates, translationRequest, TRANSLATION_SYSTEM } from './generate';
import { applyRemoteReviews, applyRemoteVariantStatuses, buildImportPlan, commitPlan, MAX_BATCH } from './importer';
import { findRepoRoot, listFiles, nowIso, Paths, pathsFor, readJson, writeJsonAtomic, writeText } from './io';
import { AnthropicLlm, COST_FLAG, costUsd, CostMeter, DEFAULT_MODEL, LlmClient, LlmError, requirePaidConsent } from './llm';
import { BlueprintMatrix, buildBlueprintMatrix, describeMatrix, languageMatrix } from './matrix';
import { computeRegistry, registryMarkdown } from './registry';
import { BankItem, exportJsonSchemas, formatIssues, Language, LANGUAGES, REVIEW_RANK, ReviewStatus, VariantFile } from './schema';
import { estimateVariantTiming, TIMING_MODEL } from './timing';
import { apiCheck, mergeRecord, pairRecord, structuralProblems, translationPairs } from './translate';
import { formatProblems, hasErrors, Problem, validateVariant, validateVariantSet, ValidationContext } from './validate';
import { applyVerifyRecord, needsVerify, verifyItem } from './verify';
import { checkArithmetic } from './arith';

type Opts = Record<string, string | boolean | string[]>;

const BOOLEAN_FLAGS = new Set([
  'plan', 'i-understand-this-costs-money', 'force', 'mark', 'allow-unapproved', 'allow-reuse', 'dry-run', 'commit', 'publish',
  'all-items', 'require-languages', 'fix', 'api', 'from-draft', 'no-fallbacks', 'local-only', 'help', 'json', 'overwrite',
]);

export function parseArgs(argv: string[]): { cmd: string; opts: Opts } {
  const [cmd = 'help', ...rest] = argv;
  const opts: Opts = {};
  for (let i = 0; i < rest.length; i++) {
    const a = rest[i]!;
    if (!a.startsWith('--')) throw new Error(`unexpected argument ${a}`);
    const name = a.slice(2);
    if (BOOLEAN_FLAGS.has(name)) {
      opts[name] = true;
      continue;
    }
    const value = rest[++i];
    if (value === undefined || value.startsWith('--')) throw new Error(`--${name} needs a value`);
    const prev = opts[name];
    opts[name] = prev === undefined ? value : Array.isArray(prev) ? [...prev, value] : [String(prev), value];
  }
  return { cmd, opts };
}

const str = (o: Opts, k: string): string | undefined => (typeof o[k] === 'string' ? (o[k] as string) : Array.isArray(o[k]) ? (o[k] as string[]).at(-1) : undefined);
const list = (o: Opts, k: string): string[] => (o[k] === undefined || typeof o[k] === 'boolean' ? [] : Array.isArray(o[k]) ? (o[k] as string[]) : String(o[k]).split(',').map((s) => s.trim()).filter(Boolean));
const num = (o: Opts, k: string, d: number): number => {
  const v = str(o, k);
  if (v === undefined) return d;
  const n = Number(v);
  if (!Number.isFinite(n)) throw new Error(`--${k} must be a number`);
  return n;
};
const bool = (o: Opts, k: string): boolean => o[k] === true;

function lang(o: Opts, required = true): Language | undefined {
  const l = str(o, 'language');
  if (!l) {
    if (required) throw new Error('--language ru|ky|en is required');
    return undefined;
  }
  if (!(LANGUAGES as readonly string[]).includes(l)) throw new Error(`unknown language ${l}`);
  return l as Language;
}

interface Env {
  paths: Paths;
  out: (line: string) => void;
  /** Opens Firestore (firebase-admin); tests pass a fake. */
  openDb: (projectId: string) => Promise<PipelineFirestore>;
}

export interface CliDeps {
  openFirestore?: (projectId: string) => Promise<PipelineFirestore>;
}

function loadVariantFiles(paths: Paths): Array<{ path: string; file: VariantFile }> {
  return listFiles(paths.variants, /^v_.*\.json$/).map((path) => {
    const parsed = VariantFile.safeParse(readJson(path));
    if (!parsed.success) throw new Error(`${relative(paths.root, path)}: ${formatIssues(parsed.error).join('; ')}`);
    return { path, file: parsed.data };
  });
}

function loadMatrix(paths: Paths, bp: Blueprint): BlueprintMatrix {
  const p = join(paths.matrix, `${bp.id}.json`);
  if (existsSync(p)) {
    const m = readJson<BlueprintMatrix>(p);
    if (m.blueprint_version === bp.version) return m;
  }
  return buildBlueprintMatrix(bp, loadCurriculum(paths.curriculum));
}

export function validationContext(blueprints: Blueprint[], bank: Bank): ValidationContext {
  return {
    blueprints,
    question: (id) => bank.items.get(id)?.item.question,
    key: (id) => bank.items.get(id)?.item.key,
    passage: (id) => {
      const p = bank.passages.get(id)?.passage;
      return p ? { ...p.passage, layout: p.layout } : undefined;
    },
    partOf: (id) => bank.items.get(id)?.item.target.part_id,
  };
}

function makeLlm(o: Opts, envModelVar = 'CONTENT_MODEL'): LlmClient {
  const model = str(o, 'model') ?? process.env[envModelVar] ?? process.env.CONTENT_MODEL ?? DEFAULT_MODEL;
  const effort = (str(o, 'effort') ?? process.env.CONTENT_EFFORT ?? 'high') as 'low' | 'medium' | 'high' | 'xhigh' | 'max';
  return new AnthropicLlm({ model, effort, fallbacks: !bool(o, 'no-fallbacks') });
}

function blueprintsFrom(o: Opts, all: Blueprint[]): Blueprint[] {
  const ids = list(o, 'blueprint');
  if (!ids.length || ids.includes('all')) return all;
  return ids.map((id) => getBlueprint(all, id));
}

// ---------------------------------------------------------------------------

async function cmdMatrix(env: Env, o: Opts): Promise<number> {
  const all = loadBlueprints(env.paths.blueprints);
  const curriculum = loadCurriculum(env.paths.curriculum);
  for (const bp of blueprintsFrom(o, all)) {
    const m = buildBlueprintMatrix(bp, curriculum);
    writeJsonAtomic(join(env.paths.matrix, `${bp.id}.json`), m);
    env.out(describeMatrix(m));
  }
  return 0;
}

async function cmdGenerate(env: Env, o: Opts): Promise<number> {
  const all = loadBlueprints(env.paths.blueprints);
  const bpId = str(o, 'blueprint');
  if (!bpId) throw new Error('--blueprint is required');
  const bp = getBlueprint(all, bpId);
  const language = lang(o)!;
  const matrix = loadMatrix(env.paths, bp);
  const bank = loadBank(env.paths.bank, { strict: true });
  const filter = { section: str(o, 'section'), part: str(o, 'part'), topic: str(o, 'topic') };
  const perRequest = Math.min(10, Math.max(1, num(o, 'per-request', 5)));
  const maxItems = num(o, 'max-items', 50);
  const model = str(o, 'model') ?? process.env.CONTENT_MODEL ?? DEFAULT_MODEL;
  const from = str(o, 'translate-from') as Language | undefined;

  if (from) {
    const candidates = translationCandidates(bank, from, language, bp.id, filter).slice(0, maxItems);
    const estIn = candidates.length * 1800;
    const estOut = candidates.length * 1600;
    env.out(`translate ${from} → ${language}: ${candidates.length} item(s); estimate ≈ $${costUsd(model, estIn, estOut).toFixed(2)} with ${model}`);
    if (bool(o, 'plan') || !bool(o, 'i-understand-this-costs-money')) {
      if (!bool(o, 'plan')) env.out(`(dry plan only — add ${COST_FLAG} to run)`);
      return 0;
    }
    requirePaidConsent(true);
    const llm = makeLlm(o);
    const meter = new CostMeter(str(o, 'max-cost-usd') ? num(o, 'max-cost-usd', 0) : null);
    const batchId = str(o, 'batch-id') ?? `translate_${from}_${language}_${bp.id}_${nowIso().slice(0, 10)}`;
    const file = newBankFile(env.paths.bank, batchId, 'translated', `Translations ${from} → ${language} for ${bp.id}`, nowIso());
    let added = 0;
    for (const src of candidates) {
      if (meter.exhausted()) break;
      const { part } = findPart(bp, src.target.section_id, src.target.part_id);
      try {
        const req = translationRequest(src, language);
        const res = await llm.complete({ purpose: 'translate', system: TRANSLATION_SYSTEM, user: req.user, schema: req.schema });
        meter.add(res.usage);
        const item = convertTranslation(src, language, part, res.json, { batchId, model: llm.model, now: nowIso() });
        if (!bank.items.has(item.id)) {
          file.data.items.push(item);
          bank.items.set(item.id, { item, file });
          added++;
          saveBankFile(file);
        }
        env.out(`+ ${src.id} → ${item.id} — ${meter}`);
      } catch (e) {
        env.out(`! ${src.id}: ${(e as Error).message}`);
        if (e instanceof LlmError && e.kind === 'api') break;
      }
    }
    env.out(`translated ${added} item(s); ${meter}`);
    return 0;
  }

  const rows = planGeneration(matrix, language, bank, num(o, 'variants', 10), num(o, 'overgeneration', 1.3), filter);
  let estIn = 0;
  let estOut = 0;
  let deficitItems = 0;
  for (const r of rows) {
    if (r.deficit <= 0) continue;
    const requests = r.kind === 'passage_group' ? r.deficit : Math.ceil(r.deficit / perRequest);
    const t = estimateRequestTokens(r, perRequest);
    estIn += requests * t.input;
    estOut += requests * t.output;
    deficitItems += r.kind === 'passage_group' ? r.deficit * 12 : r.deficit;
    env.out(`${r.slot} ${r.kind === 'passage_group' ? `[${r.layout} passages]` : `${r.topic_id} d${r.difficulty}`}: have ${r.have}, target ${r.target}, deficit ${r.deficit}`);
  }
  env.out(`total deficit ≈ ${deficitItems} item(s); full-plan estimate ≈ $${costUsd(model, estIn, estOut).toFixed(2)} with ${model} (this run is capped at --max-items ${maxItems})`);
  if (bool(o, 'plan') || !bool(o, 'i-understand-this-costs-money')) {
    if (!bool(o, 'plan')) env.out(`(dry plan only — add ${COST_FLAG} to call the API)`);
    return 0;
  }
  requirePaidConsent(true);
  const llm = makeLlm(o);
  const batchId = str(o, 'batch-id') ?? `gen_${bp.id}_${language}_${nowIso().slice(0, 10)}`;
  const file = newBankFile(env.paths.bank, batchId, 'generated', `Generated for ${bp.id} [${language}] by ${llm.model}`, nowIso());
  const meter = new CostMeter(str(o, 'max-cost-usd') ? num(o, 'max-cost-usd', 0) : null);
  const res = await runGeneration({ blueprint: bp, matrix, language, bank, file, llm, rows, perRequest, maxItems, meter, now: nowIso, log: env.out });
  writeJsonAtomic(join(env.paths.bank, batchId, 'batch.json'), {
    batch_id: batchId,
    model: llm.model,
    updated_at: nowIso(),
    args: o,
    result: res,
    usage: { calls: meter.calls, input_tokens: meter.input, output_tokens: meter.output, cost_usd: Math.round(meter.usd * 100) / 100 },
  });
  env.out(`added ${res.items_added} item(s), ${res.passages_added} passage(s), ${res.failures.length} failure(s); ${meter}`);
  return 0;
}

function selectItems(bank: Bank, o: Opts): BankItem[] {
  const ids = new Set(list(o, 'ids'));
  const batch = str(o, 'batch');
  const bpIds = list(o, 'blueprint');
  const language = lang(o, false);
  return bankItemsList(bank).filter(
    (it) =>
      (!ids.size || ids.has(it.id)) &&
      (!batch || it.pipeline.batch_id === batch) &&
      (!bpIds.length || bpIds.includes(it.target.blueprint_id)) &&
      (!language || it.question.language === language),
  );
}

async function cmdVerify(env: Env, o: Opts): Promise<number> {
  const bank = loadBank(env.paths.bank, { strict: true });
  const force = bool(o, 'force');
  // The free --local-only check covers every selected item unless capped;
  // the paid API run keeps the 100-item default.
  const localOnly = bool(o, 'local-only');
  const cap = num(o, 'max-items', localOnly ? Number.MAX_SAFE_INTEGER : 100);
  const items = selectItems(bank, o).filter((it) => needsVerify(it, force)).slice(0, cap);
  if (localOnly) {
    let failed = 0;
    for (const it of items) {
      if (it.question.subject_id !== 'math') continue;
      const r = checkArithmetic(it);
      if (r.checked) env.out(`${r.ok ? 'ok  ' : 'FAIL'} ${it.id} ${r.detail}`);
      if (r.ok === false) failed++;
    }
    return failed ? 1 : 0;
  }
  const model = str(o, 'model') ?? process.env.VERIFY_MODEL ?? process.env.CONTENT_MODEL ?? DEFAULT_MODEL;
  env.out(`${items.length} item(s) to verify; estimate ≈ $${costUsd(model, items.length * 1500, items.length * 2500).toFixed(2)} with ${model}`);
  if (!bool(o, 'i-understand-this-costs-money')) {
    env.out(`(dry plan only — add ${COST_FLAG} to call the API, or --local-only for the free arithmetic check)`);
    return 0;
  }
  requirePaidConsent(true);
  const llm = makeLlm({ ...o, model }, 'VERIFY_MODEL');
  const meter = new CostMeter(str(o, 'max-cost-usd') ? num(o, 'max-cost-usd', 0) : null);
  const counts: Record<string, number> = {};
  const touched = new Set<string>();
  for (const it of items) {
    if (meter.exhausted()) break;
    const entry = bank.items.get(it.id)!;
    try {
      const passage = it.question.passage_id ? bank.passages.get(it.question.passage_id)?.passage : undefined;
      const rec = await verifyItem(it, passage, llm, nowIso());
      if (rec.usage) meter.add(rec.usage);
      applyVerifyRecord(it, rec);
      counts[rec.verdict] = (counts[rec.verdict] ?? 0) + 1;
      saveBankFile(entry.file);
      touched.add(entry.file.path);
      env.out(`${rec.verdict.padEnd(11)} ${it.id} ${rec.agrees ? 'agrees' : 'DISAGREES'} — ${meter}`);
      if (rec.verdict === 'unchanged' && !rec.agrees) env.out(`  ! approved item disagrees with the blind solver: send ${it.id} back to a methodologist`);
    } catch (e) {
      env.out(`! ${it.id}: ${(e as Error).message}`);
      if (e instanceof LlmError && e.kind === 'api') break;
    }
  }
  env.out(`verify done: ${JSON.stringify(counts)}; ${meter}`);
  return 0;
}

async function cmdTranslateCheck(env: Env, o: Opts): Promise<number> {
  const bank = loadBank(env.paths.bank, { strict: true });
  const items = selectItems(bank, { ...o, language: false });
  const pairs = translationPairs(items);
  const passages = new Map([...bank.passages].map(([k, v]) => [k, v.passage]));
  const useApi = bool(o, 'api');
  let llm: LlmClient | null = null;
  if (useApi) {
    const model = str(o, 'model') ?? process.env.CONTENT_MODEL ?? DEFAULT_MODEL;
    env.out(`${pairs.length} pair(s); API estimate ≈ $${costUsd(model, pairs.length * 2500, pairs.length * 800).toFixed(2)} with ${model}`);
    if (!bool(o, 'i-understand-this-costs-money')) {
      env.out(`(structural checks only — add ${COST_FLAG} for the bilingual API check)`);
    } else {
      requirePaidConsent(true);
      llm = makeLlm(o);
    }
  }
  const now = nowIso();
  let failed = 0;
  const files = new Set<string>();
  for (const pair of pairs) {
    const structural = structuralProblems(pair.a, pair.b, passages);
    let api = null;
    if (llm) {
      try {
        api = await apiCheck(pair, passages, llm);
      } catch (e) {
        env.out(`! api check ${pair.a.id}/${pair.b.id}: ${(e as Error).message}`);
      }
    }
    for (const self of [pair.a, pair.b]) {
      self.pipeline.translate_check = mergeRecord(self.pipeline.translate_check, pairRecord(pair, structural, api, now, self));
      files.add(bank.items.get(self.id)!.file.path);
    }
    const st = pair.a.pipeline.translate_check!.status;
    if (st === 'failed') failed++;
    env.out(`${st === 'passed' ? 'ok  ' : 'FAIL'} ${pair.a.id} (${pair.a.question.language}) ↔ ${pair.b.id} (${pair.b.question.language})${structural.length ? ': ' + structural.join('; ') : ''}`);
  }
  for (const f of bank.files) if (files.has(f.path)) saveBankFile(f);
  env.out(`${pairs.length} pair(s), ${failed} failed`);
  return failed ? 1 : 0;
}

async function cmdDedup(env: Env, o: Opts): Promise<number> {
  const bank = loadBank(env.paths.bank, { strict: true });
  const threshold = num(o, 'threshold', 0.85);
  const items = bankItemsList(bank);
  const passages = [...bank.passages.values()].map((v) => v.passage);
  const external = list(o, 'against')
    .map((p) => resolve(env.paths.root, p))
    .flatMap((p) => externalDocsFrom(readJson(p), relative(env.paths.root, p).split('\\').join('/')));
  const report = runDedup(items, passages, threshold, external);
  const reportPath = join(env.paths.reports, 'dedup.json');
  writeJsonAtomic(reportPath, { generated_at: nowIso(), ...report });
  for (const c of report.clusters) env.out(`${c.kind} cluster ${c.cluster_id}: canonical ${c.canonical}; ${c.members.map((m) => `${m.id} (${m.similarity_to_canonical})`).join(', ')}`);
  for (const m of report.external_matches) env.out(`matches existing content: ${m.id} ~ ${m.external_ref} (${m.similarity})`);
  if (bool(o, 'mark')) {
    const recs = dedupRecords(report, nowIso());
    for (const f of bank.files) {
      let changed = false;
      for (const it of f.data.items) {
        const r = recs.get(it.id);
        if (r) {
          it.pipeline.dedup = r;
          changed = true;
        } else if (it.pipeline.dedup) {
          delete it.pipeline.dedup;
          changed = true;
        }
      }
      if (changed) saveBankFile(f);
    }
  }
  env.out(`${report.documents} document(s), ${report.clusters.length} cluster(s), ${report.external_matches.length} external match(es); report: ${relative(env.paths.root, reportPath)}`);
  return 0;
}

function parseNumbers(spec: string): number[] {
  const out: number[] = [];
  for (const part of spec.split(',')) {
    const m = /^(\d+)(?:-(\d+))?$/.exec(part.trim());
    if (!m) throw new Error(`bad --numbers ${spec}`);
    const a = Number(m[1]);
    const b = m[2] ? Number(m[2]) : a;
    for (let n = a; n <= b; n++) out.push(n);
  }
  return out;
}

async function cmdAssemble(env: Env, o: Opts): Promise<number> {
  const all = loadBlueprints(env.paths.blueprints);
  const bpId = str(o, 'blueprint');
  if (!bpId) throw new Error('--blueprint is required');
  const bp = getBlueprint(all, bpId);
  const language = lang(o)!;
  const matrix = loadMatrix(env.paths, bp);
  const bank = loadBank(env.paths.bank, { strict: true });
  const variantFiles = loadVariantFiles(env.paths).filter((v) => v.file.variant.blueprint_id === bp.id && v.file.variant.language === language);
  const existingNumbers = variantFiles.map((v) => v.file.variant.number);
  const numbers = str(o, 'numbers') ? parseNumbers(str(o, 'numbers')!) : Array.from({ length: num(o, 'count', 1) }, (_, i) => Math.max(0, ...existingNumbers) + i + 1);
  const items = bankItemsList(bank);
  const itemMap = new Map(items.map((i) => [i.id, i]));
  const passages = new Map([...bank.passages].map(([k, v]) => [k, v.passage]));
  const ctx = validationContext(all, bank);
  let failures = 0;
  const built: VariantFile[] = [];
  for (const n of numbers) {
    const id = variantIdFor(bp.id, language, n);
    const existing = variantFiles.find((v) => v.file.id === id);
    if (existing && existing.file.variant.status === 'published') {
      env.out(`skip ${id}: published variants are never rebuilt (archive it and use a new number)`);
      continue;
    }
    if (existing && existing.file.variant.status === 'archived') {
      env.out(`skip ${id}: archived variants are never rebuilt (the id stays withdrawn in Firestore; use a new number)`);
      continue;
    }
    const others = [...variantFiles.filter((v) => v.file.id !== id).map((v) => v.file), ...built];
    const used = usedIds(others, itemMap);
    const seed = str(o, 'seed') ?? `${bp.id}|${language}|${n}`;
    const res = assembleVariant({
      blueprint: bp, matrix, language, number: n, items, passages,
      usedQuestionIds: used.questions, usedPassageIds: used.passages,
      allowUnapproved: bool(o, 'allow-unapproved'), allowReuse: bool(o, 'allow-reuse'), seed, now: nowIso(),
    });
    if (!res.ok || !res.file) {
      failures++;
      env.out(`✗ ${id}:\n  ${res.problems.join('\n  ')}`);
      continue;
    }
    const file = res.file;
    if (existing) {
      const same = JSON.stringify(existing.file.variant.sections) === JSON.stringify(file.variant.sections);
      file.variant.content_version = same ? existing.file.variant.content_version : existing.file.variant.content_version + 1;
    }
    const problems = validateVariant(file.id, file.variant, ctx, { publish: false, matrix: languageMatrix(matrix, language) });
    const timing = estimateVariantTiming(file.variant, bp, itemMap, passages);
    file.assembly.timing = timing;
    file.assembly.validation = problems;
    built.push(file);
    env.out(`✓ ${id}: fit ${JSON.stringify(res.fit)}; timing ${timing.sections.map((s) => `${s.section_id} ${s.estimated_minutes}/${s.budget_minutes}`).join(', ')}`);
    if (problems.length) env.out(formatProblems(problems));
    if (!bool(o, 'dry-run')) writeJsonAtomic(join(env.paths.variants, bp.id, language, `${file.id}.json`), file);
  }
  return failures ? 1 : 0;
}

async function cmdTiming(env: Env, o: Opts): Promise<number> {
  const all = loadBlueprints(env.paths.blueprints);
  const bank = loadBank(env.paths.bank, { strict: true });
  const itemMap = new Map(bankItemsList(bank).map((i) => [i.id, i]));
  const passages = new Map([...bank.passages].map(([k, v]) => [k, v.passage]));
  const bpIds = list(o, 'blueprint');
  const language = lang(o, false);
  const margin = num(o, 'margin', TIMING_MODEL.default_margin);
  let bad = 0;
  for (const { file } of loadVariantFiles(env.paths)) {
    if (bpIds.length && !bpIds.includes(file.variant.blueprint_id)) continue;
    if (language && file.variant.language !== language) continue;
    const t = estimateVariantTiming(file.variant, getBlueprint(all, file.variant.blueprint_id), itemMap, passages, margin);
    if (!t.fits) bad++;
    env.out(`${t.fits ? 'fits' : 'OVER'} ${file.id}: ${t.sections.map((s) => `${s.section_id} ${s.estimated_minutes} min of ${s.duration_minutes} (budget ${s.budget_minutes})`).join('; ')}${t.missing_items.length ? `; missing ${t.missing_items.length} item(s)` : ''}`);
  }
  return bad ? 1 : 0;
}

async function cmdValidate(env: Env, o: Opts): Promise<number> {
  const all = loadBlueprints(env.paths.blueprints);
  const bank = loadBank(env.paths.bank, { strict: true });
  const ctx = validationContext(all, bank);
  const bpIds = list(o, 'blueprint');
  const language = lang(o, false);
  const files = loadVariantFiles(env.paths)
    .map((v) => v.file)
    .filter((f) => (!bpIds.length || bpIds.includes(f.variant.blueprint_id)) && (!language || f.variant.language === language));
  const problems: Problem[] = [];
  for (const f of files) {
    const bp = getBlueprint(all, f.variant.blueprint_id);
    const matrix = loadMatrix(env.paths, bp);
    problems.push(...validateVariant(f.id, f.variant, ctx, { publish: bool(o, 'publish') || f.variant.status === 'published', matrix: languageMatrix(matrix, f.variant.language) }));
  }
  problems.push(...validateVariantSet(files.map((f) => ({ id: f.id, variant: f.variant })), ctx, { allowReuse: bool(o, 'allow-reuse'), requireLanguages: bool(o, 'require-languages') }));
  if (problems.length) env.out(formatProblems(problems));
  const errors = problems.filter((p) => p.severity === 'error').length;
  env.out(`${files.length} variant(s): ${errors} error(s), ${problems.length - errors} warning(s)`);
  return errors ? 1 : 0;
}

async function cmdImport(env: Env, o: Opts): Promise<number> {
  const all = loadBlueprints(env.paths.blueprints);
  const bank = loadBank(env.paths.bank, { strict: true });
  const bpIds = list(o, 'blueprint');
  const projectId = str(o, 'project') ?? process.env.GCLOUD_PROJECT ?? DEFAULT_PROJECT_ID;
  const batchSize = num(o, 'batch-size', MAX_BATCH);
  const plan = buildImportPlan({
    projectId,
    rawBlueprints: loadRawBlueprints(env.paths.blueprints),
    blueprintIds: bpIds.length && !bpIds.includes('all') ? bpIds : null,
    items: new Map(bankItemsList(bank).map((i) => [i.id, i])),
    passages: new Map([...bank.passages].map(([k, v]) => [k, v.passage])),
    variants: loadVariantFiles(env.paths).map((v) => v.file),
    publish: bool(o, 'publish'),
    publishedBy: str(o, 'published-by') ?? 'pipeline',
    includeAllItems: bool(o, 'all-items'),
    ctx: validationContext(all, bank),
    batchSize,
  });
  const planPath = join(env.paths.reports, 'import-plan.json');
  writeJsonAtomic(planPath, { generated_at: nowIso(), ...plan });
  env.out(`project ${projectId}: ${plan.ops.length} upsert(s) in ${plan.batches.length} batch(es) of ≤ ${batchSize}; ${JSON.stringify(plan.summary)}`);
  for (const v of plan.variants) env.out(`  variant ${v.id}: ${v.note}`);
  for (const s of plan.skipped) env.out(`  skipped ${s.id}: ${s.reason}`);
  if (!bool(o, 'commit')) {
    env.out(`DRY RUN — nothing written. Plan: ${relative(env.paths.root, planPath)}. Add --commit to write (no deletes are ever issued).`);
    return 0;
  }
  const db = await env.openDb(projectId);
  const overwrite = bool(o, 'overwrite');
  const report = await commitPlan(plan, db, { batchSize, overwrite });
  writeJsonAtomic(join(env.paths.reports, 'import-report.json'), { generated_at: nowIso(), project_id: projectId, overwrite, ...report });
  env.out(`committed: ${report.written} write(s) in ${report.batches} batch(es); unchanged ${report.unchanged}`);
  env.out(`  published variants left untouched: ${report.skipped_published.join(', ') || '—'}`);
  if (report.skipped_archived.length) env.out(`  archived (unpublished in the admin panel) variants left untouched: ${report.skipped_archived.join(', ')}; run review-sync`);
  if (report.published.length) env.out(`  published (new in Firestore): ${report.published.join(', ')}`);
  if (report.publish_in_admin.length) env.out(`  already in Firestore, status not changed (publish in the admin panel, adminPublishVariant): ${report.publish_in_admin.join(', ')}`);
  for (const b of report.publish_blocked) env.out(`  ${b.id} written as draft, not published: ${b.reason}`);
  for (const c of report.review_conflicts) env.out(`  review kept from Firestore for ${c.id}: remote ${c.remote}, local ${c.local}; run review-sync before the next import`);
  for (const c of report.overwritten) env.out(`  OVERWRITTEN ${c.collection}/${c.id}: ${c.reason}`);
  if (report.cms_conflicts.length) {
    env.out(`  ${report.cms_conflicts.length} document(s) edited outside the pipeline were NOT overwritten (cms_conflicts):`);
    for (const c of report.cms_conflicts) env.out(`    ${c.collection}/${c.id}: ${c.reason}`);
    env.out('  Port the edit into content/bank (git), or rerun with --overwrite to discard it. Details: content/reports/import-report.json');
  }
  for (const c of report.cms_caught_up) {
    const pending = c.pending_fields.length ? `; still differs from the bank: ${c.pending_fields.join(', ')} (the next import writes the bank's values; port them into content/bank to keep them)` : '';
    env.out(`  caught up exam_questions/${c.id}: the admin-panel edit is in the bank; edited_in_cms_at removed, content left as is${pending}`);
  }
  if (report.translation_links_kept.length) {
    env.out(`  ${report.translation_links_kept.length} translation link(s) changed in the admin panel were kept (translation_links_kept):`);
    for (const t of report.translation_links_kept) env.out(`    exam_questions/${t.id}: Firestore ${t.remote ?? 'null'}, bank ${t.local ?? 'null'}`);
    env.out("  Set translation_group_id in content/bank to adopt the link, or rerun with --overwrite to restore the bank's.");
  }
  // Record publication locally so the registry stays honest: only variants this run created as published.
  if (report.published.length) {
    for (const v of loadVariantFiles(env.paths)) {
      if (report.published.includes(v.file.id) && v.file.variant.status !== 'published') {
        v.file.variant.status = 'published';
        v.file.variant.published_at = nowIso();
        v.file.variant.published_by = str(o, 'published-by') ?? 'pipeline';
        writeJsonAtomic(v.path, v.file);
      }
    }
  }
  return 0;
}

async function cmdRegistry(env: Env, o: Opts): Promise<number> {
  const all = loadBlueprints(env.paths.blueprints);
  const bank = loadBank(env.paths.bank, { strict: true });
  const reg = computeRegistry(all, bankItemsList(bank), loadVariantFiles(env.paths).map((v) => v.file), num(o, 'target', 100));
  writeJsonAtomic(env.paths.registryJson, reg);
  writeText(env.paths.registryMd, registryMarkdown(reg));
  env.out(`registry: ${reg.totals.items} item(s), ${reg.totals.drafted} drafted / ${reg.totals.approved} approved / ${reg.totals.published} published variant(s) of ${reg.totals.target_variants}`);
  return 0;
}

async function cmdLint(env: Env, o: Opts): Promise<number> {
  if (bool(o, 'fix')) {
    const bank = loadBank(env.paths.bank);
    for (const f of bank.files) {
      const { changed } = rehashBankFile(f);
      if (changed) {
        saveBankFile(f);
        env.out(`rehashed ${changed} entr(y/ies) in ${relative(env.paths.root, f.path)}`);
      }
    }
  }
  const bank = loadBank(env.paths.bank);
  const problems = lintBank(bank);
  const curriculum = loadCurriculum(env.paths.curriculum);
  const topicIds = new Set(curriculum.subjects.flatMap((s) => s.topics.map((t) => t.id)));
  for (const { item } of bank.items.values()) if (!topicIds.has(item.question.topic_id)) problems.push(`${item.id}: topic ${item.question.topic_id} is not in the curriculum catalog`);
  for (const p of problems) env.out(p);
  env.out(`${bank.items.size} item(s), ${bank.passages.size} passage(s): ${problems.length} problem(s)`);
  return problems.length ? 1 : 0;
}

async function cmdReview(env: Env, o: Opts): Promise<number> {
  const ids = list(o, 'ids');
  const status = str(o, 'status') as ReviewStatus | undefined;
  const by = str(o, 'by');
  if (!ids.length || !status || !by) throw new Error('review needs --ids q_1,q_2 --status methodologist_approved|rejected --by <methodologist uid>');
  if (status !== 'methodologist_approved' && status !== 'rejected') throw new Error('humans set methodologist_approved or rejected; AI statuses come from verify');
  const bank = loadBank(env.paths.bank, { strict: true });
  const files = new Set<string>();
  for (const id of ids) {
    const entry = bank.items.get(id);
    if (!entry) throw new Error(`unknown item ${id}`);
    const it = entry.item;
    if (status === 'methodologist_approved' && it.question.review.status === 'draft' && !bool(o, 'from-draft')) {
      throw new Error(`${id} is a draft (not AI-verified). Pass --from-draft to approve it after a full manual check.`);
    }
    const now = nowIso();
    it.question.review = { status, reviewed_by: by, reviewed_at: now, notes: str(o, 'notes') ?? it.question.review.notes };
    it.question.updated_at = now;
    files.add(entry.file.path);
    env.out(`${id}: ${status} by ${by}`);
  }
  for (const f of bank.files) if (files.has(f.path)) saveBankFile(f);
  return 0;
}

/**
 * Pulls decisions made in the admin panel into the local files: methodologist
 * reviews (exam_questions.review) into the bank, and variant statuses set by
 * adminPublishVariant (archived / published) into content/variants. Reads Firestore only.
 */
async function cmdReviewSync(env: Env, o: Opts): Promise<number> {
  const bank = loadBank(env.paths.bank, { strict: true });
  const items = selectItems(bank, o);
  const projectId = str(o, 'project') ?? process.env.GCLOUD_PROJECT ?? DEFAULT_PROJECT_ID;
  const db = await env.openDb(projectId);
  const ids = items.map((i) => i.id);
  const remote = await db.getExisting('exam_questions', ids);
  const remoteKeys = await db.getExisting('exam_question_keys', ids);
  const { updates, cms_conflicts } = applyRemoteReviews(items, remote, nowIso(), remoteKeys);
  const touched = new Set(updates.map((u) => bank.items.get(u.id)!.file.path));
  for (const f of bank.files) if (touched.has(f.path)) saveBankFile(f);
  for (const u of updates) env.out(`${u.id}: ${u.from} → ${u.to}${u.reviewed_by ? ` (by ${u.reviewed_by})` : ''}`);
  for (const c of cms_conflicts) env.out(`${c.id}: review not pulled, edited outside the pipeline (${c.reason})`);
  env.out(`review-sync ${projectId}: ${remote.size} of ${items.length} item(s) found in Firestore, ${updates.length} updated locally, ${cms_conflicts.length} edited outside the pipeline`);

  const bpIds = list(o, 'blueprint');
  const language = lang(o, false);
  const variantFiles = loadVariantFiles(env.paths).filter(
    (v) => (!bpIds.length || bpIds.includes(v.file.variant.blueprint_id)) && (!language || v.file.variant.language === language),
  );
  const remoteVariants = await db.getExisting('exam_variants', variantFiles.map((v) => v.file.id));
  const vs = applyRemoteVariantStatuses(variantFiles.map((v) => v.file), remoteVariants, nowIso());
  for (const u of vs.updates) {
    const v = variantFiles.find((x) => x.file.id === u.id)!;
    writeJsonAtomic(v.path, v.file);
    env.out(`${u.id}: ${u.from} → ${u.to} (from Firestore)`);
  }
  for (const id of vs.mismatched) env.out(`${id}: published in Firestore with other questions than the local file; status not pulled`);
  env.out(`variants: ${remoteVariants.size} of ${variantFiles.length} found in Firestore, ${vs.updates.length} status(es) updated locally`);
  return 0;
}

/** Read-only export of existing Firestore content (default: legacy `questions`) for `dedup --against`. */
async function cmdExportExisting(env: Env, o: Opts): Promise<number> {
  const collection = str(o, 'collection') ?? 'questions';
  if (!/^[A-Za-z0-9_]+$/.test(collection)) throw new Error('--collection must be a top-level collection name');
  const projectId = str(o, 'project') ?? process.env.GCLOUD_PROJECT ?? DEFAULT_PROJECT_ID;
  const outPath = resolve(env.paths.root, str(o, 'out') ?? join('content', 'external', `${collection}.json`));
  const db = await env.openDb(projectId);
  const docs = await db.exportCollection(collection, num(o, 'limit', 50000));
  writeJsonAtomic(outPath, { exported_at: nowIso(), project_id: projectId, collection, questions: docs });
  env.out(`exported ${docs.length} document(s) of ${collection} to ${relative(env.paths.root, outPath)} (read-only; keep it out of git if it holds licensed content)`);
  return 0;
}

async function cmdSchemas(env: Env): Promise<number> {
  for (const [name, schema] of Object.entries(exportJsonSchemas())) writeJsonAtomic(join(env.paths.schema, `${name}.schema.json`), schema);
  env.out(`JSON Schemas written to ${relative(env.paths.root, env.paths.schema)}`);
  return 0;
}

const HELP = `ORT content pipeline — npm run cli -- <stage> [flags]   (all paths relative to the repo root; --root to override)

  matrix          [--blueprint id|all]
  generate        --blueprint id --language ru|ky|en [--section s --part p --topic t] [--variants 10] [--overgeneration 1.3]
                  [--per-request 5] [--max-items 50] [--max-cost-usd N] [--batch-id id] [--translate-from ru] [--plan]
                  ${COST_FLAG}  (paid; ANTHROPIC_API_KEY; model from CONTENT_MODEL, default ${DEFAULT_MODEL})
  verify          [--batch id | --ids q_..] [--blueprint id] [--language l] [--force] [--max-items N] [--local-only] ${COST_FLAG}
  translate-check [--blueprint id] [--api ${COST_FLAG}]
  dedup           [--threshold 0.85] [--against file.json ...] [--mark]
  assemble        --blueprint id --language l [--count 1 | --numbers 1-5] [--allow-unapproved] [--allow-reuse] [--seed s] [--dry-run]
  timing          [--blueprint id] [--language l] [--margin 0.1]
  validate        [--blueprint id] [--language l] [--publish] [--allow-reuse] [--require-languages]
  import          [--blueprint id ...] [--all-items] [--publish --published-by uid] [--project ${DEFAULT_PROJECT_ID}] [--batch-size 400] [--commit] [--overwrite]
                  (--overwrite also replaces questions/keys/passages/draft variants and translation links edited in the admin panel; never a variant's status)
  registry        [--target 100]
  lint            [--fix]
  review          --ids q_..,q_.. --status methodologist_approved|rejected --by <uid> [--notes text] [--from-draft]
  review-sync     [--blueprint id] [--batch id] [--project ${DEFAULT_PROJECT_ID}]   (reads exam_questions.review and exam_variants.status from Firestore into content/)
  export-existing [--collection questions] [--out content/external/questions.json] [--limit 50000]   (read-only, for dedup --against)
  schemas

  Paid stages never run without ${COST_FLAG}; import never writes without --commit and never deletes.
`;

export async function main(argv: string[], out: (line: string) => void = (l) => console.log(l), deps: CliDeps = {}): Promise<number> {
  const { cmd, opts } = parseArgs(argv);
  if (cmd === 'help' || bool(opts, 'help')) {
    out(HELP);
    return 0;
  }
  const root = str(opts, 'root') ?? findRepoRoot();
  const env: Env = { paths: pathsFor(root), out, openDb: deps.openFirestore ?? openFirestore };
  const commands: Record<string, (e: Env, o: Opts) => Promise<number>> = {
    matrix: cmdMatrix,
    generate: cmdGenerate,
    verify: cmdVerify,
    'translate-check': cmdTranslateCheck,
    dedup: cmdDedup,
    assemble: cmdAssemble,
    timing: cmdTiming,
    validate: cmdValidate,
    import: cmdImport,
    registry: cmdRegistry,
    lint: cmdLint,
    review: cmdReview,
    'review-sync': cmdReviewSync,
    'export-existing': cmdExportExisting,
    schemas: (e) => cmdSchemas(e),
  };
  const fn = commands[cmd];
  if (!fn) {
    out(`unknown stage ${cmd}\n\n${HELP}`);
    return 2;
  }
  return fn(env, opts);
}

if (require.main === module) {
  main(process.argv.slice(2)).then(
    (code) => process.exit(code),
    (e: unknown) => {
      console.error(e instanceof Error ? e.message : e);
      process.exit(1);
    },
  );
}

export { REVIEW_RANK, hasErrors };
