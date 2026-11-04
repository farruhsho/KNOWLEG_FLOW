/**
 * sendStudyReminders: daily 18:00 Asia/Bishkek (decision D12). Messages users
 * with users/{uid}.daily_reminder_enabled == true and FCM tokens who have not
 * earned XP today (user_stats.last_active_day != today), in their
 * preferred_language (ru/ky). Dead tokens are pruned from fcm_tokens. Never
 * sends between 22:00 and 08:00 Bishkek time (late or retried runs).
 */
import '../config';
import { FieldPath, type QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { isInvalidTokenError, isQuietHours, reminderTarget, reminderText, type ReminderTarget } from '../domain/reminders';
import { db, FieldValue, mapLimit } from './common';
import { statsRef } from './gamification';

const PAGE_SIZE = 300;
const MAX_PAGES = 100;

interface SendOutcome {
  sent: number;
  failed: number;
  pruned: number;
}

async function sendTo(uid: string, target: ReminderTarget): Promise<SendOutcome> {
  const text = reminderText(target.language);
  const res = await getMessaging().sendEachForMulticast({
    tokens: target.tokens,
    notification: { title: text.title, body: text.body },
    data: { type: 'study_reminder' },
    android: { priority: 'normal', collapseKey: 'study_reminder' },
    apns: { headers: { 'apns-collapse-id': 'study_reminder' } },
  });
  const dead: string[] = [];
  res.responses.forEach((r, i) => {
    if (!r.success && isInvalidTokenError(r.error?.code)) dead.push(target.tokens[i]!);
  });
  if (dead.length > 0) {
    try {
      await db().doc(`users/${uid}`).update({ fcm_tokens: FieldValue.arrayRemove(...dead) });
    } catch (e) {
      logger.warn('reminder token prune failed', { uid, error: String(e) });
    }
  }
  return { sent: res.successCount, failed: res.failureCount, pruned: dead.length };
}

export const sendStudyReminders = onSchedule(
  { schedule: '0 18 * * *', timeZone: 'Asia/Bishkek', timeoutSeconds: 540, memory: '512MiB', retryCount: 0 },
  async () => {
    const startedMs = Date.now();
    if (isQuietHours(startedMs)) {
      logger.info('sendStudyReminders skipped: quiet hours');
      return;
    }
    const totals = { users: 0, targeted: 0, sent: 0, failed: 0, pruned: 0, errors: 0 };
    let last: QueryDocumentSnapshot | undefined;
    for (let page = 0; page < MAX_PAGES; page++) {
      // A long run must not spill into the quiet hours.
      if (isQuietHours(Date.now())) {
        logger.warn('sendStudyReminders stopped: reached quiet hours');
        break;
      }
      let q = db().collection('users').where('daily_reminder_enabled', '==', true).orderBy(FieldPath.documentId()).limit(PAGE_SIZE);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;
      last = snap.docs[snap.docs.length - 1];
      totals.users += snap.size;

      const statsSnaps = await db().getAll(...snap.docs.map((d) => statsRef(d.id)));
      const nowMs = Date.now();
      const targets = snap.docs
        .map((d, i) => ({ uid: d.id, target: reminderTarget(d.data(), statsSnaps[i]?.data(), nowMs) }))
        .filter((t): t is { uid: string; target: ReminderTarget } => t.target !== null);
      totals.targeted += targets.length;

      const outcomes = await mapLimit(targets, 10, async (t) => {
        try {
          return await sendTo(t.uid, t.target);
        } catch (e) {
          logger.warn('reminder send failed', { uid: t.uid, error: String(e) });
          totals.errors++;
          return { sent: 0, failed: 0, pruned: 0 };
        }
      });
      for (const o of outcomes) {
        totals.sent += o.sent;
        totals.failed += o.failed;
        totals.pruned += o.pruned;
      }
      if (snap.size < PAGE_SIZE) break;
    }
    logger.info('sendStudyReminders done', totals);
  },
);
