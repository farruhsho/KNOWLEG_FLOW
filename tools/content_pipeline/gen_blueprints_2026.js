// Generates assets/data/exam_blueprints.json (ORT 2026), run from repo root.
const fs = require('fs');
const SRC = { url: 'https://testing.kg/media/uploads/2026/06/01/brosh_rus_2026.pdf', verified_at: '2026-11-02', note: 'Брошюра ЦООМО «Готовимся к ОРТ», Бишкек 2026. Структура совпадает с изданием 2025.' };
const DISC = {
  ru: 'Учебный результат приложения. Не является официальным баллом ОРТ: официальная формула пересчёта ЦООМО не опубликована.',
  ky: 'Тиркеменин окуу жыйынтыгы. ЖРТнын расмий баллы эмес: БББЖБнын расмий эсептөө формуласы жарыяланган эмес.',
  en: 'Practice result. Not an official ORT score: the official conversion formula is not published.',
};
const raw = { method: 'raw', official_scale_known: false, disclaimer: DISC };
const nav = { within_section: 'free', across_sections: 'forward_only' };
const mix = { '1': 0.3, '2': 0.5, '3': 0.2 };
const t = (ru, ky, en) => ({ ru, ky, en });

const main = {
  id: 'ort_main_2026', kind: 'main', subject_id: null, exam_year: 2026, version: 1, status: 'active',
  title: t('Основной тест ОРТ', 'ЖРТнын негизги тести', 'ORT Main test'),
  languages: ['ru', 'ky'], options_per_question: 4, navigation: nav,
  sections: [
    {
      id: 'math', order: 1, title: t('Математика', 'Математика', 'Mathematics'),
      question_count: 60, duration_minutes: 90, points_per_question: 1, subject_area: 'math',
      allow_scratchpad: true, uses_passages: false, difficulty_mix: mix,
      parts: [
        {
          id: 'math_comparison', title: t('Часть I. Сравнение величин', 'I бөлүк. Чоңдуктарды салыштыруу', 'Part I. Quantitative comparison'),
          question_count: 30, options_per_question: 4, item_type: 'quantitative_comparison', verified: true,
          fixed_options: [
            { id: 'A', text: t('Величина в колонке А больше', 'А мамычасындагы чоңдук чоң', 'Column A is greater') },
            { id: 'B', text: t('Величина в колонке Б больше', 'Б мамычасындагы чоңдук чоң', 'Column B is greater') },
            { id: 'C', text: t('Величины равны', 'Чоңдуктар барабар', 'The quantities are equal') },
            { id: 'D', text: t('Информации недостаточно, чтобы определить', 'Аныктоо үчүн маалымат жетишсиз', 'Cannot be determined') },
          ],
        },
        { id: 'math_problems', title: t('Часть II. Задачи', 'II бөлүк. Маселелер', 'Part II. Problems'), question_count: 30, options_per_question: 5, item_type: 'single_choice', verified: true },
      ],
    },
    {
      id: 'verbal', order: 2, title: t('Аналогии и дополнение предложений', 'Аналогиялар жана сүйлөмдөрдү толуктоо', 'Analogies and sentence completion'),
      question_count: 30, duration_minutes: 30, points_per_question: 1, subject_area: 'verbal',
      allow_scratchpad: false, uses_passages: false, difficulty_mix: mix,
      parts: [
        { id: 'analogies', title: t('Аналогии', 'Аналогиялар', 'Analogies'), question_count: 15, options_per_question: 4, item_type: 'analogy', verified: false, note: 'Деление 30 заданий между частями в брошюре не указано; 15/15 — рабочее допущение.' },
        { id: 'completion', title: t('Дополнение предложений', 'Сүйлөмдөрдү толуктоо', 'Sentence completion'), question_count: 15, options_per_question: 4, item_type: 'completion', verified: false },
      ],
    },
    {
      id: 'reading', order: 3, title: t('Чтение и понимание', 'Окуу жана түшүнүү', 'Reading comprehension'),
      question_count: 30, duration_minutes: 60, points_per_question: 1, subject_area: 'reading',
      allow_scratchpad: false, uses_passages: true, difficulty_mix: mix,
      passage_layout: { standalone_texts: 2, paired_texts: 1, words_min: 400, words_max: 850, line_numbering_every: 5 },
      parts: [{ id: 'reading', title: t('Чтение и понимание', 'Окуу жана түшүнүү', 'Reading'), question_count: 30, options_per_question: 4, item_type: 'text_based', verified: true }],
    },
    {
      id: 'grammar', order: 4, title: t('Практическая грамматика', 'Практикалык грамматика', 'Practical grammar'),
      question_count: 30, duration_minutes: 35, points_per_question: 1, subject_area: 'grammar',
      allow_scratchpad: false, uses_passages: false, language_specific: true, difficulty_mix: mix,
      task_types: ['spelling', 'punctuation', 'word_formation', 'completion', 'lexical_grammatical_meaning', 'usage_norms'],
      parts: [{ id: 'grammar', title: t('Практическая грамматика', 'Практикалык грамматика', 'Grammar'), question_count: 30, options_per_question: 4, item_type: 'single_choice', verified: true }],
    },
  ],
  scoring: raw,
  rules: { calculators: false, scratchpad_sections: ['math'], one_attempt_per_year: true, no_wrong_answer_penalty_assumed: true },
  reference: {
    official_max_score: 245,
    thresholds_2026_27: {
      university: { general: 110, pedagogical_grant: 130, pedagogical_contract: 115, healthcare_grant: 120, healthcare_contract: 110, agriculture: 100, military_grant: 90, special_categories: 90, subject_tests: 60 },
      college: { general: 90, pedagogical_healthcare_grant: 95, pedagogical_healthcare_contract: 90, agriculture: 80, special_categories: 70, subject_tests: 40 },
    },
    source: 'https://testing.kg/news/porogovyie-ballyi-dlya-priema-v-obrazovatelnyie-organizatsii-vyisshego-professionalnogo-obrazovaniya732',
  },
  source: SRC, effective_from: '2026-01-01', effective_to: null,
};

function subject(id, title, q, min, parts, scratch, extra = {}) {
  return Object.assign({
    id: `ort_subject_${id}_2026`, kind: 'subject', subject_id: id, exam_year: 2026, version: 1, status: 'active',
    title, languages: ['ru', 'ky'], options_per_question: 4, navigation: nav,
    sections: [{
      id, order: 1, title, question_count: q, duration_minutes: min, points_per_question: 1, subject_area: id,
      allow_scratchpad: scratch, uses_passages: parts.some((p) => p.item_type === 'text_based'), difficulty_mix: mix, parts,
    }],
    scoring: raw, rules: { calculators: false, scratchpad_sections: scratch ? [id] : [] },
    reference: { official_max_score: 150, threshold_university: 60, threshold_college: 40 },
    source: SRC, effective_from: '2026-01-01', effective_to: null,
  }, extra);
}
const one = (id, q, title) => [{ id, title, question_count: q, options_per_question: 4, item_type: 'single_choice', verified: true }];

const subjects = [
  subject('chemistry', t('Химия', 'Химия', 'Chemistry'), 40, 80, one('chemistry', 40, t('Химия', 'Химия', 'Chemistry')), true),
  subject('biology', t('Биология', 'Биология', 'Biology'), 40, 60, one('biology', 40, t('Биология', 'Биология', 'Biology')), true),
  subject('physics', t('Физика', 'Физика', 'Physics'), 40, 80, one('physics', 40, t('Физика', 'Физика', 'Physics')), true),
  subject('math', t('Математика (предметный тест)', 'Математика (предметтик тест)', 'Mathematics (subject test)'), 40, 80, one('math', 40, t('Математика', 'Математика', 'Mathematics')), true),
  subject('history', t('История', 'Тарых', 'History'), 40, 60, one('history', 40, t('История', 'Тарых', 'History')), true),
  subject('english', t('Английский язык', 'Англис тили', 'English'), 50, 60, [
    { id: 'english_lexgram', title: t('Лексика и грамматика', 'Лексика жана грамматика', 'Vocabulary and grammar'), question_count: 40, options_per_question: 4, item_type: 'single_choice', verified: false, note: 'Брошюра: 40 + 2 текста × 5; онлайн-образец ЦООМО: 45 + 5. Сверить перед выпуском.' },
    { id: 'english_reading', title: t('Чтение', 'Окуу', 'Reading'), question_count: 10, options_per_question: 4, item_type: 'text_based', verified: false },
  ], false, { languages: ['en'] }),
  subject('kyrgyz_lit', t('Кыргызский язык и литература', 'Кыргыз тили жана адабияты', 'Kyrgyz language and literature'), 40, 60, [
    { id: 'kyrgyz_language', title: t('Язык', 'Тил', 'Language'), question_count: 20, options_per_question: 4, item_type: 'single_choice', verified: true, note: '15 отдельных + 5 к тексту' },
    { id: 'kyrgyz_literature', title: t('Литература', 'Адабият', 'Literature'), question_count: 20, options_per_question: 4, item_type: 'single_choice', verified: true },
  ], false, { languages: ['ky'] }),
  subject('russian_lit', t('Русский язык и литература', 'Орус тили жана адабияты', 'Russian language and literature'), 40, 60, [
    { id: 'russian_language', title: t('Язык', 'Тил', 'Language'), question_count: 20, options_per_question: 4, item_type: 'single_choice', verified: true, note: '15 отдельных + 5 к тексту' },
    { id: 'russian_literature', title: t('Литература', 'Адабият', 'Literature'), question_count: 20, options_per_question: 4, item_type: 'single_choice', verified: true },
  ], false, { languages: ['ru'] }),
];

const stateLanguage = {
  id: 'ort_state_language_2026', kind: 'state_language', subject_id: 'state_language', exam_year: 2026, version: 1, status: 'active',
  title: t('Тест по государственному языку', 'Мамлекеттик тил боюнча тест', 'State language (Kyrgyz) test'),
  languages: ['ky'], options_per_question: 4, navigation: nav,
  sections: [{
    id: 'state_language', order: 1, title: t('Государственный язык', 'Мамлекеттик тил', 'State language'),
    question_count: 50, duration_minutes: 60, points_per_question: 1, subject_area: 'state_language',
    allow_scratchpad: false, uses_passages: true, difficulty_mix: mix,
    parts: [
      { id: 'state_lexgram', title: t('Лексика и грамматика', 'Лексика жана грамматика', 'Vocabulary and grammar'), question_count: 40, options_per_question: 4, item_type: 'single_choice', verified: false, note: 'Деление 40/10 — допущение: в брошюре часть 1 лексико-грамматическая, часть 2 — 2 текста × 5 вопросов.' },
      { id: 'state_reading', title: t('Чтение (2 текста)', 'Окуу (2 текст)', 'Reading (2 texts)'), question_count: 10, options_per_question: 4, item_type: 'text_based', verified: true },
    ],
  }],
  scoring: {
    method: 'level', official_scale_known: false, level_cutoffs_known: false,
    levels: [
      { level: 1, title: t('Ниже среднего', 'Орточодон төмөн', 'Below average') },
      { level: 2, title: t('Средний', 'Орточо', 'Average') },
      { level: 3, title: t('Выше среднего', 'Орточодон жогору', 'Above average') },
      { level: 4, title: t('Высокий', 'Жогорку', 'High') },
    ],
    disclaimer: t(
      'Официальный результат выдаётся уровнем 1–4; границы уровней не опубликованы. Приложение показывает учебный процент. Тест обязателен для получения сертификата, но не влияет на конкурс.',
      'Расмий жыйынтык 1–4-деңгээл менен берилет; деңгээлдердин чектери жарыяланган эмес. Тиркеме окуу пайызын көрсөтөт. Тест сертификат алуу үчүн милдеттүү, бирок конкурска таасир этпейт.',
      'Officially reported as level 1–4 with unpublished cut-offs; the app shows a practice percentage.'),
  },
  rules: { calculators: false, scratchpad_sections: [], mandatory_for_certificate: true, affects_competition: false },
  source: SRC, effective_from: '2026-01-01', effective_to: null,
};

const all = [main, ...subjects, stateLanguage];
for (const b of all) for (const s of b.sections) {
  const sum = s.parts.reduce((a, p) => a + p.question_count, 0);
  if (sum !== s.question_count) throw new Error(`${b.id}/${s.id}: parts ${sum} != ${s.question_count}`);
}
fs.writeFileSync('assets/data/exam_blueprints.json', JSON.stringify({ schema_version: 1, generated_at: '2026-11-02', blueprints: all }, null, 2) + '\n');
console.log(all.map((b) => `${b.id}: ${b.sections.map((s) => `${s.id} ${s.question_count}/${s.duration_minutes}`).join(', ')}`).join('\n'));
