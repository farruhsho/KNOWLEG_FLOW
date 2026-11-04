/**
 * Server-side exam scoring (ARCHITECTURE §1.4 ExamResult). Pure: takes the
 * attempt's question layout, the submitted answers and the answer keys, and
 * returns correctness per question, per section and per topic.
 *
 * Scoring method is "raw" (one point per correct answer, no penalty for
 * wrong answers): the official ORT conversion formula is not published, so
 * the result is always flagged as unofficial (`disclaimer_key`).
 */

export interface ScoringSection {
  section_id: string;
  question_ids: string[];
}

export interface ScoringInput {
  sections: ScoringSection[];
  /** answers[sectionId][questionId] = option id or null (unanswered). */
  answers: Record<string, Record<string, string | null | undefined> | undefined>;
  /** Correct option id per question. Missing = question cannot be scored. */
  keys: Record<string, string | null | undefined>;
  /** topic_id per question (from exam_questions). */
  topics: Record<string, string | null | undefined>;
}

export interface QuestionOutcome {
  question_id: string;
  section_id: string;
  topic_id: string | null;
  user_answer: string | null;
  correct_answer: string | null;
  answered: boolean;
  is_correct: boolean;
  scored: boolean;
}

export interface SectionScore {
  section_id: string;
  correct: number;
  total: number;
  percent: number;
}

export interface TopicScore {
  topic_id: string;
  correct: number;
  total: number;
}

export interface ExamScore {
  correct: number;
  total: number;
  percent: number;
  /** Answers given, including answers to unscored (key-less) questions. */
  answered: number;
  /** Scored questions answered wrongly. correct + incorrect + skipped == total. */
  incorrect: number;
  /** Scored questions left unanswered. */
  skipped: number;
  unscored: number;
  sections: SectionScore[];
  topics: TopicScore[];
  weak_topics: string[];
  strong_topics: string[];
  outcomes: QuestionOutcome[];
}

export interface ScoringOptions {
  /** A topic is weak when accuracy is below this (and total >= minTopicTotal). */
  weakBelow?: number;
  /** A topic is strong when accuracy is at least this. */
  strongAtLeast?: number;
  minTopicTotal?: number;
  maxTopics?: number;
}

export function round1(x: number): number {
  return Math.round(x * 10) / 10;
}

export function percentOf(correct: number, total: number): number {
  return total > 0 ? round1((correct / total) * 100) : 0;
}

function normalize(answer: string | null | undefined): string | null {
  if (typeof answer !== 'string') return null;
  const t = answer.trim().toUpperCase();
  return t.length > 0 ? t : null;
}

export function scoreAttempt(input: ScoringInput, options: ScoringOptions = {}): ExamScore {
  const weakBelow = options.weakBelow ?? 0.5;
  const strongAtLeast = options.strongAtLeast ?? 0.8;
  const minTopicTotal = options.minTopicTotal ?? 2;
  const maxTopics = options.maxTopics ?? 5;

  const outcomes: QuestionOutcome[] = [];
  const sections: SectionScore[] = [];
  const topicAgg = new Map<string, { correct: number; total: number }>();
  let correct = 0;
  let total = 0;
  let answered = 0;
  let incorrect = 0;
  let skipped = 0;
  let unscored = 0;

  for (const section of input.sections) {
    const sectionAnswers = input.answers[section.section_id] ?? {};
    let sCorrect = 0;
    let sTotal = 0;
    for (const qid of section.question_ids) {
      const key = normalize(input.keys[qid]);
      const userAnswer = normalize(sectionAnswers[qid]);
      const topicId = input.topics[qid] ?? null;
      const scored = key !== null;
      const isCorrect = scored && userAnswer !== null && userAnswer === key;
      outcomes.push({
        question_id: qid,
        section_id: section.section_id,
        topic_id: topicId,
        user_answer: userAnswer,
        correct_answer: key,
        answered: userAnswer !== null,
        is_correct: isCorrect,
        scored,
      });
      if (userAnswer !== null) answered++;
      if (!scored) {
        unscored++;
        continue;
      }
      sTotal++;
      if (isCorrect) sCorrect++;
      else if (userAnswer === null) skipped++;
      else incorrect++;
      if (topicId) {
        const agg = topicAgg.get(topicId) ?? { correct: 0, total: 0 };
        agg.total++;
        if (isCorrect) agg.correct++;
        topicAgg.set(topicId, agg);
      }
    }
    sections.push({
      section_id: section.section_id,
      correct: sCorrect,
      total: sTotal,
      percent: percentOf(sCorrect, sTotal),
    });
    correct += sCorrect;
    total += sTotal;
  }

  const topics: TopicScore[] = [...topicAgg.entries()]
    .map(([topic_id, a]) => ({ topic_id, correct: a.correct, total: a.total }))
    .sort((a, b) => a.topic_id.localeCompare(b.topic_id));

  const eligible = topics.filter((t) => t.total >= minTopicTotal);
  const acc = (t: TopicScore) => t.correct / t.total;
  const weak_topics = eligible
    .filter((t) => acc(t) < weakBelow)
    .sort((a, b) => acc(a) - acc(b) || b.total - a.total || a.topic_id.localeCompare(b.topic_id))
    .slice(0, maxTopics)
    .map((t) => t.topic_id);
  const strong_topics = eligible
    .filter((t) => acc(t) >= strongAtLeast)
    .sort((a, b) => acc(b) - acc(a) || b.total - a.total || a.topic_id.localeCompare(b.topic_id))
    .slice(0, maxTopics)
    .map((t) => t.topic_id);

  return {
    correct,
    total,
    percent: percentOf(correct, total),
    answered,
    incorrect,
    skipped,
    unscored,
    sections,
    topics,
    weak_topics,
    strong_topics,
    outcomes,
  };
}

/** Wrong answers (answered and incorrect) — these go to user_mistakes. */
export function wrongOutcomes(score: ExamScore): QuestionOutcome[] {
  return score.outcomes.filter((o) => o.scored && o.answered && !o.is_correct);
}

export interface ExamResult {
  correct: number;
  total: number;
  percent: number;
  answered: number;
  /** Scored questions answered wrongly (decision D4). */
  incorrect: number;
  /** Scored questions left unanswered (decision D4). */
  skipped: number;
  sections: SectionScore[];
  topics: TopicScore[];
  weak_topics: string[];
  strong_topics: string[];
  xp_awarded: number;
  leaderboard_eligible: boolean;
  disclaimer_key: 'exam_result_unofficial';
}

export function buildExamResult(score: ExamScore, xpAwarded: number, leaderboardEligible: boolean): ExamResult {
  return {
    correct: score.correct,
    total: score.total,
    percent: score.percent,
    answered: score.answered,
    incorrect: score.incorrect,
    skipped: score.skipped,
    sections: score.sections,
    topics: score.topics,
    weak_topics: score.weak_topics,
    strong_topics: score.strong_topics,
    xp_awarded: xpAwarded,
    leaderboard_eligible: leaderboardEligible,
    disclaimer_key: 'exam_result_unofficial',
  };
}
