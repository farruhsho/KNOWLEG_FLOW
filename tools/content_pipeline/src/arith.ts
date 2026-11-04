/**
 * Small exact-arithmetic checker used by the verify stage for maths items.
 * It evaluates pure numeric expressions (integers, decimals with comma or
 * dot, + − × ÷ ^, \frac, \sqrt of perfect squares, "p% от n") with BigInt
 * rationals, so 0,1 + 0,2 is exactly 3/10. Anything with variables or
 * unsupported notation is reported as "not computable" — never guessed.
 */
import { BankItem, OptionId } from './schema';

export interface Rational {
  n: bigint;
  d: bigint;
}

const abs = (x: bigint): bigint => (x < 0n ? -x : x);
function gcd(a: bigint, b: bigint): bigint {
  a = abs(a);
  b = abs(b);
  while (b) [a, b] = [b, a % b];
  return a || 1n;
}
export function rat(n: bigint, d: bigint = 1n): Rational {
  if (d === 0n) throw new Error('division by zero');
  if (d < 0n) {
    n = -n;
    d = -d;
  }
  const g = gcd(n, d);
  return { n: n / g, d: d / g };
}
const add = (a: Rational, b: Rational): Rational => rat(a.n * b.d + b.n * a.d, a.d * b.d);
const sub = (a: Rational, b: Rational): Rational => rat(a.n * b.d - b.n * a.d, a.d * b.d);
const mul = (a: Rational, b: Rational): Rational => rat(a.n * b.n, a.d * b.d);
const div = (a: Rational, b: Rational): Rational => rat(a.n * b.d, a.d * b.n);
export const cmp = (a: Rational, b: Rational): number => {
  const x = a.n * b.d - b.n * a.d;
  return x < 0n ? -1 : x > 0n ? 1 : 0;
};
export const ratToString = (r: Rational): string => (r.d === 1n ? `${r.n}` : `${r.n}/${r.d}`);

function pow(a: Rational, e: Rational): Rational {
  if (e.d !== 1n) {
    if (e.d === 2n && e.n === 1n) return sqrt(a);
    throw new Error('fractional exponent');
  }
  if (abs(e.n) > 64n) throw new Error('exponent too large');
  let r = rat(1n);
  for (let i = 0n; i < abs(e.n); i++) r = mul(r, a);
  return e.n < 0n ? div(rat(1n), r) : r;
}

function isqrt(x: bigint): bigint | null {
  if (x < 0n) return null;
  if (x < 2n) return x;
  let r = BigInt(Math.floor(Math.sqrt(Number(x))));
  while (r * r > x) r--;
  while ((r + 1n) * (r + 1n) <= x) r++;
  return r * r === x ? r : null;
}

function sqrt(a: Rational): Rational {
  const n = isqrt(a.n);
  const d = isqrt(a.d);
  if (n === null || d === null) throw new Error('irrational square root');
  return rat(n, d);
}

/** Converts the LaTeX subset to a plain infix string, or null if unsupported markup remains. */
export function latexToPlain(src: string): string | null {
  let s = src.replace(/\$/g, ' ').replace(/\\left|\\right/g, '').replace(/\\[,;:! ]/g, '');
  s = s.replace(/\{,\}/g, '.').replace(/(\d),(\d)/g, '$1.$2');
  s = s.replace(/\\cdot|\\times|×|·/g, '*').replace(/\\div|÷|:/g, '/').replace(/[−–]/g, '-').replace(/\\%|%/g, '/100');
  // \frac{a}{b}, \dfrac, \sqrt{x}, ^{n} with balanced braces.
  const group = (str: string, i: number): [string, number] | null => {
    if (str[i] !== '{') return null;
    let depth = 0;
    for (let j = i; j < str.length; j++) {
      if (str[j] === '{') depth++;
      else if (str[j] === '}' && --depth === 0) return [str.slice(i + 1, j), j + 1];
    }
    return null;
  };
  const convert = (str: string): string | null => {
    let out = '';
    let i = 0;
    while (i < str.length) {
      const rest = str.slice(i);
      const frac = /^\\d?frac/.exec(rest);
      if (frac) {
        const g1 = group(str, i + frac[0].length);
        if (!g1) return null;
        const g2 = group(str, g1[1]);
        if (!g2) return null;
        const a = convert(g1[0]);
        const b = convert(g2[0]);
        if (a === null || b === null) return null;
        out += `((${a})/(${b}))`;
        i = g2[1];
        continue;
      }
      if (rest.startsWith('\\sqrt')) {
        const g = group(str, i + 5);
        if (!g) return null;
        const a = convert(g[0]);
        if (a === null) return null;
        out += `sqrt(${a})`;
        i = g[1];
        continue;
      }
      if (str[i] === '{') {
        const g = group(str, i);
        if (!g) return null;
        const a = convert(g[0]);
        if (a === null) return null;
        out += `(${a})`;
        i = g[1];
        continue;
      }
      if (str[i] === '\\') return null; // unsupported command
      out += str[i];
      i++;
    }
    return out;
  };
  const plain = convert(s);
  if (plain === null) return null;
  const compact = plain.replace(/\s+/g, '');
  return /^(?:[0-9+\-*/^().]|sqrt)+$/.test(compact) && /\d/.test(compact) ? compact : null;
}

/** Recursive-descent evaluation of the plain infix string. Throws on malformed input. */
export function evaluatePlain(src: string): Rational {
  let i = 0;
  const peek = (): string => src[i] ?? '';
  const number = (): Rational => {
    const m = /^\d+(?:\.\d+)?/.exec(src.slice(i));
    if (!m) throw new Error(`number expected at ${i}`);
    i += m[0].length;
    const [w, f = ''] = m[0].split('.');
    return rat(BigInt(w! + f), 10n ** BigInt(f.length));
  };
  const primary = (): Rational => {
    if (src.startsWith('sqrt(', i)) {
      i += 5;
      const v = expr();
      if (peek() !== ')') throw new Error(') expected');
      i++;
      return sqrt(v);
    }
    if (peek() === '(') {
      i++;
      const v = expr();
      if (peek() !== ')') throw new Error(') expected');
      i++;
      return v;
    }
    return number();
  };
  const power = (): Rational => {
    const base = primary();
    if (peek() === '^') {
      i++;
      return pow(base, unary());
    }
    return base;
  };
  const unary = (): Rational => {
    if (peek() === '-') {
      i++;
      return mul(rat(-1n), unary());
    }
    if (peek() === '+') {
      i++;
      return unary();
    }
    return power();
  };
  const term = (): Rational => {
    let v = unary();
    for (;;) {
      if (peek() === '*') {
        i++;
        v = mul(v, unary());
      } else if (peek() === '/') {
        i++;
        v = div(v, unary());
      } else if (peek() === '(' || /\d/.test(peek())) {
        v = mul(v, unary()); // implicit multiplication: 2(3+4)
      } else return v;
    }
  };
  const expr = (): Rational => {
    let v = term();
    for (;;) {
      if (peek() === '+') {
        i++;
        v = add(v, term());
      } else if (peek() === '-') {
        i++;
        v = sub(v, term());
      } else return v;
    }
  };
  const v = expr();
  if (i !== src.length) throw new Error(`unexpected "${src.slice(i)}"`);
  return v;
}

/** Evaluates a cell/option text: pure arithmetic, or "p% от n" (ru) / "n санынын p пайызы" (ky). */
export function evaluateText(text: string): Rational | null {
  const t = text.trim();
  const num = '(\\d+(?:[.,]\\d+)?)';
  const ru = new RegExp(`^\\$?${num}\\s*\\\\?%\\$?\\s+от\\s+\\$?${num}\\$?$`, 'u').exec(t);
  if (ru) return evaluateSafe(`${ru[1]}*${ru[2]}/100`);
  const ky = new RegExp(`^\\$?${num}\\$?\\s+санынын\\s+\\$?${num}\\s*(?:\\\\?%|пайызы)\\$?\\s*(?:ы|и)?$`, 'u').exec(t);
  if (ky) return evaluateSafe(`${ky[1]}*${ky[2]}/100`);
  const plain = latexToPlain(t);
  return plain === null ? null : evaluateSafe(plain);
}

function evaluateSafe(plain: string): Rational | null {
  try {
    return evaluatePlain(plain.replace(/,/g, '.'));
  } catch {
    return null;
  }
}

export interface ArithmeticCheck {
  checked: boolean;
  ok: boolean | null;
  detail: string;
}

const COMPUTE_STEM = /(вычислите|найдите значение( числового)? выражения|чему равно|эсептеңиз|туюнтманын маанисин табыңыз|канчага барабар)/iu;

/** Re-computes the key of a maths item where the content is plain arithmetic. */
export function checkArithmetic(item: BankItem): ArithmeticCheck {
  const q = item.question;
  if (q.type === 'quantitative_comparison') {
    const row = q.table?.rows[0];
    if (!row || row.length < 2) return { checked: false, ok: null, detail: 'no columns' };
    // A condition in the stem may constrain the columns; only plain numbers are recomputed.
    const a = evaluateText(row[0]!);
    const b = evaluateText(row[1]!);
    if (!a || !b) return { checked: false, ok: null, detail: 'columns are not plain arithmetic' };
    const c = cmp(a, b);
    const expected: OptionId = c > 0 ? 'A' : c < 0 ? 'B' : 'C';
    const ok = expected === item.key.correct;
    return { checked: true, ok, detail: `A=${ratToString(a)}, Б=${ratToString(b)} → ${expected}${ok ? '' : `, key says ${item.key.correct}`}` };
  }
  if (!COMPUTE_STEM.test(q.stem)) return { checked: false, ok: null, detail: 'stem is not a computation' };
  const segments = [...q.stem.matchAll(/\$([^$]+)\$/g)].map((m) => m[1]!);
  if (segments.length !== 1 || /=/.test(segments[0]!)) return { checked: false, ok: null, detail: 'no single expression in the stem' };
  const value = evaluateText(`$${segments[0]}$`);
  if (!value) return { checked: false, ok: null, detail: 'expression is not plain arithmetic' };
  const matching = q.options.filter((o) => {
    const v = evaluateText(o.text);
    return v !== null && cmp(v, value) === 0;
  });
  if (matching.length === 0) return { checked: true, ok: false, detail: `value ${ratToString(value)} matches no option` };
  if (matching.length > 1) return { checked: true, ok: false, detail: `value ${ratToString(value)} matches several options: ${matching.map((o) => o.id).join(', ')}` };
  const ok = matching[0]!.id === item.key.correct;
  return { checked: true, ok, detail: `value ${ratToString(value)} = option ${matching[0]!.id}${ok ? '' : `, key says ${item.key.correct}`}` };
}
