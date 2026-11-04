import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { checkArithmetic, evaluatePlain, evaluateText, latexToPlain, ratToString } from '../src/arith';
import { BankFile } from '../src/schema';
import { readJson } from '../src/io';
import { join } from 'node:path';
import { REPO_PATHS } from './fixtures';

const val = (s: string): string | null => {
  const r = evaluateText(s);
  return r ? ratToString(r) : null;
};

describe('arithmetic checker', () => {
  it('evaluates exactly with rationals', () => {
    assert.equal(ratToString(evaluatePlain('0.1+0.2')), '3/10');
    assert.equal(ratToString(evaluatePlain('2^10-10^3')), '24');
    assert.equal(ratToString(evaluatePlain('2(3+4)')), '14');
    assert.equal(ratToString(evaluatePlain('-2^2')), '-4');
    assert.equal(ratToString(evaluatePlain('sqrt(49/4)')), '7/2');
  });

  it('reads the LaTeX subset and Russian/Kyrgyz percent phrases', () => {
    assert.equal(val('$\\frac{3}{4} + \\frac{5}{6} - \\frac{1}{3}$'), '5/4');
    assert.equal(val('$2{,}5 \\cdot 4$'), '10');
    assert.equal(val('$\\sqrt{81} : 3$'), '3');
    assert.equal(val('15 % от 80'), '12');
    assert.equal(val('80 санынын 15 пайызы'), '12');
    assert.equal(val('$12 \\%$'), '3/25');
  });

  it('never guesses: variables, irrational roots and words are not computable', () => {
    assert.equal(latexToPlain('$x^2$'), null);
    assert.equal(val('$\\sqrt{2}$'), null);
    assert.equal(val('Площадь треугольника'), null);
    assert.equal(val('$\\pi$'), null);
  });

  it('re-derives the keys of the sample items and catches a wrong key', () => {
    const sample = BankFile.parse(readJson(join(REPO_PATHS.bank, 'sample', 'items.json')));
    const fractions = sample.items.find((i) => i.question.language === 'ru' && i.question.stem.startsWith('Вычислите'))!;
    assert.deepEqual(checkArithmetic(fractions), { checked: true, ok: true, detail: 'value 5/4 = option C' });
    const wrong = { ...fractions, key: { ...fractions.key, correct: 'A' as const } };
    assert.equal(checkArithmetic(wrong).ok, false);

    const powers = sample.items.find((i) => i.question.language === 'ky' && i.question.table?.rows[0]?.[0] === '$2^{10}$')!;
    assert.equal(checkArithmetic(powers).ok, true);
    assert.equal(checkArithmetic({ ...powers, key: { ...powers.key, correct: 'C' } }).ok, false);

    const symbolic = sample.items.find((i) => i.question.table?.rows[0]?.[0] === '$x^2$')!;
    assert.equal(checkArithmetic(symbolic).checked, false, 'symbolic comparison is left to the blind solver');
  });
});
