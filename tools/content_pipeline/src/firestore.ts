/**
 * firebase-admin (v14, modular) adapter for the import stage. Loaded lazily
 * only by `import --commit`, so dry runs and tests need no credentials.
 * Credentials: Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS
 * pointing to a service-account JSON kept outside the repo, or
 * `gcloud auth application-default login`).
 */
import { isDeleteField, nestedArrayPaths, type CollectionName, type FirestorePort } from './importer';

export const DEFAULT_PROJECT_ID = 'knowleg-33f36';

export interface PipelineFirestore extends FirestorePort {
  /** Read-only export of up to `limit` documents of any collection (e.g. the legacy `questions`) for dedup --against. */
  exportCollection(collection: string, limit: number): Promise<Array<Record<string, unknown>>>;
}

/** Firestore values → JSON-safe values (Timestamps → ISO strings, references → paths). */
function plain(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(plain);
  if (v && typeof v === 'object') {
    const o = v as { toDate?: () => Date; path?: unknown; firestore?: unknown };
    if (typeof o.toDate === 'function') return o.toDate().toISOString();
    if (typeof o.path === 'string' && o.firestore) return o.path;
    return Object.fromEntries(Object.entries(v as Record<string, unknown>).map(([k, x]) => [k, plain(x)]));
  }
  return v;
}

/** Firestore sentinels the JSON-safe plan markers stand for. */
export interface FirestoreSentinels {
  timestamp(iso: string): unknown;
  serverTimestamp(): unknown;
  deleteField(): unknown;
}

/** Plan markers (`__timestamp`, `__server_timestamp`, `__delete_field`) → Firestore values. */
export function toFirestoreValue(v: unknown, s: FirestoreSentinels): unknown {
  if (Array.isArray(v)) return v.map((x) => toFirestoreValue(x, s));
  if (v && typeof v === 'object') {
    const o = v as Record<string, unknown>;
    if (typeof o.__timestamp === 'string') return s.timestamp(o.__timestamp);
    if (o.__server_timestamp === true) return s.serverTimestamp();
    if (isDeleteField(o)) return s.deleteField();
    return Object.fromEntries(Object.entries(o).map(([k, x]) => [k, toFirestoreValue(x, s)]));
  }
  return v;
}

/** Top-level fields of a write that hold a delete marker (FieldValue.delete() is valid only in merge writes). */
export function deletedFields(data: Record<string, unknown>): string[] {
  return Object.keys(data).filter((k) => isDeleteField(data[k]));
}

export async function openFirestore(projectId: string): Promise<PipelineFirestore> {
  const { initializeApp, applicationDefault, getApps } = await import('firebase-admin/app');
  const { getFirestore, Timestamp, FieldValue } = await import('firebase-admin/firestore');
  const app = getApps()[0] ?? initializeApp({ credential: applicationDefault(), projectId });
  const db = getFirestore(app);

  const sentinels: FirestoreSentinels = {
    timestamp: (iso) => Timestamp.fromDate(new Date(iso)),
    serverTimestamp: () => FieldValue.serverTimestamp(),
    deleteField: () => FieldValue.delete(),
  };

  return {
    async exportCollection(collection: string, limit: number) {
      // Read-only paging by document id; Timestamps become ISO strings.
      const out: Array<Record<string, unknown>> = [];
      let last: string | null = null;
      while (out.length < limit) {
        let q = db.collection(collection).orderBy('__name__').limit(Math.min(500, limit - out.length));
        if (last) q = q.startAfter(last);
        const snap = await q.get();
        if (snap.empty) break;
        for (const d of snap.docs) out.push({ id: d.id, ...(plain(d.data()) as Record<string, unknown>) });
        last = snap.docs[snap.docs.length - 1]!.id;
      }
      return out;
    },
    async getExisting(collection: CollectionName, ids: string[]) {
      const out = new Map<string, Record<string, unknown>>();
      for (let i = 0; i < ids.length; i += 300) {
        const refs = ids.slice(i, i + 300).map((id) => db.collection(collection).doc(id));
        if (!refs.length) continue;
        const snaps = await db.getAll(...refs);
        for (const s of snaps) if (s.exists) out.set(s.id, s.data() ?? {});
      }
      return out;
    },
    async commitBatch(writes) {
      if (writes.length > 400) throw new Error('batch larger than 400 writes');
      // Firestore rejects an array inside an array only at commit (INVALID_ARGUMENT), after earlier batches went through: fail before.
      const bad = writes.flatMap((w) => nestedArrayPaths(w.data).map((p) => `${w.collection}/${w.id} ${p}`));
      if (bad.length) throw new Error(`Firestore cannot store an array inside an array: ${bad.slice(0, 5).join('; ')}`);
      const deletes = writes.filter((w) => !w.merge && deletedFields(w.data).length).map((w) => `${w.collection}/${w.id}`);
      if (deletes.length) throw new Error(`a field delete needs a merge write: ${deletes.slice(0, 5).join('; ')}`);
      const batch = db.batch();
      for (const w of writes) batch.set(db.collection(w.collection).doc(w.id), toFirestoreValue(w.data, sentinels) as Record<string, unknown>, { merge: w.merge });
      await batch.commit();
    },
  };
}
