/**
 * adminSendNotification (ARCHITECTURE §9.4)
 *   {title: {ru, ky}, body: {ru, ky}, audience: {kind: all|language|region|group, value?}, dryRun?}
 *   -> {recipients, sent, failed, notificationId, tokens, pruned, dryRun}
 *
 * Permission `send_notifications` (super_admin, content_manager). Recipients
 * are users with FCM tokens (`users/{uid}.fcm_tokens`) who are not banned;
 * the text language follows `preferred_language`. Tokens go out in
 * multicast batches of ≤ 500 (getMessaging().sendEachForMulticast); dead
 * tokens are removed from fcm_tokens. At most 3 real broadcasts per Bishkek
 * day (RATE_LIMITED); dry runs only count recipients, are not capped and
 * leave no history (notificationId null). History: notifications/{id}
 * (readable by admin roles).
 *
 * Audience selection pages through `users` ordered by document id and
 * filters in code (domain/notifications.ts recipientFor): no composite
 * index is needed, and region / language matching is the exact same logic
 * as the leagues and reminders (map or string region, `ky*` languages). For
 * `group`, only the group's members are read. Only RECIPIENT_FIELDS of each
 * profile are fetched (select / fieldMask, ARCHITECTURE §9.7).
 */
import '../config';
import { FieldPath, type DocumentSnapshot, type QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onCall } from 'firebase-functions/v2/https';
import { canBroadcast, parseBroadcast, recipientFor, tokenBatches, type Audience, type BroadcastInput, type Recipient } from '../domain/notifications';
import { DomainError, Reasons } from '../domain/reasons';
import { isInvalidTokenError } from '../domain/reminders';
import { bishkekDayKey } from '../domain/time';
import { int } from '../domain/types';
import { adminCallableOptions, chunk, db, FieldValue, mapLimit, payload, requirePermission, wrap, writeAdminLog } from './common';
import { regionIndex } from './gamification';

const PAGE_SIZE = 500;
const MAX_PAGES = 200; // 100k users per broadcast
/** The only users/{uid} fields recipientFor reads (§9.7: no full profile reads). */
export const RECIPIENT_FIELDS = ['is_banned', 'fcm_tokens', 'preferred_language', 'region', 'region_id', 'group_ids'] as const;

async function collectRecipients(audience: Audience): Promise<Recipient[]> {
  const regions = regionIndex();
  const out: Recipient[] = [];
  const consider = (snaps: DocumentSnapshot[]) => {
    for (const s of snaps) {
      const r = s.exists ? recipientFor(s.id, s.data(), audience, regions) : null;
      if (r) out.push(r);
    }
  };
  if (audience.kind === 'group') {
    const gid = audience.value!;
    const group = await db().doc(`groups/${gid}`).get();
    if (!group.exists) throw new DomainError(Reasons.VALIDATION_FAILED, 'group not found', { field: 'audience' });
    const members = await db().collection(`groups/${gid}/members`).select().get();
    for (const part of chunk(members.docs, 300)) {
      consider(await db().getAll(...part.map((m) => db().doc(`users/${m.id}`)), { fieldMask: [...RECIPIENT_FIELDS] }));
    }
    return out;
  }
  let last: QueryDocumentSnapshot | undefined;
  for (let page = 0; page < MAX_PAGES; page++) {
    let q = db()
      .collection('users')
      .select(...RECIPIENT_FIELDS)
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    consider(snap.docs);
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE_SIZE) break;
  }
  return out;
}

interface SendTotals {
  sent: number;
  failed: number;
  pruned: number;
}

async function send(input: BroadcastInput, recipients: Recipient[], notificationId: string): Promise<SendTotals> {
  const totals: SendTotals = { sent: 0, failed: 0, pruned: 0 };
  const dead = new Map<string, string[]>();
  for (const batch of tokenBatches(recipients)) {
    try {
      const res = await getMessaging().sendEachForMulticast({
        tokens: batch.tokens,
        notification: { title: input.title[batch.language], body: input.body[batch.language] },
        data: { type: 'broadcast', notificationId },
        android: { priority: 'normal' },
      });
      totals.sent += res.successCount;
      totals.failed += res.failureCount;
      res.responses.forEach((r, i) => {
        if (!r.success && isInvalidTokenError(r.error?.code)) {
          const owner = batch.owners[i]!;
          dead.set(owner, [...(dead.get(owner) ?? []), batch.tokens[i]!]);
        }
      });
    } catch (e) {
      logger.warn('broadcast batch failed', { notificationId, size: batch.tokens.length, error: String(e) });
      totals.failed += batch.tokens.length;
    }
  }
  await mapLimit([...dead.entries()], 10, async ([uid, tokens]) => {
    try {
      await db().doc(`users/${uid}`).update({ fcm_tokens: FieldValue.arrayRemove(...tokens) });
      totals.pruned += tokens.length;
    } catch (e) {
      logger.warn('broadcast token prune failed', { uid, error: String(e) });
    }
  });
  return totals;
}

export const adminSendNotification = onCall(
  adminCallableOptions({ timeoutSeconds: 540, memory: '512MiB' }),
  wrap('adminSendNotification', async (req) => {
    const actor = await requirePermission(req, 'send_notifications');
    const input = parseBroadcast(payload(req), regionIndex());
    const recipients = await collectRecipients(input.audience);
    const tokenCount = recipients.reduce((n, r) => n + r.tokens.length, 0);
    if (input.dryRun) {
      return { recipients: recipients.length, tokens: tokenCount, sent: 0, failed: 0, pruned: 0, notificationId: null, dryRun: true };
    }

    // Reserve one of today's broadcast slots and create the history doc atomically.
    const nowMs = Date.now();
    const day = bishkekDayKey(nowMs);
    const quotaRef = db().doc(`notification_quota/${day}`);
    const ref = db().collection('notifications').doc();
    await db().runTransaction(async (tx) => {
      const q = await tx.get(quotaRef);
      const count = int(q.get('count'));
      if (!canBroadcast(count)) throw new DomainError(Reasons.RATE_LIMITED, 'daily broadcast limit reached', { limit: 3 });
      tx.set(quotaRef, { day, count: count + 1, updated_at: FieldValue.serverTimestamp() }, { merge: true });
      tx.set(ref, {
        title: input.title,
        body: input.body,
        audience: input.audience,
        status: 'sending',
        recipients: recipients.length,
        tokens: tokenCount,
        sent: 0,
        failed: 0,
        pruned: 0,
        day,
        created_by: actor.uid,
        created_by_role: actor.role,
        created_at: FieldValue.serverTimestamp(),
      });
    });

    let totals: SendTotals = { sent: 0, failed: 0, pruned: 0 };
    let status = 'sent';
    try {
      totals = await send(input, recipients, ref.id);
      if (totals.sent === 0 && totals.failed > 0) status = 'failed';
    } catch (e) {
      status = 'failed';
      logger.error('broadcast failed', { notificationId: ref.id, error: String(e) });
    }
    await ref.update({ ...totals, status, completed_at: FieldValue.serverTimestamp() });
    await writeAdminLog(actor, 'send_notification', { notification_id: ref.id }, {
      audience: input.audience,
      recipients: recipients.length,
      ...totals,
      status,
    });
    logger.info('broadcast done', { notificationId: ref.id, recipients: recipients.length, ...totals });
    return { recipients: recipients.length, tokens: tokenCount, ...totals, notificationId: ref.id, dryRun: false };
  }),
);
