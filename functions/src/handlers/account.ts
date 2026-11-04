/**
 * accountDelete {} -> {ok: true}  (Google Play User Data policy, ACC-01)
 *
 * Deletes every per-user document (new and legacy collections, including
 * sub-collections), the user's Storage files and finally the Auth user.
 * Purchases and legacy payments are kept for finance/fraud review but
 * anonymized: uid -> 'deleted:' + sha256(uid).
 */
import '../config';
import { getAuth } from 'firebase-admin/auth';
import { FieldPath, type DocumentReference, type Query } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';
import { sha256Hex } from '../domain/hash';
import { anonymizedUid } from '../domain/purchase';
import { callableOptions, db, FieldValue, requireAuth, wrap } from './common';

/** Single documents keyed by uid. */
export const UID_DOCS = [
  'users',
  'user_stats',
  'user_progress',
  'user_gamification',
  'gamification',
  'user_achievements',
  'analytics',
  'rankings',
] as const;

/** Trees (document + all sub-collections) keyed by uid. */
export const UID_TREES = ['entitlements', 'user_mistakes', 'ai_usage', 'xp_events'] as const;

/** Legacy collections where the owner is a field. */
export const OWNED_BY_FIELD: ReadonlyArray<readonly [collection: string, field: string]> = [
  ['exam_attempts', 'uid'],
  ['user_attempts', 'uid'],
  ['ort_attempts', 'user_id'],
  ['flashcard_progress', 'uid'],
  ['user_mission_progress', 'user_id'],
  ['daily_quests', 'userId'],
  ['forum_posts', 'author_uid'],
];

async function deleteQueryTrees(q: Query): Promise<number> {
  let n = 0;
  for (;;) {
    const snap = await q.limit(200).get();
    if (snap.empty) return n;
    for (const d of snap.docs) {
      await db().recursiveDelete(d.ref);
      n++;
    }
    if (snap.size < 200) return n;
  }
}

async function anonymize(collection: string, field: string, uid: string): Promise<number> {
  const replacement = anonymizedUid(uid);
  let n = 0;
  for (;;) {
    const snap = await db().collection(collection).where(field, '==', uid).limit(400).get();
    if (snap.empty) return n;
    const batch = db().batch();
    for (const d of snap.docs) {
      batch.update(d.ref, { [field]: replacement, anonymized_at: FieldValue.serverTimestamp() });
      n++;
    }
    await batch.commit();
    if (snap.size < 400) return n;
  }
}

export async function deleteUserData(uid: string): Promise<Record<string, number>> {
  const counts: Record<string, number> = {};
  const refs: DocumentReference[] = UID_DOCS.map((c) => db().collection(c).doc(uid));
  const batch = db().batch();
  for (const r of refs) batch.delete(r);
  await batch.commit();
  counts['docs'] = refs.length;

  for (const c of UID_TREES) await db().recursiveDelete(db().collection(c).doc(uid));
  counts['trees'] = UID_TREES.length;

  for (const [collection, field] of OWNED_BY_FIELD) {
    counts[collection] = await deleteQueryTrees(db().collection(collection).where(field, '==', uid));
  }
  // daily_quests ids are `${uid}_${date}` even when the userId field is missing.
  counts['daily_quests_by_id'] = await deleteQueryTrees(
    db()
      .collection('daily_quests')
      .where(FieldPath.documentId(), '>=', `${uid}_`)
      .where(FieldPath.documentId(), '<', `${uid}_`),
  );
  counts['leaderboard_entries'] = await deleteQueryTrees(db().collectionGroup('entries').where('uid', '==', uid));

  counts['purchases_anonymized'] = await anonymize('purchases', 'uid', uid);
  counts['payments_anonymized'] = await anonymize('payments', 'uid', uid);

  try {
    const bucket = getStorage().bucket();
    await bucket.deleteFiles({ prefix: `user_avatars/${uid}/` });
    await bucket.deleteFiles({ prefix: `temp_uploads/${uid}/` });
  } catch (e) {
    logger.warn('storage cleanup failed', { error: String(e) });
  }
  return counts;
}

export const accountDelete = onCall(
  callableOptions({ timeoutSeconds: 300, memory: '512MiB' }),
  wrap('accountDelete', async (req) => {
    const uid = requireAuth(req);
    const counts = await deleteUserData(uid);
    await db().collection('admin_logs').add({
      actor_uid: 'self',
      actor_role: 'user',
      action: 'account_delete',
      target: { uid_hash: sha256Hex(uid) },
      details: counts,
      at: FieldValue.serverTimestamp(),
    });
    try {
      await getAuth().deleteUser(uid);
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (code !== 'auth/user-not-found') throw e;
    }
    logger.info('account deleted', { uid_hash: sha256Hex(uid), counts });
    return { ok: true };
  }),
);
