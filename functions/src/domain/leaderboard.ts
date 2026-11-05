/**
 * Leaderboard board selection (ARCHITECTURE §1.7, decision D10).
 *
 * - `weekly_{YYYY}-W{ww}` and `all_time` receive ALL server-awarded XP:
 *   exam XP of leaderboard-eligible attempts and the (capped) lesson /
 *   practice XP of recordActivity.
 * - `subject_{key}_weekly_{YYYY}-W{ww}` boards are exam-only and keyed by
 *   the blueprint's subject key: `main` for the main test, the subject id
 *   (`math`, `chemistry`, `biology`, `physics`, `history`, `english`,
 *   `kyrgyz_lit`, `russian_lit`) for subject tests, `state_language` for the
 *   state-language test.
 * - Leagues (ARCHITECTURE §9.3) receive exactly the XP of the weekly board:
 *   `region_{regionId}_weekly_*` when the profile has a known region, and
 *   `group_{gid}_weekly_*` for every entry of users/{uid}.group_ids.
 */
import { ALL_TIME_BOARD_ID, groupWeeklyBoardId, regionWeeklyBoardId, subjectWeeklyBoardId, weeklyBoardId } from './time';

const KEY_RE = /^[a-z][a-z0-9_]{0,39}$/;

/** Subject-board key of a blueprint, or null when it has none. */
export function leaderboardSubjectKey(blueprint: { kind: string; subject_id: string | null }): string | null {
  let key: string | null;
  if (blueprint.kind === 'main') key = 'main';
  else if (blueprint.kind === 'state_language') key = blueprint.subject_id ?? 'state_language';
  else key = blueprint.subject_id;
  return key !== null && KEY_RE.test(key) ? key : null;
}

/** Max groups per user (users/{uid}.group_ids, ARCHITECTURE §9.3). */
export const MAX_GROUP_IDS = 5;

const GROUP_ID_RE = /^[A-Za-z0-9_-]{1,64}$/;

/** Valid, unique group ids from users/{uid}.group_ids (at most MAX_GROUP_IDS). */
export function leagueGroupIds(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const g of raw) {
    if (typeof g === 'string' && GROUP_ID_RE.test(g) && !out.includes(g)) out.push(g);
  }
  return out.slice(0, MAX_GROUP_IDS);
}

export interface LeagueMembership {
  /** kg_regions.json id of the user's region, or null. */
  regionId: string | null;
  /** users/{uid}.group_ids (validated). */
  groupIds: readonly string[];
}

/**
 * Boards that XP earned at `nowMs` goes to: weekly + all-time, the subject
 * board for exams (`subjectKey`), and the weekly region / group leagues.
 */
export function leaderboardBoards(nowMs: number, subjectKey: string | null, leagues?: LeagueMembership): string[] {
  const boards = [weeklyBoardId(nowMs), ALL_TIME_BOARD_ID];
  if (subjectKey) boards.push(subjectWeeklyBoardId(subjectKey, nowMs));
  if (leagues?.regionId && KEY_RE.test(leagues.regionId)) boards.push(regionWeeklyBoardId(leagues.regionId, nowMs));
  for (const gid of leagueGroupIds(leagues?.groupIds)) boards.push(groupWeeklyBoardId(gid, nowMs));
  return boards;
}
