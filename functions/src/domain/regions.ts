/**
 * Kyrgyz regions (assets/data/kg_regions.json, bundled into the functions
 * build) and the mapping from a user profile to the region id used by the
 * regional league `region_{regionId}_weekly_*` (ARCHITECTURE §9.3) and by
 * adminSendNotification's `region` audience.
 *
 * The app stores `users/{uid}.region` as a map `{oblast, district,
 * settlement}` whose `oblast` is the canonical Russian name; the board key is
 * the stable ASCII `id` of that oblast (`chuy`, `bishkek`, ...). Ids and
 * oblast names are both accepted, as a map field or a plain string, plus the
 * legacy `region_id` field.
 */
import { isRecord } from './types';

export interface RegionIndex {
  /** Known region ids. */
  ids: ReadonlySet<string>;
  /** Canonical oblast name (and localized titles) -> id. */
  byName: ReadonlyMap<string, string>;
}

const ID_RE = /^[a-z][a-z0-9_]{0,39}$/;

function norm(s: string): string {
  return s.trim().toLowerCase();
}

/** Builds the index from the parsed kg_regions.json (`{regions: [{id, oblast, title}]}`). */
export function buildRegionIndex(json: unknown): RegionIndex {
  const ids = new Set<string>();
  const byName = new Map<string, string>();
  const list = isRecord(json) && Array.isArray(json['regions']) ? json['regions'] : [];
  for (const r of list) {
    if (!isRecord(r) || typeof r['id'] !== 'string' || !ID_RE.test(r['id'])) continue;
    const id = r['id'];
    ids.add(id);
    if (typeof r['oblast'] === 'string') byName.set(norm(r['oblast']), id);
    if (isRecord(r['title'])) {
      for (const t of Object.values(r['title'])) if (typeof t === 'string' && t.trim()) byName.set(norm(t), id);
    }
  }
  return { ids, byName };
}

/** Region id for a raw value (id or name), or null when unknown. */
export function resolveRegionId(value: unknown, index: RegionIndex): string | null {
  if (typeof value !== 'string' || value.trim() === '' || value.length > 100) return null;
  if (index.ids.has(value.trim())) return value.trim();
  return index.byName.get(norm(value)) ?? null;
}

/**
 * Region id of a users/{uid} profile: `region.oblast` / `region.id` (map),
 * `region` (string), then legacy `region_id`. Null when unset or unknown.
 */
export function regionIdFromProfile(profile: unknown, index: RegionIndex): string | null {
  if (!isRecord(profile)) return null;
  const region = profile['region'];
  if (isRecord(region)) {
    const fromMap = resolveRegionId(region['id'], index) ?? resolveRegionId(region['oblast'], index);
    if (fromMap) return fromMap;
  } else {
    const fromString = resolveRegionId(region, index);
    if (fromString) return fromString;
  }
  return resolveRegionId(profile['region_id'], index);
}
