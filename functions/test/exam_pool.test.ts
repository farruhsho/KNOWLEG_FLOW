import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import type { PoolItem } from '../src/domain/assembly';
import { assertCanStartNew, parseEntitlement } from '../src/domain/entitlements';
import {
  assertFreshBlueprint,
  freshVariantId,
  inferPassageLayouts,
  isFreshVariantId,
  keyFitsPoolItem,
  lastSeenMap,
  parseExamPoolConfig,
  parseExamPoolUpdate,
  parseExamStartInput,
  passageLayoutOf,
  poolItemFromDoc,
  POOL_FIELDS,
  SEEN_ATTEMPTS_WINDOW,
} from '../src/domain/exam_pool';
import {
  applySectionSubmit,
  assertSectionOver,
  buildInitialAttempt,
  flagsForStyle,
  STRICT_EARLY_SUBMIT_MS,
} from '../src/domain/exam_session';
import { buildSessionPayload } from '../src/domain/payload';
import { DomainError } from '../src/domain/reasons';
import { blueprint, buildBank } from './fixtures';

function reasonOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    return e instanceof DomainError ? `${e.reason}${e.extra?.['field'] ? `:${String(e.extra['field'])}` : ''}${e.extra?.['why'] ? `:${String(e.extra['why'])}` : ''}` : String(e);
  }
  return undefined;
}

describe('parseExamStartInput', () => {
  it('a variantId means library mode (the phase 1–3 client), standard style', () => {
    assert.deepEqual(parseExamStartInput({ variantId: 'v1', clientAppVersion: '1.0.0+1' }), {
      mode: 'library',
      variantId: 'v1',
      examStyle: 'standard',
      clientAppVersion: '1.0.0+1',
    });
  });

  it('fresh needs blueprintId and language; mode defaults to fresh without a variantId', () => {
    assert.deepEqual(parseExamStartInput({ blueprintId: 'ort_main_2026', language: 'ru', examStyle: 'strict' }), {
      mode: 'fresh',
      blueprintId: 'ort_main_2026',
      language: 'ru',
      examStyle: 'strict',
      clientAppVersion: '',
    });
    assert.equal(parseExamStartInput({ mode: 'fresh', blueprintId: 'b', language: 'ky' }).mode, 'fresh');
    assert.equal(reasonOf(() => parseExamStartInput({ mode: 'fresh', language: 'ru' })), 'VALIDATION_FAILED:blueprintId');
    assert.equal(reasonOf(() => parseExamStartInput({ mode: 'fresh', blueprintId: 'b' })), 'VALIDATION_FAILED:language');
    assert.equal(reasonOf(() => parseExamStartInput({ mode: 'fresh', blueprintId: 'b', language: 'de' })), 'VALIDATION_FAILED:language');
    assert.equal(reasonOf(() => parseExamStartInput({})), 'VALIDATION_FAILED:blueprintId');
  });

  it('rejects unknown modes and styles, bad ids and long versions', () => {
    assert.equal(reasonOf(() => parseExamStartInput({ variantId: 'v', mode: 'random' })), 'VALIDATION_FAILED:mode');
    assert.equal(reasonOf(() => parseExamStartInput({ variantId: 'v', examStyle: 'easy' })), 'VALIDATION_FAILED:examStyle');
    assert.equal(reasonOf(() => parseExamStartInput({ mode: 'library' })), 'VALIDATION_FAILED:variantId');
    assert.equal(reasonOf(() => parseExamStartInput({ variantId: 'a/b' })), 'VALIDATION_FAILED:variantId');
    assert.equal(reasonOf(() => parseExamStartInput({ variantId: 'v', clientAppVersion: 'x'.repeat(41) })), 'VALIDATION_FAILED:clientAppVersion');
  });
});

describe('assertFreshBlueprint', () => {
  it('accepts the languages the blueprint lists (state language: ky only; English: en only)', () => {
    assertFreshBlueprint(blueprint('ort_main_2026'), 'ru');
    assertFreshBlueprint(blueprint('ort_state_language_2026'), 'ky');
    assertFreshBlueprint(blueprint('ort_subject_english_2026'), 'en');
    assert.equal(reasonOf(() => assertFreshBlueprint(blueprint('ort_state_language_2026'), 'ru')), 'VALIDATION_FAILED:language');
    assert.equal(reasonOf(() => assertFreshBlueprint(blueprint('ort_subject_english_2026'), 'ru')), 'VALIDATION_FAILED:language');
  });

  it('refuses a retired blueprint', () => {
    const bp = { ...blueprint('ort_main_2026'), status: 'retired' };
    assert.equal(reasonOf(() => assertFreshBlueprint(bp, 'ru')), 'VARIANT_NOT_AVAILABLE:blueprint_inactive');
  });
});

describe('config/exam_pool', () => {
  it('defaults: fresh on, methodologist_approved floor', () => {
    assert.deepEqual(parseExamPoolConfig(undefined), { fresh_enabled: true, min_review_status: 'methodologist_approved' });
    assert.deepEqual(parseExamPoolConfig({ fresh_enabled: 'yes', min_review_status: 'draft' }), { fresh_enabled: true, min_review_status: 'methodologist_approved' });
    assert.deepEqual(parseExamPoolConfig({ fresh_enabled: false, min_review_status: 'ai_verified' }), { fresh_enabled: false, min_review_status: 'ai_verified' });
  });

  it('adminUpdateExamPool input', () => {
    assert.deepEqual(parseExamPoolUpdate({ freshEnabled: false }), { fresh_enabled: false });
    assert.deepEqual(parseExamPoolUpdate({ minReviewStatus: 'ai_verified' }), { min_review_status: 'ai_verified' });
    assert.equal(reasonOf(() => parseExamPoolUpdate({})), 'VALIDATION_FAILED:freshEnabled');
    assert.equal(reasonOf(() => parseExamPoolUpdate({ freshEnabled: 1 })), 'VALIDATION_FAILED:freshEnabled');
    assert.equal(reasonOf(() => parseExamPoolUpdate({ minReviewStatus: 'draft' })), 'VALIDATION_FAILED:minReviewStatus');
  });
});

describe('pool documents', () => {
  const doc = {
    section_id: 'reading',
    part_id: 'reading',
    topic_id: 'reading.detail',
    difficulty: 2,
    passage_id: 'p1',
    passage_order: 3,
    review: { status: 'ai_verified' },
  };

  it('maps an exam_questions document to a pool item', () => {
    assert.deepEqual(poolItemFromDoc('q1', doc, 'ort_main_2026'), {
      id: 'q1',
      section_id: 'reading',
      part_id: 'reading',
      topic_id: 'reading.detail',
      difficulty: 2,
      passage_id: 'p1',
      passage_order: 3,
      review_status: 'ai_verified',
    });
    assert.equal(poolItemFromDoc('q1', { ...doc, blueprint_id: 'ort_main_2026' }, 'ort_main_2026')?.id, 'q1');
  });

  it('drops rejected, deduplicated, foreign-blueprint and malformed items', () => {
    assert.equal(poolItemFromDoc('q', { ...doc, review: { status: 'rejected' } }, 'b'), null);
    assert.equal(poolItemFromDoc('q', { ...doc, dedup_excluded: true }, 'b'), null);
    assert.equal(poolItemFromDoc('q', { ...doc, duplicate_of: 'q0' }, 'b'), null);
    assert.equal(poolItemFromDoc('q', { ...doc, blueprint_id: 'ort_main_2027' }, 'ort_main_2026'), null);
    assert.equal(poolItemFromDoc('q', { ...doc, difficulty: 5 }, 'b'), null);
    assert.equal(poolItemFromDoc('q', { ...doc, topic_id: '' }, 'b'), null);
    assert.equal(poolItemFromDoc('q', { ...doc, part_id: null }, 'b'), null);
    assert.equal(poolItemFromDoc('q', null, 'b'), null);
    assert.equal(poolItemFromDoc('q', { ...doc, review: undefined }, 'b')?.review_status, 'draft');
  });

  it('drops items the importer flags out of assembly (failed translation check)', () => {
    assert.equal(poolItemFromDoc('q', { ...doc, assembly_excluded: true }, 'b'), null);
    assert.equal(poolItemFromDoc('q', { ...doc, assembly_excluded: false, dedup_excluded: false }, 'b')?.id, 'q');
    assert.ok(POOL_FIELDS.includes('dedup_excluded') && POOL_FIELDS.includes('assembly_excluded') && POOL_FIELDS.includes('duplicate_of'));
  });

  it('passage layout: standalone | paired, anything else unknown', () => {
    assert.equal(passageLayoutOf({ layout: 'paired' }), 'paired');
    assert.equal(passageLayoutOf({ layout: 'standalone' }), 'standalone');
    assert.equal(passageLayoutOf({ title: 'x' }), 'unknown');
    assert.equal(passageLayoutOf(undefined), 'unknown');
  });
});

describe('pool documents: the per-question checks of the blueprint part (as validateVariant)', () => {
  const bp = blueprint('ort_main_2026');
  const partOf = (sectionId: string, partId: string) => bp.sections.find((s) => s.id === sectionId)!.parts.find((p) => p.id === partId)!;
  const opts = (n: number) => Array.from({ length: n }, (_, k) => ({ id: String.fromCharCode(65 + k), text: `вариант ${k + 1}` }));
  const grammar = {
    section_id: 'grammar', part_id: 'grammar', topic_id: 'grammar.morphology', difficulty: 2, language: 'ru',
    type: 'single_choice', stem: 'Укажите верный вариант.', options: opts(4), passage_id: null, review: { status: 'ai_verified' },
  };
  const comparison = {
    section_id: 'math', part_id: 'math_comparison', topic_id: 'math.numbers', difficulty: 1, language: 'ru',
    type: 'quantitative_comparison', stem: '', column_a: '$2^3$', column_b: '$3^2$', options: [], passage_id: null, review: { status: 'ai_verified' },
  };
  const reading = {
    section_id: 'reading', part_id: 'reading', topic_id: 'reading.detail', difficulty: 2, language: 'ru',
    type: 'text_based', stem: 'О чём говорится в первом абзаце?', options: opts(4), passage_id: 'p1', passage_order: 1, review: { status: 'ai_verified' },
  };

  it('a valid item passes and carries the option ids its key must name', () => {
    assert.deepEqual(poolItemFromDoc('g1', grammar, bp.id, partOf('grammar', 'grammar'))?.answer_ids, ['A', 'B', 'C', 'D']);
    // Quantitative comparison: the blueprint's fixed options, no stem needed with both columns.
    assert.deepEqual(poolItemFromDoc('c1', comparison, bp.id, partOf('math', 'math_comparison'))?.answer_ids, ['A', 'B', 'C', 'D']);
    assert.equal(poolItemFromDoc('r1', reading, bp.id, partOf('reading', 'reading'))?.passage_id, 'p1');
    // Analogy / completion / text-based items may be stored as single_choice.
    assert.equal(poolItemFromDoc('r2', { ...reading, type: 'single_choice' }, bp.id, partOf('reading', 'reading'))?.id, 'r2');
  });

  it('drops a type that does not match the part', () => {
    assert.equal(poolItemFromDoc('g', { ...grammar, type: 'quantitative_comparison' }, bp.id, partOf('grammar', 'grammar')), null);
    assert.equal(poolItemFromDoc('c', { ...comparison, type: 'single_choice' }, bp.id, partOf('math', 'math_comparison')), null);
  });

  it('drops an option count other than options_per_question (not for quantitative comparison)', () => {
    assert.equal(poolItemFromDoc('g', { ...grammar, options: opts(5) }, bp.id, partOf('grammar', 'grammar')), null);
    assert.equal(poolItemFromDoc('g', { ...grammar, options: opts(3) }, bp.id, partOf('grammar', 'grammar')), null);
    assert.equal(poolItemFromDoc('m', { ...grammar, section_id: 'math', part_id: 'math_problems', options: opts(4) }, bp.id, partOf('math', 'math_problems')), null);
    assert.equal(poolItemFromDoc('m', { ...grammar, section_id: 'math', part_id: 'math_problems', options: opts(5) }, bp.id, partOf('math', 'math_problems'))?.id, 'm');
  });

  it('drops an empty stem (unless both comparison columns or an image are there)', () => {
    assert.equal(poolItemFromDoc('g', { ...grammar, stem: '   ' }, bp.id, partOf('grammar', 'grammar')), null);
    assert.equal(poolItemFromDoc('g', { ...grammar, stem: '', image_path: 'exam/img.png' }, bp.id, partOf('grammar', 'grammar'))?.id, 'g');
    assert.equal(poolItemFromDoc('c', { ...comparison, column_b: null }, bp.id, partOf('math', 'math_comparison')), null);
  });

  it('drops a text_based item without a passage', () => {
    assert.equal(poolItemFromDoc('r', { ...reading, passage_id: null }, bp.id, partOf('reading', 'reading')), null);
  });

  it('the key must be one of the item options (the fixed options for comparison)', () => {
    const g = poolItemFromDoc('g1', grammar, bp.id, partOf('grammar', 'grammar'))!;
    assert.equal(keyFitsPoolItem(g, 'B'), true);
    assert.equal(keyFitsPoolItem(g, ' C '), true);
    assert.equal(keyFitsPoolItem(g, 'E'), false);
    assert.equal(keyFitsPoolItem(g, ''), false);
    assert.equal(keyFitsPoolItem(g, null), false);
    const c = poolItemFromDoc('c1', { ...comparison, options: opts(2) }, bp.id, partOf('math', 'math_comparison'))!;
    assert.equal(keyFitsPoolItem(c, 'D'), true, 'fixed options, not the stored ones');
    assert.equal(keyFitsPoolItem(c, 'E'), false);
    // Without the part checks only a non-empty key is required.
    assert.equal(keyFitsPoolItem(poolItemFromDoc('x', grammar, bp.id)!, 'Z'), true);
  });

  it('every item of the committed ort_main_2026 ru banks passes (pilot + set 2)', () => {
    const dir = path.resolve(__dirname, '..', '..', 'content', 'bank');
    let n = 0;
    for (const d of readdirSync(dir).filter((x) => x.startsWith('pilot_main_ru_v1_') || x.startsWith('main_ru_v2_'))) {
      const f = JSON.parse(readFileSync(path.join(dir, d, 'items.json'), 'utf8')) as { items: Array<{ id: string; target: { blueprint_id: string; part_id: string }; passage_order: number | null; question: Record<string, unknown>; key: { correct: string } }> };
      for (const it of f.items) {
        const q = it.question;
        const section = bp.sections.find((s) => s.id === q['section_id'])!;
        const part = section.parts.find((p) => p.id === it.target.part_id)!;
        const item = poolItemFromDoc(it.id, { ...q, part_id: it.target.part_id, blueprint_id: it.target.blueprint_id, passage_order: it.passage_order }, bp.id, part);
        assert.ok(item, `${d}/${it.id} passes the part checks`);
        assert.equal(keyFitsPoolItem(item, it.key.correct), true, `${d}/${it.id} key`);
        n++;
      }
    }
    assert.equal(n, 300);
  });
});

describe('inferPassageLayouts', () => {
  const item = (id: string, passageId: string, topic: string, subtopic: string | null = null) => ({
    id, section_id: 'reading', part_id: 'reading', topic_id: topic, subtopic_id: subtopic, difficulty: 2, passage_id: passageId, passage_order: null, review_status: 'ai_verified',
  });

  it('keeps stored layouts; a passage without one is paired only when a question names the paired comparison', () => {
    const items = [
      item('a1', 'pa', 'reading.detail'),
      item('a2', 'pa', 'reading.inference'),
      item('b1', 'pb', 'reading.detail'),
      item('b2', 'pb', 'reading.paired_comparison'),
      item('c1', 'pc', 'reading.detail', 'reading.paired.contrast'),
      item('d1', 'pd', 'reading.detail'),
    ];
    const stored = new Map<string, 'standalone' | 'paired' | 'unknown'>([
      ['pa', 'unknown'],
      ['pb', 'unknown'],
      ['pc', 'unknown'],
      ['pd', 'paired'],
      ['pe', 'unknown'],
    ]);
    const out = inferPassageLayouts(items, stored);
    assert.deepEqual(Object.fromEntries([...out].map(([id, p]) => [id, p.layout])), { pa: 'standalone', pb: 'paired', pc: 'paired', pd: 'paired', pe: 'standalone' });
    assert.ok([...out.values()].every((p) => p.layout !== 'unknown'));
  });

  it('the pilot bank imported without layouts assembles with the real paired text last', () => {
    const dir = path.resolve(__dirname, '..', '..', 'content', 'bank');
    const items: PoolItem[] = [];
    const truth = new Map<string, string>();
    for (const d of readdirSync(dir).filter((x) => x.startsWith('pilot_main_ru_v1_reading_'))) {
      const f = JSON.parse(readFileSync(path.join(dir, d, 'items.json'), 'utf8')) as {
        passages: Array<{ id: string; layout: string }>;
        items: Array<{ id: string; question: { topic_id: string; subtopic_id: string | null; difficulty: number; passage_id: string } }>;
      };
      for (const p of f.passages) truth.set(p.id, p.layout);
      for (const it of f.items) items.push({ ...item(it.id, it.question.passage_id, it.question.topic_id, it.question.subtopic_id), difficulty: it.question.difficulty });
    }
    const inferred = inferPassageLayouts(items, new Map([...truth.keys()].map((id) => [id, 'unknown' as const])));
    for (const [id, layout] of truth) assert.equal(inferred.get(id)!.layout, layout, id);
  });
});

describe('assertCanStartNew (fresh pre-check before the pool is loaded)', () => {
  it('NO_ENTITLEMENT without a free exam or a credit; otherwise passes', () => {
    const ent = (o: Partial<ReturnType<typeof parseEntitlement>> = {}) => ({ ...parseEntitlement(undefined), ...o });
    assertCanStartNew(ent(), 1);
    assertCanStartNew(ent({ free_exams_used_count: 1, credits: 1 }), 1);
    assert.equal(reasonOf(() => assertCanStartNew(ent({ free_exams_used_count: 1 }), 1)), 'NO_ENTITLEMENT');
    assert.equal(reasonOf(() => assertCanStartNew(ent(), 0)), 'NO_ENTITLEMENT');
  });
});

describe('lastSeenMap', () => {
  it('keeps the most recent attempt time per question, at most the last 50 attempts', () => {
    const m = lastSeenMap([
      { started_at: 100, question_ids: ['a', 'b'] },
      { started_at: 300, question_ids: ['b', 'c'] },
      { started_at: 200, question_ids: ['a'] },
    ]);
    assert.deepEqual([...m.entries()].sort(), [
      ['a', 200],
      ['b', 300],
      ['c', 300],
    ]);
    const many = Array.from({ length: SEEN_ATTEMPTS_WINDOW + 5 }, (_, i) => ({ started_at: i, question_ids: [`q${i}`] }));
    const w = lastSeenMap(many);
    assert.equal(w.size, SEEN_ATTEMPTS_WINDOW);
    assert.equal(w.has('q0'), false, 'the oldest attempts fall out of the window');
  });

  it('fresh variant ids', () => {
    assert.equal(freshVariantId('abc'), 'fresh_abc');
    assert.equal(isFreshVariantId('fresh_abc'), true);
    assert.equal(isFreshVariantId('v_ort_main_2026_ru_001'), false);
  });
});

describe('strict ORT style (§10.2)', () => {
  const bp = blueprint('ort_main_2026');
  const T0 = 1_762_000_000_000;
  const attempt = (examStyle: 'standard' | 'strict') =>
    buildInitialAttempt({ uid: 'u', variant: buildBank(bp).variant, blueprint: bp, nowMs: T0, entitlementSource: 'credit', clientAppVersion: '1', examStyle });

  it('a strict section cannot be submitted before deadline − 5 s (SECTION_NOT_OVER with the deadline)', () => {
    const a = attempt('strict');
    const deadline = a.sections[0]!.deadline_at!;
    assert.equal(deadline, T0 + 90 * 60_000);
    try {
      assertSectionOver(a, T0 + 60_000);
      assert.fail('expected SECTION_NOT_OVER');
    } catch (e) {
      assert.ok(e instanceof DomainError);
      assert.equal(e.reason, 'SECTION_NOT_OVER');
      assert.equal(e.code, 'failed-precondition');
      assert.deepEqual(e.extra, { deadlineAt: deadline, serverNow: T0 + 60_000 });
    }
    assert.equal(reasonOf(() => assertSectionOver(a, deadline - STRICT_EARLY_SUBMIT_MS - 1)), 'SECTION_NOT_OVER');
    assertSectionOver(a, deadline - STRICT_EARLY_SUBMIT_MS);
    assertSectionOver(a, deadline + 10_000);
  });

  it('the next strict section is checked against its own deadline', () => {
    const a = attempt('strict');
    const t1 = a.sections[0]!.deadline_at!;
    const next = applySectionSubmit(a, bp, 'math', t1).attempt;
    assert.equal(next.exam_style, 'strict');
    assert.equal(reasonOf(() => assertSectionOver(next, t1 + 1_000)), 'SECTION_NOT_OVER');
    assertSectionOver(next, next.sections[1]!.deadline_at! - 1_000);
  });

  it('standard attempts are never blocked and keep their flags; strict drops flags', () => {
    assertSectionOver(attempt('standard'), T0 + 1);
    assert.deepEqual(flagsForStyle('standard', ['q1']), ['q1']);
    assert.deepEqual(flagsForStyle('strict', ['q1']), []);
  });

  it('attempts carry style, source and freshness into the payload', () => {
    const bank = buildBank(bp);
    const fresh = buildInitialAttempt({
      uid: 'u',
      variant: bank.variant,
      blueprint: bp,
      nowMs: T0,
      entitlementSource: 'free_first',
      clientAppVersion: '1',
      examStyle: 'strict',
      source: 'fresh',
      freshness: { total: 150, repeated: 12 },
    });
    const p = buildSessionPayload({ attemptId: 'a1', attempt: fresh, blueprint: bp, questions: bank.questions, passages: new Map(), nowMs: T0 });
    assert.equal(p.examStyle, 'strict');
    assert.equal(p.source, 'fresh');
    assert.deepEqual(p.freshness, { total: 150, repeated: 12 });
    const lib = buildSessionPayload({ attemptId: 'a2', attempt: attempt('standard'), blueprint: bp, questions: bank.questions, passages: new Map(), nowMs: T0 });
    assert.deepEqual([lib.examStyle, lib.source, lib.freshness], ['standard', 'library', null]);
  });
});
