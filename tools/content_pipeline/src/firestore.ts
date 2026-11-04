/**
 * firebase-admin (v14, modular) adapter for the import stage. Loaded lazily
 * only by `import --commit`, so dry runs and tests need no credentials.
 * Credentials: Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS
 * pointing to a service-account JSON kept outside the repo, or
 * `gcloud auth application-default login`).
 */
import type { CollectionName, FirestorePort } from './importer';

export const DEFAULT_PROJECT_ID = 'knowleg-33f36';

export async function openFirestore(projectId: string): Promise<FirestorePort> {
  const { initializeApp, applicationDefault, getApps } = await import('firebase-admin/app');
  const { getFirestore, Timestamp, FieldValue } = await import('firebase-admin/firestore');
  const app = getApps()[0] ?? initializeApp({ credential: applicationDefault(), projectId });
  const db = getFirestore(app);

  const convert = (v: unknown): unknown => {
    if (Array.isArray(v)) return v.map(convert);
    if (v && typeof v === 'object') {
      const o = v as Record<string, unknown>;
      if (typeof o.__timestamp === 'string') return Timestamp.fromDate(new Date(o.__timestamp));
      if (o.__server_timestamp === true) return FieldValue.serverTimestamp();
      return Object.fromEntries(Object.entries(o).map(([k, x]) => [k, convert(x)]));
    }
    return v;
  };

  return {
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
      const batch = db.batch();
      for (const w of writes) batch.set(db.collection(w.collection).doc(w.id), convert(w.data) as Record<string, unknown>, { merge: w.merge });
      await batch.commit();
    },
  };
}
