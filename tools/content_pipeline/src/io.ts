import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readdirSync, readFileSync, renameSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';

/** Repository layout used by every stage. Tests point `root` at a temp dir. */
export interface Paths {
  root: string;
  blueprints: string;
  content: string;
  curriculum: string;
  matrix: string;
  bank: string;
  variants: string;
  reports: string;
  schema: string;
  registryJson: string;
  registryMd: string;
}

export function pathsFor(root: string): Paths {
  const content = join(root, 'content');
  return {
    root,
    blueprints: join(root, 'assets', 'data', 'exam_blueprints.json'),
    content,
    curriculum: join(content, 'curriculum', 'topics.json'),
    matrix: join(content, 'matrix'),
    bank: join(content, 'bank'),
    variants: join(content, 'variants'),
    reports: join(content, 'reports'),
    schema: join(content, 'schema'),
    registryJson: join(content, 'registry.json'),
    registryMd: join(content, 'REGISTRY.md'),
  };
}

/** Walks up from `start` until it finds the repo root (the folder with assets/data/exam_blueprints.json). */
export function findRepoRoot(start: string = process.cwd()): string {
  let dir = resolve(start);
  for (;;) {
    if (existsSync(join(dir, 'assets', 'data', 'exam_blueprints.json'))) return dir;
    const parent = dirname(dir);
    if (parent === dir) {
      throw new Error(`Repo root not found from ${start}: no assets/data/exam_blueprints.json above it. Pass --root.`);
    }
    dir = parent;
  }
}

export function readJson<T = unknown>(path: string): T {
  const raw = readFileSync(path, 'utf8');
  try {
    return JSON.parse(raw.charCodeAt(0) === 0xfeff ? raw.slice(1) : raw) as T;
  } catch (e) {
    throw new Error(`Invalid JSON in ${path}: ${(e as Error).message}`);
  }
}

/** Writes pretty JSON atomically (temp file + rename) so an interrupted batch never leaves a torn file. */
export function writeJsonAtomic(path: string, data: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = `${path}.${process.pid}.tmp`;
  writeFileSync(tmp, JSON.stringify(data, null, 2) + '\n', 'utf8');
  renameSync(tmp, path);
}

export function writeText(path: string, text: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text, 'utf8');
}

/** Recursively lists files under `dir` whose name matches `pattern`, sorted for determinism. */
export function listFiles(dir: string, pattern: RegExp): string[] {
  if (!existsSync(dir)) return [];
  const out: string[] = [];
  const walk = (d: string): void => {
    for (const name of readdirSync(d).sort()) {
      const p = join(d, name);
      if (statSync(p).isDirectory()) walk(p);
      else if (pattern.test(name)) out.push(p);
    }
  };
  walk(dir);
  return out;
}

/** JSON with recursively sorted keys: the canonical form hashed for content ids. */
export function canonicalJson(value: unknown): string {
  return JSON.stringify(sortKeys(value));
}

function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value !== null && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const k of Object.keys(value as Record<string, unknown>).sort()) {
      const v = (value as Record<string, unknown>)[k];
      if (v !== undefined) out[k] = sortKeys(v);
    }
    return out;
  }
  return value;
}

export function sha256Hex(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

/** Small deterministic PRNG (mulberry32) seeded from a string. */
export function seededRandom(seed: string): () => number {
  let a = parseInt(sha256Hex(seed).slice(0, 8), 16) >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Stable per-item sort key for seeded shuffles. */
export function seededKey(seed: string, id: string): string {
  return sha256Hex(`${seed}|${id}`);
}

export function nowIso(): string {
  return new Date().toISOString();
}
