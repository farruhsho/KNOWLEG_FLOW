/**
 * Prompts and output schemas for the paid stages. System prompts are stable
 * strings (prompt-cache friendly); everything variable goes in the user turn.
 * Output schemas are deliberately simple (no nullable unions, no numeric
 * bounds) so they stay inside the structured-outputs subset; the pipeline
 * re-validates every result with zod.
 */
import { ISSUE_KINDS, OPTION_IDS } from './schema';

export const PROMPT_VERSION = 'v1-2026-11';

export const GENERATION_SYSTEM = `You write ORIGINAL practice items for "ORT Master KG", an exam-preparation app for school leavers in Kyrgyzstan who take the ORT (Общереспубликанское тестирование / ЖРТ).

Hard rules — an item that breaks any of them is worthless:
1. Originality. Never reproduce, translate, paraphrase or lightly edit items from ЦООМО / testing.kg (brochures, online sample tests, past papers), Secom, ORTPREP or any other publisher, textbook problem book or website. Invent new content: new numbers, new contexts, new wording. Do not imitate a specific published item.
2. Never present an item as official, as a "real ORT question", or as coming from ЦООМО.
3. Exactly one option is correct; every other option is definitely wrong. No "all of the above", "none of the above", trick wording, or double negatives.
4. Distractors are plausible and each one corresponds to a typical student mistake; write that mistake in wrong_option_notes for every wrong option.
5. The explanation is a clear step-by-step solution a 16-year-old can follow; solution_steps lists the same steps briefly.
6. Content stays inside the Kyrgyz school programme for the given grades; basis names the grade and topic of the programme (e.g. "Программа 8 кл., алгебра: квадратные уравнения").
7. Language. Write in the requested language only. Russian: standard literary Russian. Kyrgyz: natural literary Kyrgyz in Cyrillic with ң, ө, ү — written as a native author would, not a word-for-word translation from Russian. English (English subject test only): clear standard English.
8. Mathematics: LaTeX inside $...$; decimal comma in Russian and Kyrgyz written as {,} inside LaTeX (e.g. $2{,}5$); numeric options in ascending order; no calculator-only arithmetic.
9. Difficulty: 1 = one routine step; 2 = two or three steps or one common trap; 3 = multi-step reasoning or a non-routine idea. Difficulty must match the request.
10. quantitative_comparison items: give an optional condition and two quantities (column A / column Б). The options are fixed by the blueprint and mean: A — column A is greater, B — column Б is greater, C — they are equal, D — the relation cannot be determined from the information given. Use D only when the relation genuinely depends on unknown values; prove it in the explanation with two cases.
11. analogy items: the stem is a word pair "СЛОВО1 : СЛОВО2" (capitals); each option is a pair "слово : слово"; exactly one option has the same relation type as the stem, and the explanation names the relation.
12. completion items: a sentence with one or two gaps shown as "____"; each option fills all gaps (for two gaps "слово1 … слово2").
13. Reading passages are original texts of the requested length, style and genre, suitable for school leavers, with facts that are true or clearly fictional.

Return only JSON that matches the response schema.`;

export const TRANSLATION_SYSTEM = `You translate ORIGINAL exam-practice items for "ORT Master KG" between Russian and Kyrgyz.

Rules:
1. Keep the meaning, difficulty, numbers, formulas (LaTeX in $...$ unchanged), the order of options and which option is correct. Never change the key.
2. Write natural literary target language: Kyrgyz in Cyrillic with ң, ө, ү, as a native author would phrase it (not word-for-word); Russian in standard literary style. Use the school-programme terminology of the target language.
3. If an item cannot be translated without changing what it tests (wordplay, a grammar point of the source language, an analogy whose relation breaks in translation), set translatable=false and explain why.
4. Translate the explanation, solution steps and wrong-option notes too.

Return only JSON that matches the response schema.`;

export const VERIFY_SYSTEM = `You are an independent reviewer of multiple-choice exam-practice items. You receive an item WITHOUT its answer key. Solve it yourself from scratch, then audit it.

Report:
- answer: the single option you consider correct, or NONE if no option is correct, or MULTIPLE if more than one option is defensibly correct;
- correct_options: every option you consider correct;
- confidence: low / medium / high;
- issues: each problem with kind (ambiguity, multiple_correct, no_correct, factual_error, language_quality, off_programme, copyright_risk, other), severity (blocker = item unusable, major = must be fixed, minor = polish) and a short note;
- language_quality: ok / minor_issues / poor (grammar, spelling, naturalness of the item's language; for Kyrgyz check ң ө ү and natural phrasing);
- solution: your brief reasoning.

Flag copyright_risk if the item looks copied from a known published test. Be strict: an item with any doubt about the uniquely correct answer must get an issue.

Return only JSON that matches the response schema.`;

export const TRANSLATE_CHECK_SYSTEM = `You check that two language versions (Russian and Kyrgyz) of the same exam-practice item are equivalent.

Check: same meaning of stem and every option, same numbers and formulas, same correct option and the explanation supports it in both languages, same difficulty, no information added or lost, and natural literary target language (Kyrgyz with ң ө ү, native phrasing). Report each problem with the field (stem, options, explanation, wrong_option_notes, passage, other), severity (blocker / major / minor) and a note.

Return only JSON that matches the response schema.`;

const str = { type: 'string' };
const strArr = { type: 'array', items: str };
const obj = (properties: Record<string, unknown>): Record<string, unknown> => ({
  type: 'object',
  additionalProperties: false,
  required: Object.keys(properties),
  properties,
});

const wrongNotes = (ids: readonly string[]): Record<string, unknown> => ({
  type: 'array',
  items: obj({ option: { type: 'string', enum: [...ids] }, note: str }),
});

export function choiceItemSchema(optionIds: readonly string[], subtopics: string[]): Record<string, unknown> {
  return obj({
    subtopic_id: subtopics.length ? { type: 'string', enum: subtopics } : str,
    stem: str,
    options: strArr,
    correct: { type: 'string', enum: [...optionIds] },
    explanation: str,
    solution_steps: strArr,
    wrong_option_notes: wrongNotes(optionIds),
    basis: str,
  });
}

export function comparisonItemSchema(subtopics: string[]): Record<string, unknown> {
  const ids = OPTION_IDS.slice(0, 4);
  return obj({
    subtopic_id: subtopics.length ? { type: 'string', enum: subtopics } : str,
    condition: str,
    column_a: str,
    column_b: str,
    correct: { type: 'string', enum: [...ids] },
    explanation: str,
    solution_steps: strArr,
    wrong_option_notes: wrongNotes(ids),
    basis: str,
  });
}

export function itemsEnvelope(item: Record<string, unknown>): Record<string, unknown> {
  return obj({ items: { type: 'array', items: item } });
}

export function passageGroupSchema(optionIds: readonly string[], topicIds: string[]): Record<string, unknown> {
  return obj({
    texts: { type: 'array', items: obj({ title: str, text: str }) },
    basis: str,
    questions: {
      type: 'array',
      items: obj({
        topic_id: { type: 'string', enum: topicIds },
        difficulty: { type: 'string', enum: ['1', '2', '3'] },
        stem: str,
        options: strArr,
        correct: { type: 'string', enum: [...optionIds] },
        explanation: str,
        solution_steps: strArr,
        wrong_option_notes: wrongNotes(optionIds),
      }),
    },
  });
}

export function translationSchema(optionIds: readonly string[]): Record<string, unknown> {
  return obj({
    translatable: { type: 'boolean' },
    reason: str,
    stem: str,
    table_rows: { type: 'array', items: strArr },
    options: strArr,
    correct: { type: 'string', enum: [...optionIds] },
    explanation: str,
    solution_steps: strArr,
    wrong_option_notes: wrongNotes(optionIds),
  });
}

export const VERIFY_SCHEMA: Record<string, unknown> = obj({
  answer: { type: 'string', enum: [...OPTION_IDS, 'NONE', 'MULTIPLE'] },
  correct_options: { type: 'array', items: { type: 'string', enum: [...OPTION_IDS] } },
  confidence: { type: 'string', enum: ['low', 'medium', 'high'] },
  issues: { type: 'array', items: obj({ kind: { type: 'string', enum: [...ISSUE_KINDS] }, severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, note: str }) },
  language_quality: { type: 'string', enum: ['ok', 'minor_issues', 'poor'] },
  solution: str,
});

export const TRANSLATE_CHECK_SCHEMA: Record<string, unknown> = obj({
  equivalent: { type: 'boolean' },
  target_language_quality: { type: 'string', enum: ['ok', 'minor_issues', 'poor'] },
  issues: { type: 'array', items: obj({ field: str, severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, note: str }) },
});

export const LANGUAGE_NAMES: Record<string, string> = { ru: 'Russian', ky: 'Kyrgyz', en: 'English' };
