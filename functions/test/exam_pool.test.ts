import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  assertFreshBlueprint,
  freshVariantId,
  isFreshVariantId,
  lastSeenMap,
  parseExamPoolConfig,
  parseExamPoolUpdate,
  parseExamStartInput,
  passageLayoutOf,
  poolItemFromDoc,
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

  it('passage layout: standalone | paired, anything else unknown', () => {
    assert.equal(passageLayoutOf({ layout: 'paired' }), 'paired');
    assert.equal(passageLayoutOf({ layout: 'standalone' }), 'standalone');
    assert.equal(passageLayoutOf({ title: 'x' }), 'unknown');
    assert.equal(passageLayoutOf(undefined), 'unknown');
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
