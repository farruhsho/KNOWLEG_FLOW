/**
 * Moderation enforcement (decision D5). Moderators ban by writing
 * users/{uid}.is_banned (+ ban_reason, banned_at, banned_by) directly, which
 * firestore.rules allows. The server side of a ban:
 * - examStart, aiTutor, recordActivity and adminAiDraftQuestions reject the
 *   user with permission-denied / reason USER_BANNED (handlers/common.ts);
 * - addLeaderboardXp never writes entries for banned users;
 * - this trigger removes the user's existing leaderboard entries as soon as
 *   the ban is set, so they disappear from every board.
 */
import '../config';
import { logger } from 'firebase-functions';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { isBannedProfile } from '../domain/access';
import { db } from './common';

/** Deletes every leaderboards/{board}/entries/{uid} document of `uid`. */
export async function purgeLeaderboardEntries(uid: string): Promise<number> {
  let n = 0;
  for (;;) {
    const snap = await db().collectionGroup('entries').where('uid', '==', uid).limit(300).get();
    if (snap.empty) return n;
    // Only leaderboard entries (other collections named `entries` are not touched).
    const docs = snap.docs.filter((d) => d.ref.parent.parent?.parent.id === 'leaderboards');
    if (docs.length === 0) return n;
    const batch = db().batch();
    for (const d of docs) batch.delete(d.ref);
    await batch.commit();
    n += docs.length;
    if (snap.size < 300) return n;
  }
}

export const onUserBanChanged = onDocumentUpdated({ document: 'users/{uid}', retry: false }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!isBannedProfile(after) || isBannedProfile(before)) return;
  const uid = event.params.uid;
  try {
    const removed = await purgeLeaderboardEntries(uid);
    logger.info('banned user removed from leaderboards', { uid, removed });
  } catch (e) {
    logger.error('leaderboard purge after ban failed', { uid, error: String(e) });
  }
});
