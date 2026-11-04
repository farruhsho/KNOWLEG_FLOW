import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { CODE_ALPHABET, generateShortCode, isPromoCode, isShortCode, normalizeCode, SHORT_CODE_LENGTH } from '../src/domain/codes';

describe('codes (ARCHITECTURE §9)', () => {
  it('alphabet has 32 unambiguous characters (no 0/O, 1/I)', () => {
    assert.equal(CODE_ALPHABET.length, 32);
    assert.equal(new Set(CODE_ALPHABET).size, 32);
    for (const c of ['0', 'O', '1', 'I']) assert.ok(!CODE_ALPHABET.includes(c), c);
  });

  it('generateShortCode is deterministic for injected randomness and always well formed', () => {
    assert.equal(generateShortCode(() => 0), 'AAAAAA');
    assert.equal(generateShortCode(() => 31), '999999');
    let seed = 7;
    const lcg = (n: number) => (seed = (seed * 1103515245 + 12345) % 2 ** 31) % n;
    for (let i = 0; i < 200; i++) {
      const c = generateShortCode(lcg);
      assert.equal(c.length, SHORT_CODE_LENGTH);
      assert.ok(isShortCode(c), c);
    }
    assert.throws(() => generateShortCode(() => 32));
    assert.throws(() => generateShortCode(() => -1));
  });

  it('normalizeCode upper-cases and strips spaces and dashes; rejects non-strings and huge input', () => {
    assert.equal(normalizeCode(' abc-def '), 'ABCDEF');
    assert.equal(normalizeCode('ab cd\tef'), 'ABCDEF');
    assert.equal(normalizeCode(''), null);
    assert.equal(normalizeCode('   '), null);
    assert.equal(normalizeCode(42), null);
    assert.equal(normalizeCode(null), null);
    assert.equal(normalizeCode('A'.repeat(65)), null);
  });

  it('isShortCode accepts exactly 6 alphabet characters', () => {
    assert.ok(isShortCode('ABC234'));
    assert.ok(!isShortCode('ABC23'));
    assert.ok(!isShortCode('ABC2345'));
    assert.ok(!isShortCode('ABC10O'), 'ambiguous characters');
    assert.ok(!isShortCode('abc234'), 'lower case must be normalized first');
    assert.ok(!isShortCode(123456));
  });

  it('isPromoCode accepts 4-20 characters A-Z0-9', () => {
    assert.ok(isPromoCode('WELCOME'));
    assert.ok(isPromoCode('ORT2026'));
    assert.ok(isPromoCode('ABCD'));
    assert.ok(isPromoCode('A'.repeat(20)));
    assert.ok(!isPromoCode('ABC'));
    assert.ok(!isPromoCode('A'.repeat(21)));
    assert.ok(!isPromoCode('ORT_2026'));
    assert.ok(!isPromoCode('ort2026'));
    assert.ok(!isPromoCode('ОРТ2026'), 'Cyrillic');
  });
});
