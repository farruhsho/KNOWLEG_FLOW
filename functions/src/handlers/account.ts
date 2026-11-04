/**
 * accountDelete {} -> {ok: true}  (Google Play User Data policy, ACC-01)
 *
 * Requires a recent sign-in: the ID token's auth_time must be at most 5
 * minutes old, else HttpsError failed-precondition with reason
 * REQUIRES_RECENT_LOGIN (the client re-authenticates and retries).
 *
 * Deletes the Auth user FIRST, then every per-user document (new and legacy
 * collections, including sub-collections) and the user's Storage files.
 * Deleting Auth first means the still-valid ID token can no longer be used
 * against examStart/billing/aiTutor/recordActivity (they check that the Auth
 * user exists), so wiping entitlements cannot be abused to re-claim the free
 * exam. A retry after a partial failure (Auth user already gone) skips the
 * recent-login check and only finishes the data cleanup of the caller's uid.
 * Purchases and legacy payments are kept for finance/fraud review but
 * anonymized: uid -> 'deleted:' + sha256(uid).
 */
import '../config';
import { getAuth } from 'firebase-admin/auth';
import { FieldPath, type DocumentReference, type Query } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';
import { assertRecentLogin, dailyQuestIdRange } from '../domain/access';
import { sha256Hex } from '../domain/hash';
import { anonymizedUid } from '../domain/purchase';
import { callableOptions, db, FieldValue, findAuthUser, requireAuth, wrap } from './common';
import { removeUserFromGroups } from './groups';

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
export const UID_TREES = ['entitlements', 'user_mistakes', 'ai_usage', 'xp_events', 'friends', 'referrals'] as const;

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
  // Read before users/{uid} is deleted: the referrer's item about this user goes too.
  const referredBy = (await db().doc(`users/${uid}`).get()).get('referred_by');
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
  const questRange = dailyQuestIdRange(uid);
  counts['daily_quests_by_id'] = await deleteQueryTrees(
    db()
      .collection('daily_quests')
      .where(FieldPath.documentId(), '>=', questRange.start)
      .where(FieldPath.documentId(), '<', questRange.end),
  );
  counts['leaderboard_entries'] = await deleteQueryTrees(db().collectionGroup('entries').where('uid', '==', uid));

  // Phase 3 (ARCHITECTURE §9): codes, referral item, promo attempt counters, groups.
  counts['referral_codes'] = await deleteQueryTrees(db().collection('referral_codes').where('uid', '==', uid));
  if (typeof referredBy === 'string' && referredBy && !referredBy.includes('/')) {
    await db().doc(`referrals/${referredBy}/items/${uid}`).delete();
  }
  const attemptRange = dailyQuestIdRange(uid); // same `${uid}_${day}` id scheme
  counts['promo_attempts'] = await deleteQueryTrees(
    db()
      .collection('promo_attempts')
      .where(FieldPath.documentId(), '>=', attemptRange.start)
      .where(FieldPath.documentId(), '<', attemptRange.end),
  );
  counts['groups'] = await removeUserFromGroups(uid);

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
    const authUser = await findAuthUser(uid);
    if (authUser) {
      assertRecentLogin(req.auth?.token?.auth_time, Date.now());
      try {
        await getAuth().deleteUser(uid);
      } catch (e) {
        if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
      }
    } else {
      logger.warn('accountDelete retry: auth user already deleted, finishing data cleanup', { uid_hash: sha256Hex(uid) });
    }
    let counts: Record<string, number>;
    try {
      counts = await deleteUserData(uid);
    } catch (e) {
      // The Auth user is gone; the client can retry with its still-valid token
      // (the retry skips the recent-login check), and ops can re-run cleanup.
      logger.error('accountDelete: data cleanup failed after auth deletion', { uid_hash: sha256Hex(uid), error: String(e) });
      throw e;
    }
    await db().collection('admin_logs').add({
      actor_uid: 'self',
      actor_role: 'user',
      action: 'account_delete',
      target: { uid_hash: sha256Hex(uid) },
      details: counts,
      at: FieldValue.serverTimestamp(),
    });
    logger.info('account deleted', { uid_hash: sha256Hex(uid), counts });
    return { ok: true };
  }),
);
