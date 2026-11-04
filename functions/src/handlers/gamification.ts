/**
 * Persistence for server-side gamification: user_stats documents,
 * idempotent xp_events, and leaderboard entries.
 */
import type { DocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { ALL_TIME_BOARD_ID, subjectWeeklyBoardId, weeklyBoardId } from '../domain/time';
import { isRecord, str, strOrNull } from '../domain/types';
import type { UserStats } from '../domain/xp';
import { db, FieldValue, Timestamp } from './common';

export function statsRef(uid: string) {
  return db().doc(`user_stats/${uid}`);
}

export function xpEventRef(uid: string, eventId: string) {
  return db().doc(`xp_events/${uid}/events/${eventId}`);
}

export function statsToDoc(s: UserStats): Record<string, unknown> {
  const achievements: Record<string, Timestamp> = {};
  for (const [k, ms] of Object.entries(s.achievements)) achievements[k] = Timestamp.fromMillis(ms);
  return {
    xp: s.xp,
    level: s.level,
    current_streak: s.current_streak,
    best_streak: s.best_streak,
    last_active_day: s.last_active_day,
    active_days_total: s.active_days_total,
    today_xp: s.today_xp,
    today_practice_xp: s.today_practice_xp,
    daily_goal_xp: s.daily_goal_xp,
    daily_goal_awarded_day: s.daily_goal_awarded_day,
    exams_completed: s.exams_completed,
    lessons_completed: s.lessons_completed,
    best_exam_percent: s.best_exam_percent,
    section_90_counts: s.section_90_counts,
    achievements,
    updated_at: FieldValue.serverTimestamp(),
  };
}

export interface LeaderboardProfile {
  display_name: string;
  avatar_url: string | null;
  region_id: string | null;
  banned: boolean;
}

/** Public leaderboard fields from users/{uid} (no email/phone ever). */
export function profileFromUserDoc(snap: DocumentSnapshot): LeaderboardProfile {
  const d = snap.exists ? (snap.data() ?? {}) : {};
  const region = isRecord(d['region']) ? d['region'] : {};
  const name = str(d['name']).trim() || str(d['display_name']).trim();
  return {
    display_name: (name || 'Student').slice(0, 40),
    avatar_url: strOrNull(d['avatar_url']) ?? strOrNull(d['photo_url']) ?? strOrNull(d['photoUrl']),
    region_id: strOrNull(region['oblast']) ?? strOrNull(d['region_id']),
    banned: d['is_banned'] === true,
  };
}

/**
 * Adds `xp` to the weekly and all-time boards (and the subject weekly board
 * for subject tests). Entries carry `uid` so accountDelete can find them.
 */
export function addLeaderboardXp(
  tx: Transaction,
  uid: string,
  profile: LeaderboardProfile,
  xp: number,
  nowMs: number,
  subjectId: string | null,
): void {
  if (xp <= 0 || profile.banned) return;
  const boards = [weeklyBoardId(nowMs), ALL_TIME_BOARD_ID];
  if (subjectId) boards.push(subjectWeeklyBoardId(subjectId, nowMs));
  for (const board of boards) {
    tx.set(
      db().doc(`leaderboards/${board}/entries/${uid}`),
      {
        uid,
        display_name: profile.display_name,
        avatar_url: profile.avatar_url,
        region_id: profile.region_id,
        xp: FieldValue.increment(xp),
        updated_at: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
}
