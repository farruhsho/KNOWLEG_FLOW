import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { activityEventId, dailyLessonTarget, isActivityKind, practiceCorrectCount, shouldPersistAward } from '../src/domain/activity';
import { leaderboardBoards, leaderboardSubjectKey } from '../src/domain/leaderboard';
import { applyLessonCompleted, applyPracticeCorrect, emptyStats, XP_RULES } from '../src/domain/xp';
import { blueprint, bishkek, rawBlueprints } from './fixtures';

describe('recordActivity event ids (D10)', () => {
  const t = bishkek(2026, 11, 4, 12);

  it('are namespaced per kind, and per Bishkek day for practice', () => {
    const lesson = activityEventId('lesson_completed', 'l1', t);
    const practice = activityEventId('practice_answered', 'l1', t);
    assert.match(lesson, /^lesson_[0-9a-f]{40}$/);
    assert.match(practice, /^practice_2026-11-04_[0-9a-f]{40}$/);
    assert.notEqual(lesson, practice);
    // Same lesson on another day: same id (awarded once ever). Same practice ref on another day: new id.
    assert.equal(activityEventId('lesson_completed', 'l1', t + 86_400_000), lesson);
    assert.notEqual(activityEventId('practice_answered', 'l1', t + 86_400_000), practice);
    assert.ok(isActivityKind('lesson_completed') && isActivityKind('practice_answered') && !isActivityKind('exam'));
  });

  it('practiceCorrectCount clamps the client-reported count', () => {
    assert.equal(practiceCorrectCount(false, 10), 0);
    assert.equal(practiceCorrectCount(true, undefined), 1);
    assert.equal(practiceCorrectCount(500, undefined), 50);
    assert.equal(practiceCorrectCount(undefined, 7), 7);
  });
});

describe('practice XP cap: a 0 award writes nothing (SEC-XP-01)', () => {
  it('once today_practice_xp hits the cap, fresh refIds earn 0 and must not be persisted', () => {
    const t = bishkek(2026, 11, 4, 15);
    let stats = emptyStats();
    let persisted = 0;
    for (let i = 0; i < 200; i++) {
      const award = applyPracticeCorrect(stats, 1, t + i);
      if (!shouldPersistAward(award.total)) continue;
      persisted++;
      stats = award.stats;
    }
    assert.equal(stats.today_practice_xp, XP_RULES.PRACTICE_DAILY_CAP);
    assert.equal(persisted, XP_RULES.PRACTICE_DAILY_CAP / XP_RULES.PRACTICE_CORRECT);
    const capped = applyPracticeCorrect(stats, 50, t + 1000);
    assert.equal(capped.total, 0);
    assert.equal(shouldPersistAward(capped.total), false);
    assert.equal(shouldPersistAward(applyPracticeCorrect(emptyStats(), 0, t).total), false);
    assert.equal(shouldPersistAward(applyLessonCompleted(stats, t).total), true);
  });
});

describe('daily_lessons pointers resolve to the real lesson (GAM-X5)', () => {
  it('reads lesson_id / lessonId and rejects junk', () => {
    assert.equal(dailyLessonTarget({ lesson_id: 'lesson_42' }), 'lesson_42');
    assert.equal(dailyLessonTarget({ lessonId: 'lesson_7' }), 'lesson_7');
    assert.equal(dailyLessonTarget({ lesson_id: 'a/b' }), null);
    assert.equal(dailyLessonTarget({ title: 'x' }), null);
    assert.equal(dailyLessonTarget(null), null);
    // The award is keyed by the resolved lesson id, so the pointer and the lesson dedupe.
    const t = bishkek(2026, 11, 1, 9);
    assert.equal(activityEventId('lesson_completed', dailyLessonTarget({ lesson_id: 'lesson_42' })!, t), activityEventId('lesson_completed', 'lesson_42', t));
  });
});

describe('leaderboard boards (D10)', () => {
  const t = bishkek(2026, 11, 4, 12);

  it('weekly and all-time boards get every award; the subject board only when a key is given', () => {
    assert.deepEqual(leaderboardBoards(t, null), ['weekly_2026-W45', 'all_time']);
    assert.deepEqual(leaderboardBoards(t, 'main'), ['weekly_2026-W45', 'all_time', 'subject_main_weekly_2026-W45']);
  });

  it('subject keys: main, the subject ids, state_language', () => {
    const keys = Object.fromEntries(rawBlueprints().map((b) => [b['id'], leaderboardSubjectKey(blueprint(b['id'] as string))]));
    assert.deepEqual(keys, {
      ort_main_2026: 'main',
      ort_subject_chemistry_2026: 'chemistry',
      ort_subject_biology_2026: 'biology',
      ort_subject_physics_2026: 'physics',
      ort_subject_math_2026: 'math',
      ort_subject_history_2026: 'history',
      ort_subject_english_2026: 'english',
      ort_subject_kyrgyz_lit_2026: 'kyrgyz_lit',
      ort_subject_russian_lit_2026: 'russian_lit',
      ort_state_language_2026: 'state_language',
    });
    assert.equal(leaderboardSubjectKey({ kind: 'state_language', subject_id: null }), 'state_language');
    assert.equal(leaderboardSubjectKey({ kind: 'subject', subject_id: null }), null);
    assert.equal(leaderboardSubjectKey({ kind: 'subject', subject_id: 'Bad/Id' }), null);
  });
});
