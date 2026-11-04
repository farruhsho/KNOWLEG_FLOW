/**
 * Text normalisation for hashing/similarity. Cyrillic is preserved —
 * including Kyrgyz ң ө ү, which are NOT folded into н о у ("төрт" four ≠
 * "торт" cake). Look-alike code points that people type instead of the
 * Kyrgyz letters (ӊ, ӧ, ӱ, Latin ö/ü, ɵ) are mapped onto the canonical ones,
 * and Latin homoglyphs inside Cyrillic words (a, e, o, p, c, x, y, k) are
 * mapped to their Cyrillic twins so "мaтематика" with a Latin a still matches.
 */

const KY_LOOKALIKES: Record<string, string> = {
  'ӊ': 'ң', 'ӈ': 'ң',
  'ӧ': 'ө', 'ö': 'ө', 'ɵ': 'ө',
  'ӱ': 'ү', 'ü': 'ү',
  'ё': 'е',
};

const LATIN_TO_CYRILLIC: Record<string, string> = { a: 'а', e: 'е', o: 'о', p: 'р', c: 'с', x: 'х', y: 'у', k: 'к' };

const CYRILLIC = /\p{Script=Cyrillic}/u;

/** Normalised text: NFKC, lower case, look-alikes unified, LaTeX markup and decoration removed, maths operators kept. */
export function normalizeText(input: string): string {
  let s = input.normalize('NFKC').toLowerCase();
  s = s
    .replace(/\{,\}/g, ',')
    .replace(/\\(cdot|times)/g, '*')
    .replace(/\\(div)/g, '/')
    .replace(/\\(leq?|leqslant)/g, '≤')
    .replace(/\\(geq?|geqslant)/g, '≥')
    .replace(/\\(neq|ne)\b/g, '≠')
    .replace(/\\[a-z]+/g, (m) => ` ${m.slice(1)} `)
    .replace(/[$\\{}]/g, ' ')
    .replace(/[−–—]/g, '-')
    .replace(/[×·]/g, '*')
    .replace(/÷/g, '/');
  s = [...s].map((ch) => KY_LOOKALIKES[ch] ?? ch).join('');
  // Homoglyph repair only inside tokens that already contain Cyrillic letters.
  s = s.replace(/[\p{L}]+/gu, (tok) => (CYRILLIC.test(tok) ? [...tok].map((ch) => LATIN_TO_CYRILLIC[ch] ?? ch).join('') : tok));
  s = s.replace(/[^\p{L}\p{N}\s+\-*/=<>≤≥≠^%().,]/gu, ' ');
  return s.replace(/\s+/g, ' ').trim();
}

/** Words for timing: letters/digits runs, LaTeX commands stripped. */
export function wordCount(input: string): number {
  const s = input.replace(/\\[a-zA-Z]+/g, ' ').replace(/[$\\{}^_]/g, ' ');
  const m = s.match(/[\p{L}\p{N}]+/gu);
  return m ? m.length : 0;
}

/** Character k-shingles over the normalised text (spaces kept as separators). */
export function shingles(normalized: string, k = 5): Set<string> {
  const out = new Set<string>();
  if (normalized.length === 0) return out;
  if (normalized.length <= k) {
    out.add(normalized);
    return out;
  }
  for (let i = 0; i + k <= normalized.length; i++) out.add(normalized.slice(i, i + k));
  return out;
}

export function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 && b.size === 0) return 1;
  let inter = 0;
  const [small, large] = a.size <= b.size ? [a, b] : [b, a];
  for (const x of small) if (large.has(x)) inter++;
  return inter / (a.size + b.size - inter);
}

function fnv1a(s: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

const MINHASH_K = 64;
const COEFFS: Array<[number, number]> = Array.from({ length: MINHASH_K }, (_, i) => [
  (fnv1a(`a${i}`) | 1) >>> 0,
  fnv1a(`b${i}`) >>> 0,
]);

/** 64-value MinHash signature of a shingle set. */
export function minhash(sh: Set<string>): Uint32Array {
  const sig = new Uint32Array(MINHASH_K).fill(0xffffffff);
  for (const s of sh) {
    const x = fnv1a(s);
    for (let i = 0; i < MINHASH_K; i++) {
      const [a, b] = COEFFS[i]!;
      const v = (Math.imul(a, x) + b) >>> 0;
      if (v < sig[i]!) sig[i] = v;
    }
  }
  return sig;
}

/** LSH band keys (16 bands × 4 rows): documents sharing any key are candidate pairs. */
export function lshKeys(sig: Uint32Array, bands = 16): string[] {
  const rows = Math.floor(sig.length / bands);
  const keys: string[] = [];
  for (let b = 0; b < bands; b++) keys.push(`${b}:${Array.from(sig.slice(b * rows, (b + 1) * rows)).join('.')}`);
  return keys;
}
