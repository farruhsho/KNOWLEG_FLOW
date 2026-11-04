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
 */
import { ALL_TIME_BOARD_ID, subjectWeeklyBoardId, weeklyBoardId } from './time';

const KEY_RE = /^[a-z][a-z0-9_]{0,39}$/;

/** Subject-board key of a blueprint, or null when it has none. */
export function leaderboardSubjectKey(blueprint: { kind: string; subject_id: string | null }): string | null {
  let key: string | null;
  if (blueprint.kind === 'main') key = 'main';
  else if (blueprint.kind === 'state_language') key = blueprint.subject_id ?? 'state_language';
  else key = blueprint.subject_id;
  return key !== null && KEY_RE.test(key) ? key : null;
}

/** Boards that XP earned at `nowMs` goes to (subject board only for exams). */
export function leaderboardBoards(nowMs: number, subjectKey: string | null): string[] {
  const boards = [weeklyBoardId(nowMs), ALL_TIME_BOARD_ID];
  if (subjectKey) boards.push(subjectWeeklyBoardId(subjectKey, nowMs));
  return boards;
}
