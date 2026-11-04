import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/domain/reasons';
import { buildContextBlock, buildTutorMessages, refusalText, TUTOR_SYSTEM_PROMPT } from '../src/domain/tutor_prompt';
import {
  decideQuota,
  DEFAULT_DAILY_LIMIT,
  estimateCostUsd,
  MAX_HISTORY_ITEMS,
  parseTutorConfig,
  sanitizeTutorInput,
} from '../src/domain/tutor_quota';

describe('tutor quota', () => {
  it('defaults to 15/day and clamps config', () => {
    assert.equal(parseTutorConfig(undefined).daily_limit, DEFAULT_DAILY_LIMIT);
    assert.equal(parseTutorConfig(undefined).enabled, true);
    assert.equal(parseTutorConfig({ daily_limit: 9999, max_tokens: 10 }).daily_limit, 500);
    assert.equal(parseTutorConfig({ max_tokens: 10 }).max_tokens, 300);
    assert.equal(parseTutorConfig({ enabled: false }).enabled, false);
  });

  it('allows until the limit is reached', () => {
    assert.deepEqual(decideQuota(0, 15), { allowed: true, remainingAfter: 14 });
    assert.deepEqual(decideQuota(14, 15), { allowed: true, remainingAfter: 0 });
    assert.deepEqual(decideQuota(15, 15), { allowed: false, remainingAfter: 0 });
  });

  it('estimates cost from usage', () => {
    const usd = estimateCostUsd('claude-opus-5-5', { input_tokens: 1_000_000, output_tokens: 0, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 });
    assert.equal(usd, 4);
  });
});

describe('sanitizeTutorInput', () => {
  it('validates mode, message and language', () => {
    assert.throws(() => sanitizeTutorInput({ mode: 'hack', message: 'x' }), DomainError);
    assert.throws(() => sanitizeTutorInput({ mode: 'chat', message: '   ' }), DomainError);
    assert.throws(() => sanitizeTutorInput({ mode: 'chat', message: 'x'.repeat(2001) }), DomainError);
    assert.throws(() => sanitizeTutorInput({ mode: 'chat', message: 'hi', questionId: '../etc' }), DomainError);
    const ok = sanitizeTutorInput({ mode: 'step_by_step', message: ' Реши ', language: 'ky', questionId: 'q_1' });
    assert.equal(ok.message, 'Реши');
    assert.equal(ok.language, 'ky');
    assert.equal(ok.questionId, 'q_1');
    assert.equal(sanitizeTutorInput({ mode: 'chat', message: 'x', language: 'de' }).language, 'ru');
  });

  it('trims history to the last turns and starts it with a user turn', () => {
    const history = Array.from({ length: 15 }, (_, i) => ({ role: i % 2 === 0 ? 'user' : 'assistant', text: `t${i}` }));
    const out = sanitizeTutorInput({ mode: 'chat', message: 'next', history });
    assert.ok(out.history.length <= MAX_HISTORY_ITEMS);
    assert.equal(out.history[0]!.role, 'user');
    assert.ok(out.history.every((h) => h.role === 'user' || h.role === 'assistant'));
  });
});

describe('tutor prompt', () => {
  it('system prompt is static and demands step-by-step reasoning in ru/ky', () => {
    assert.match(TUTOR_SYSTEM_PROMPT, /step by step/);
    assert.match(TUTOR_SYSTEM_PROMPT, /Never answer with only a letter/);
    assert.match(TUTOR_SYSTEM_PROMPT, /Kyrgyz/);
    assert.match(TUTOR_SYSTEM_PROMPT, /cheat/);
    assert.ok(!/\d{4}-\d{2}-\d{2}T/.test(TUTOR_SYSTEM_PROMPT), 'no timestamps in the cached prefix');
  });

  it('context block carries mode, language and question context in the last user turn', () => {
    const block = buildContextBlock('explain_mistake', 'ky', {
      stem: '2+2=?',
      options: [{ id: 'A', text: '4' }, { id: 'B', text: '5' }],
      userAnswer: 'B',
      correct: 'A',
      explanation: 'arithmetic',
    });
    assert.match(block, /reply language: Kyrgyz/);
    assert.match(block, /student answer: B/);
    assert.match(block, /reference answer: A/);
    const msgs = buildTutorMessages([{ role: 'user', text: 'hi' }, { role: 'assistant', text: 'hello' }], 'why?', block);
    assert.equal(msgs.length, 3);
    assert.equal(msgs[2]!.role, 'user');
    assert.ok(msgs[2]!.content.startsWith('why?'));
  });

  it('refusal text exists in both languages', () => {
    assert.match(refusalText('ru'), /ОРТ/);
    assert.match(refusalText('ky'), /ЖРТ/);
  });
});
