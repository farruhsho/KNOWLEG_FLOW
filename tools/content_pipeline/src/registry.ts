/**
 * Stage 10 — readiness registry. Counted only from the files under content/
 * (bank + variants); nothing is typed in by hand, so the numbers are honest
 * by construction. Target: 100 variants per blueprint × language.
 *
 * Two views: rows per blueprint × language (one exam_variants document is
 * one language), and directions per blueprint, where variant number N counts
 * only when every language of the blueprint has an approved (resp.
 * published) version N — the "100 variants × 10 directions" goal.
 */
import { Blueprint } from './blueprints';
import { BankItem, REVIEW_RANK, ReviewStatus, VariantFile } from './schema';

export const TARGET_VARIANTS = 100;

export interface RegistryRow {
  blueprint_id: string;
  language: string;
  target_variants: number;
  items_per_variant: number;
  variants: { drafted: number; ai_verified: number; approved: number; published: number; archived: number };
  items: Record<ReviewStatus, number> & { total: number };
}

export interface DirectionRow {
  blueprint_id: string;
  languages: string[];
  target_numbers: number;
  /** Variant numbers approved (resp. published) in every language of the blueprint. */
  approved_numbers: number;
  published_numbers: number;
}

export interface Registry {
  schema_version: 1;
  as_of: string | null;
  target_per_direction: number;
  rows: RegistryRow[];
  directions: DirectionRow[];
  totals: {
    target_variants: number;
    drafted: number;
    ai_verified: number;
    approved: number;
    published: number;
    items: number;
    approved_items: number;
    target_numbers: number;
    approved_numbers: number;
    published_numbers: number;
  };
}

/** Weakest review status among the variant's items (-1 when an item is missing or rejected). */
function minRankOf(v: VariantFile, byId: Map<string, BankItem>): number {
  let m = Infinity;
  for (const s of v.variant.sections) for (const id of s.question_ids) m = Math.min(m, REVIEW_RANK[byId.get(id)?.question.review.status ?? 'rejected']);
  return m === Infinity ? -1 : m;
}

export function computeRegistry(blueprints: Blueprint[], items: BankItem[], variants: VariantFile[], target = TARGET_VARIANTS): Registry {
  const byId = new Map(items.map((i) => [i.id, i]));
  let asOf: string | null = null;
  const bump = (t: string | null | undefined): void => {
    if (t && (!asOf || t > asOf)) asOf = t;
  };
  for (const it of items) bump(it.question.updated_at);
  for (const v of variants) {
    bump(String(v.assembly.assembled_at));
    bump(v.variant.published_at);
  }
  const live = (bpId: string, language: string): VariantFile[] =>
    variants.filter((v) => v.variant.blueprint_id === bpId && v.variant.language === language && v.variant.status !== 'archived');
  const rows: RegistryRow[] = [];
  for (const bp of blueprints) {
    for (const language of bp.languages) {
      const its = items.filter((i) => i.target.blueprint_id === bp.id && i.question.language === language);
      const count = (s: ReviewStatus): number => its.filter((i) => i.question.review.status === s).length;
      const all = variants.filter((v) => v.variant.blueprint_id === bp.id && v.variant.language === language);
      const vs = live(bp.id, language);
      rows.push({
        blueprint_id: bp.id,
        language,
        target_variants: target,
        items_per_variant: bp.sections.reduce((a, s) => a + s.question_count, 0),
        variants: {
          drafted: vs.length,
          ai_verified: vs.filter((v) => minRankOf(v, byId) >= REVIEW_RANK.ai_verified).length,
          approved: vs.filter((v) => minRankOf(v, byId) >= REVIEW_RANK.methodologist_approved).length,
          published: vs.filter((v) => v.variant.status === 'published').length,
          archived: all.length - vs.length,
        },
        items: {
          draft: count('draft'),
          ai_verified: count('ai_verified'),
          methodologist_approved: count('methodologist_approved'),
          rejected: count('rejected'),
          total: its.length,
        },
      });
    }
  }
  const directions: DirectionRow[] = blueprints.map((bp) => {
    const numbersWhere = (ok: (v: VariantFile) => boolean): number => {
      const perLang = bp.languages.map((l) => new Set(live(bp.id, l).filter(ok).map((v) => v.variant.number)));
      const [first, ...rest] = perLang;
      return first ? [...first].filter((n) => n <= target && rest.every((s) => s.has(n))).length : 0;
    };
    return {
      blueprint_id: bp.id,
      languages: [...bp.languages],
      target_numbers: target,
      approved_numbers: numbersWhere((v) => minRankOf(v, byId) >= REVIEW_RANK.methodologist_approved),
      published_numbers: numbersWhere((v) => v.variant.status === 'published'),
    };
  });
  const sum = (f: (r: RegistryRow) => number): number => rows.reduce((a, r) => a + f(r), 0);
  const dsum = (f: (r: DirectionRow) => number): number => directions.reduce((a, r) => a + f(r), 0);
  return {
    schema_version: 1,
    as_of: asOf,
    target_per_direction: target,
    rows,
    directions,
    totals: {
      target_variants: sum((r) => r.target_variants),
      drafted: sum((r) => r.variants.drafted),
      ai_verified: sum((r) => r.variants.ai_verified),
      approved: sum((r) => r.variants.approved),
      published: sum((r) => r.variants.published),
      items: sum((r) => r.items.total),
      approved_items: sum((r) => r.items.methodologist_approved),
      target_numbers: dsum((r) => r.target_numbers),
      approved_numbers: dsum((r) => r.approved_numbers),
      published_numbers: dsum((r) => r.published_numbers),
    },
  };
}

export function registryMarkdown(r: Registry): string {
  const lines = [
    '# Реестр готовности контента ОРТ',
    '',
    '> Файл генерируется командой `npm run cli -- registry` из `content/bank/**` и `content/variants/**`.',
    '> Не редактируйте вручную: числа считаются из файлов, «готовым» вариант считается только когда все его',
    '> задания `methodologist_approved` (ARCHITECTURE §7).',
    '',
    `Данные на: ${r.as_of ?? '—'}. Цель: ${r.target_per_direction} вариантов на направление × язык.`,
    '',
    '## По направлениям и языкам',
    '',
    '| Направление | Язык | Цель | Собрано (draft) | ai_verified | Одобрено | Опубликовано | Заданий в варианте | Задания: draft / ai_verified / approved / rejected |',
    '|---|---|---:|---:|---:|---:|---:|---:|---|',
  ];
  for (const row of r.rows) {
    const v = row.variants;
    const i = row.items;
    lines.push(
      `| \`${row.blueprint_id}\` | ${row.language} | ${row.target_variants} | ${v.drafted} | ${v.ai_verified} | ${v.approved} | ${v.published} | ${row.items_per_variant} | ${i.draft} / ${i.ai_verified} / ${i.methodologist_approved} / ${i.rejected} |`,
    );
  }
  const t = r.totals;
  lines.push(
    `| **Итого** | | ${t.target_variants} | ${t.drafted} | ${t.ai_verified} | ${t.approved} | ${t.published} | | ${t.items} заданий, из них одобрено ${t.approved_items} |`,
    '',
    '## По направлениям',
    '',
    'Номер варианта N засчитывается, только если вариант N одобрен (опубликован) на **всех** языках направления.',
    '',
    '| Направление | Языки | Цель (номеров) | Одобрено на всех языках | Опубликовано на всех языках |',
    '|---|---|---:|---:|---:|',
  );
  for (const d of r.directions) {
    lines.push(`| \`${d.blueprint_id}\` | ${d.languages.join(', ')} | ${d.target_numbers} | ${d.approved_numbers} | ${d.published_numbers} |`);
  }
  lines.push(`| **Итого** | | ${t.target_numbers} | ${t.approved_numbers} | ${t.published_numbers} |`, '');
  return lines.join('\n');
}
