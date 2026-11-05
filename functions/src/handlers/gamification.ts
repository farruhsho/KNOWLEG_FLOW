/**
 * Persistence for server-side gamification: user_stats documents,
 * idempotent xp_events, and leaderboard entries (including the region and
 * group leagues of ARCHITECTURE §9.3).
 */
import { readFileSync } from 'node:fs';
import path from 'node:path';
import type { DocumentSnapshot, Transaction } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { leaderboardBoards, leagueGroupIds } from '../domain/leaderboard';
import { buildRegionIndex, regionIdFromProfile, type RegionIndex } from '../domain/regions';
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
    study_seconds_total: s.study_seconds_total,
    study_seconds_today: s.study_seconds_today,
    study_day: s.study_day,
    updated_at: FieldValue.serverTimestamp(),
  };
}

let regions: RegionIndex | null = null;

/** kg_regions.json bundled with the build (copied from assets/data), loaded once. */
export function regionIndex(): RegionIndex {
  if (regions) return regions;
  const candidates = [
    path.join(__dirname, '..', 'data', 'kg_regions.json'),
    path.join(__dirname, '..', '..', '..', 'assets', 'data', 'kg_regions.json'),
  ];
  for (const file of candidates) {
    try {
      const index = buildRegionIndex(JSON.parse(readFileSync(file, 'utf8')));
      if (index.ids.size > 0) return (regions = index);
    } catch {
      // try next candidate
    }
  }
  logger.error('kg_regions.json not bundled: regional leagues are disabled');
  return (regions = buildRegionIndex(null));
}

export interface LeaderboardProfile {
  display_name: string;
  avatar_url: string | null;
  region_id: string | null;
  banned: boolean;
  /** kg_regions.json id for the regional league, or null. */
  league_region_id: string | null;
  /** users/{uid}.group_ids for the group leagues. */
  group_ids: string[];
}

/** Display name used on leaderboard entries, group members, friends and referral items. */
export function displayNameOf(d: Record<string, unknown> | undefined): string {
  const name = str(d?.['name']).trim() || str(d?.['display_name']).trim();
  return (name || 'Student').slice(0, 40);
}

/** Public leaderboard fields from users/{uid} (no email/phone ever). */
export function profileFromUserDoc(snap: DocumentSnapshot): LeaderboardProfile {
  const d = snap.exists ? (snap.data() ?? {}) : {};
  const region = isRecord(d['region']) ? d['region'] : {};
  return {
    display_name: displayNameOf(d),
    avatar_url: strOrNull(d['avatar_url']) ?? strOrNull(d['photo_url']) ?? strOrNull(d['photoUrl']),
    region_id: strOrNull(region['oblast']) ?? strOrNull(d['region_id']),
    banned: d['is_banned'] === true,
    league_region_id: regionIdFromProfile(d, regionIndex()),
    group_ids: leagueGroupIds(d['group_ids']),
  };
}

/**
 * Adds `xp` to the weekly and all-time boards, the subject weekly board when
 * `subjectKey` is given (exams only, see domain/leaderboard.ts), and the
 * weekly region / group leagues of the profile (ARCHITECTURE §9.3).
 * Banned users never get entries. Entries carry `uid` so accountDelete and
 * the ban trigger can find them.
 */
export function addLeaderboardXp(
  tx: Transaction,
  uid: string,
  profile: LeaderboardProfile,
  xp: number,
  nowMs: number,
  subjectKey: string | null,
): void {
  if (xp <= 0 || profile.banned) return;
  const leagues = { regionId: profile.league_region_id, groupIds: profile.group_ids };
  for (const board of leaderboardBoards(nowMs, subjectKey, leagues)) {
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
