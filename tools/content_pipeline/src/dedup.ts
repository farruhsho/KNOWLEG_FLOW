/**
 * Stage 5 — duplicates. Exact duplicates share the hash of the normalised
 * text; near duplicates have character-shingle Jaccard ≥ threshold. Items
 * are compared within the same language and, for passage items, within the
 * same passage (generic stems like "Какова основная мысль текста?" would
 * otherwise collide). Translation pairs are never compared with each other.
 */
import { BankItem, BankPassage, DedupRecord, REVIEW_RANK } from './schema';
import { jaccard, lshKeys, minhash, normalizeText, shingles } from './text';
import { sha256Hex } from './io';

export interface DedupDoc {
  id: string;
  group: string;
  text: string;
  translation_group_id: string | null;
  rank: number;
  created_at: string;
}

/** Text that identifies an item for dedup: stem + table cells (no headers) + option texts in sorted order. */
export function itemDedupText(item: BankItem): string {
  const q = item.question;
  const parts: string[] = [];
  if (q.type === 'quantitative_comparison') {
    // The stem is mostly the fixed instruction; the columns carry the content.
    parts.push(q.stem);
    if (q.table) for (const row of q.table.rows) parts.push(row.join(' | '));
  } else {
    parts.push(q.stem);
    if (q.table) for (const row of q.table.rows) parts.push(row.join(' | '));
    parts.push([...q.options.map((o) => o.text)].sort().join(' ; '));
  }
  return parts.join(' \n ');
}

export function docFromItem(item: BankItem): DedupDoc {
  const q = item.question;
  return {
    id: item.id,
    group: `${q.language}|${q.passage_id ?? '-'}`,
    text: normalizeText(itemDedupText(item)),
    translation_group_id: q.translation_group_id,
    rank: REVIEW_RANK[q.review.status],
    created_at: q.created_at,
  };
}

export function docFromPassage(p: BankPassage): DedupDoc {
  return {
    id: p.id,
    group: `passage|${p.passage.language}`,
    text: normalizeText(`${p.passage.title}\n${p.passage.text}`),
    translation_group_id: p.translation_group_id,
    rank: 0,
    created_at: '',
  };
}

export interface SimilarPair {
  a: string;
  b: string;
  similarity: number;
  exact: boolean;
}

export interface DedupCluster {
  cluster_id: string;
  kind: 'exact' | 'near';
  canonical: string;
  members: Array<{ id: string; similarity_to_canonical: number }>;
}

export interface DedupReport {
  threshold: number;
  documents: number;
  pairs: SimilarPair[];
  clusters: DedupCluster[];
  external_matches: Array<{ id: string; external_ref: string; similarity: number }>;
}

const EXACT_PAIRWISE_LIMIT = 1500;

/** All pairs within the same group whose similarity ≥ threshold. */
export function similarPairs(docs: DedupDoc[], threshold: number): SimilarPair[] {
  const byGroup = new Map<string, DedupDoc[]>();
  for (const d of docs) byGroup.set(d.group, [...(byGroup.get(d.group) ?? []), d]);
  const pairs: SimilarPair[] = [];
  for (const group of byGroup.values()) {
    const sh = new Map(group.map((d) => [d.id, shingles(d.text)]));
    const hash = new Map(group.map((d) => [d.id, sha256Hex(d.text)]));
    const check = (x: DedupDoc, y: DedupDoc): void => {
      if (x.translation_group_id && x.translation_group_id === y.translation_group_id) return;
      const exact = hash.get(x.id) === hash.get(y.id);
      const sim = exact ? 1 : jaccard(sh.get(x.id)!, sh.get(y.id)!);
      if (sim >= threshold) {
        const [a, b] = x.id < y.id ? [x.id, y.id] : [y.id, x.id];
        pairs.push({ a, b, similarity: Math.round(sim * 1000) / 1000, exact });
      }
    };
    if (group.length <= EXACT_PAIRWISE_LIMIT) {
      for (let i = 0; i < group.length; i++) for (let j = i + 1; j < group.length; j++) check(group[i]!, group[j]!);
      continue;
    }
    // Large groups: MinHash LSH candidates, then exact Jaccard on candidates.
    const buckets = new Map<string, string[]>();
    for (const d of group) for (const k of lshKeys(minhash(sh.get(d.id)!))) buckets.set(k, [...(buckets.get(k) ?? []), d.id]);
    const byId = new Map(group.map((d) => [d.id, d]));
    const seen = new Set<string>();
    for (const ids of buckets.values()) {
      for (let i = 0; i < ids.length; i++) {
        for (let j = i + 1; j < ids.length; j++) {
          const key = ids[i]! < ids[j]! ? `${ids[i]}|${ids[j]}` : `${ids[j]}|${ids[i]}`;
          if (seen.has(key)) continue;
          seen.add(key);
          check(byId.get(ids[i]!)!, byId.get(ids[j]!)!);
        }
      }
    }
  }
  return pairs.sort((x, y) => x.a.localeCompare(y.a) || x.b.localeCompare(y.b));
}

/** Union-find clusters; the canonical member is the most-reviewed, then oldest, then smallest id. */
export function clusterPairs(docs: DedupDoc[], pairs: SimilarPair[]): DedupCluster[] {
  const parent = new Map<string, string>();
  const find = (x: string): string => {
    let r = x;
    while (parent.get(r) !== r) r = parent.get(r)!;
    let c = x;
    while (parent.get(c) !== r) {
      const n = parent.get(c)!;
      parent.set(c, r);
      c = n;
    }
    return r;
  };
  for (const p of pairs) {
    if (!parent.has(p.a)) parent.set(p.a, p.a);
    if (!parent.has(p.b)) parent.set(p.b, p.b);
    const ra = find(p.a);
    const rb = find(p.b);
    if (ra !== rb) parent.set(ra < rb ? rb : ra, ra < rb ? ra : rb);
  }
  const groups = new Map<string, string[]>();
  for (const id of parent.keys()) groups.set(find(id), [...(groups.get(find(id)) ?? []), id]);
  const docById = new Map(docs.map((d) => [d.id, d]));
  const shById = new Map(docs.map((d) => [d.id, shingles(d.text)]));
  const clusters: DedupCluster[] = [];
  for (const members of groups.values()) {
    const sorted = [...members].sort((x, y) => {
      const dx = docById.get(x)!;
      const dy = docById.get(y)!;
      return dy.rank - dx.rank || dx.created_at.localeCompare(dy.created_at) || x.localeCompare(y);
    });
    const canonical = sorted[0]!;
    const exactAll = members.every((m) => docById.get(m)!.text === docById.get(canonical)!.text);
    clusters.push({
      cluster_id: `dup_${sha256Hex([...members].sort().join(',')).slice(0, 12)}`,
      kind: exactAll ? 'exact' : 'near',
      canonical,
      members: sorted.map((id) => ({
        id,
        similarity_to_canonical: Math.round(jaccard(shById.get(id)!, shById.get(canonical)!) * 1000) / 1000,
      })),
    });
  }
  return clusters.sort((a, b) => a.canonical.localeCompare(b.canonical));
}

/** Text fragments of existing content (legacy `questions` exports, other banks) to compare against. */
export interface ExternalDoc {
  ref: string;
  language: string | null;
  text: string;
}

function textOf(v: unknown, language: string | null): string {
  if (typeof v === 'string') return v;
  if (v && typeof v === 'object') {
    const m = v as Record<string, unknown>;
    if (language && typeof m[language] === 'string') return m[language] as string;
    if (typeof m.text === 'string') return m.text;
    if (m.text && typeof m.text === 'object') return textOf(m.text, language);
    return Object.values(m).filter((x) => typeof x === 'string').join(' ');
  }
  return '';
}

/**
 * Tolerant extractor: a BankFile, an array of question-like objects, or an
 * object with a `questions` array. Legacy QuestionModel documents keep
 * multilingual maps in `stem`/`options[].text`; each language becomes one doc.
 */
export function externalDocsFrom(json: unknown, source: string): ExternalDoc[] {
  const out: ExternalDoc[] = [];
  const pushQ = (q: Record<string, unknown>, idx: number): void => {
    const ref = `${source}#${typeof q.id === 'string' ? q.id : idx}`;
    const stem = q.stem;
    const options = Array.isArray(q.options) ? q.options : [];
    const langs = stem && typeof stem === 'object' ? Object.keys(stem as object) : [typeof q.language === 'string' ? q.language : null];
    for (const lang of langs) {
      const l = lang as string | null;
      const optTexts = options.map((o) => textOf(o, l)).sort().join(' ; ');
      const text = `${textOf(stem, l)} \n ${optTexts}`;
      if (text.trim()) out.push({ ref: langs.length > 1 ? `${ref}:${l}` : ref, language: l, text: normalizeText(text) });
    }
  };
  if (json && typeof json === 'object' && !Array.isArray(json)) {
    const o = json as Record<string, unknown>;
    if (Array.isArray(o.items)) {
      (o.items as Array<Record<string, unknown>>).forEach((it, i) => {
        const q = (it.question ?? it) as Record<string, unknown>;
        pushQ({ ...q, id: it.id ?? q.id }, i);
      });
      return out;
    }
    if (Array.isArray(o.questions)) {
      (o.questions as Array<Record<string, unknown>>).forEach(pushQ);
      return out;
    }
  }
  if (Array.isArray(json)) (json as Array<Record<string, unknown>>).forEach(pushQ);
  return out;
}

export function matchExternal(items: BankItem[], external: ExternalDoc[], threshold: number): DedupReport['external_matches'] {
  const matches: DedupReport['external_matches'] = [];
  const extSh = external.map((e) => ({ e, sh: shingles(e.text), h: sha256Hex(e.text) }));
  for (const item of items) {
    const doc = docFromItem(item);
    const sh = shingles(doc.text);
    const h = sha256Hex(doc.text);
    for (const x of extSh) {
      if (x.e.language && x.e.language !== item.question.language) continue;
      const sim = x.h === h ? 1 : jaccard(sh, x.sh);
      if (sim >= threshold) matches.push({ id: item.id, external_ref: x.e.ref, similarity: Math.round(sim * 1000) / 1000 });
    }
  }
  return matches;
}

export function runDedup(items: BankItem[], passages: BankPassage[], threshold: number, external: ExternalDoc[] = []): DedupReport {
  const docs = [...items.map(docFromItem), ...passages.map(docFromPassage)];
  const pairs = similarPairs(docs, threshold);
  return {
    threshold,
    documents: docs.length,
    pairs,
    clusters: clusterPairs(docs, pairs),
    external_matches: matchExternal(items, external, threshold),
  };
}

/** Dedup records to store on items (only for items that are in a cluster or match external content). */
export function dedupRecords(report: DedupReport, at: string): Map<string, DedupRecord> {
  const out = new Map<string, DedupRecord>();
  for (const c of report.clusters) {
    const maxSim = (id: string): number =>
      Math.max(0, ...report.pairs.filter((p) => p.a === id || p.b === id).map((p) => p.similarity));
    for (const m of c.members) {
      if (!m.id.startsWith('q_')) continue;
      out.set(m.id, { at, cluster_id: c.cluster_id, duplicate_of: m.id === c.canonical ? null : c.canonical, max_similarity: maxSim(m.id) });
    }
  }
  for (const m of report.external_matches) {
    const prev = out.get(m.id);
    if (!prev || prev.max_similarity < m.similarity) {
      out.set(m.id, { at, cluster_id: `ext:${m.external_ref}`, duplicate_of: prev?.duplicate_of ?? null, max_similarity: m.similarity });
    }
  }
  return out;
}

/** Items excluded from assembly by dedup: non-canonical cluster members and matches of existing external content. */
export function isDedupExcluded(item: BankItem): boolean {
  const d = item.pipeline.dedup;
  if (!d) return false;
  return d.duplicate_of !== null || d.cluster_id.startsWith('ext:');
}
