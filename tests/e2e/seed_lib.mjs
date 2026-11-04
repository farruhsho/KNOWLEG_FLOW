// Seeding for local development on the emulators (seed_dev.mjs). e2e.test.mjs
// keeps its own fixture with deterministic answer keys. Writes the real ORT 2026 blueprints plus structurally
// complete exam variants. Where the hand-written sample bank
// (content/bank/sample/items.json) has an original item for a part, it is used;
// the rest of each variant is clearly-labelled synthetic filler.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '../..');
export const blueprints = JSON.parse(readFileSync(path.join(root, 'assets/data/exam_blueprints.json'), 'utf8')).blueprints;
const sample = JSON.parse(readFileSync(path.join(root, 'content/bank/sample/items.json'), 'utf8'));

/** Firestore cannot store nested arrays: rows are stored as {cells} (decision D2). */
const storedTable = (t) => (t ? { headers: t.headers ?? [], rows: (t.rows ?? []).map((r) => ({ cells: r })) } : null);

function sampleFor(partId, lang) {
  return sample.items.filter((i) => i.target.part_id === partId && i.question.language === lang);
}

function writeQuestion(batch, db, id, q, key) {
  batch.set(db.doc(`exam_questions/${id}`), {
    ...q, table: storedTable(q.table), review: { status: 'methodologist_approved' }, content_version: 1,
  });
  batch.set(db.doc(`exam_question_keys/${id}`), {
    correct: key.correct, explanation: key.explanation ?? '', wrong_option_notes: key.wrong_option_notes ?? {}, solution_steps: key.solution_steps ?? [],
  });
}

function seedSection(db, batch, bp, section, lang, prefix) {
  const ids = [];
  let n = 0;
  for (const part of section.parts) {
    const real = sampleFor(part.id, lang);
    for (let i = 0; i < part.question_count; i++) {
      n++;
      const id = `${prefix}_${section.id}_${n}`;
      const r = real[i];
      if (r) {
        writeQuestion(batch, db, id, { ...r.question, part_id: part.id, passage_id: null }, r.key);
        ids.push(id);
        continue;
      }
      const isQc = part.item_type === 'quantitative_comparison';
      const passageId = part.item_type === 'text_based' ? `${prefix}_${section.id}_p${Math.floor(i / 10)}` : null;
      const a = 2 + (n % 7);
      const b = 3 + (n % 5);
      writeQuestion(batch, db, id, {
        subject_id: bp.subject_id ?? section.subject_area, section_id: section.id, part_id: part.id,
        topic_id: `${section.subject_area}.practice`, difficulty: 1 + (i % 3), language: lang,
        type: isQc ? 'quantitative_comparison' : part.item_type,
        stem: isQc ? (lang === 'ky' ? 'Чоңдуктарды салыштырыңыз.' : 'Сравните величины в колонках А и Б.')
                   : `[Демо ${n}] ${lang === 'ky' ? 'Эсептеңиз' : 'Вычислите'}: $${a} \\cdot ${b}$`,
        options: isQc ? part.fixed_options.map((o) => ({ id: o.id, text: o.text[lang] ?? o.text.ru }))
                      : Array.from({ length: part.options_per_question }, (_, k) => ({ id: String.fromCharCode(65 + k), text: String(a * b + k * (k % 2 ? 1 : -1) * (k + 1)) })),
        column_a: isQc ? `$${a}^2$` : null, column_b: isQc ? `$${a * b}$` : null,
        table: isQc ? { headers: ['А', 'Б'], rows: [[`$${a}^2$`, `$${a * b}$`]] } : null,
        passage_id: passageId, image_path: null,
        source: { kind: 'original', basis: 'demo filler for local testing' },
      }, {
        correct: isQc ? (a * a > a * b ? 'A' : a * a < a * b ? 'B' : 'C') : 'A',
        explanation: isQc ? `$${a}^2 = ${a * a}$, $${a * b}$.` : `$${a} \\cdot ${b} = ${a * b}$.`,
      });
      if (passageId) {
        batch.set(db.doc(`exam_passages/${passageId}`), {
          language: lang, title: lang === 'ky' ? 'Текст' : 'Текст',
          text: Array.from({ length: 12 }, (_, l) => `${lang === 'ky' ? 'Сап' : 'Строка'} ${l + 1}: демонстрационный текст для проверки режима чтения.`).join('\n'),
        });
      }
      ids.push(id);
    }
  }
  return ids;
}

export async function seedVariant(db, bp, variantId, lang, number = 1) {
  const sections = [];
  for (const section of bp.sections) {
    const batch = db.batch();
    sections.push({ section_id: section.id, question_ids: seedSection(db, batch, bp, section, lang, variantId) });
    await batch.commit();
  }
  await db.doc(`exam_variants/${variantId}`).set({
    blueprint_id: bp.id, blueprint_version: bp.version, number,
    title: { ru: `Вариант ${number}`, ky: `${number}-вариант` },
    language: lang, status: 'published', sections, content_version: 1, created_by: 'seed',
  });
  return sections;
}

export async function seedExamBase(db) {
  for (const bp of blueprints) await db.doc(`exam_blueprints/${bp.id}`).set(bp);
  await db.doc('config/pricing').set({
    free_exams_per_user: 1,
    products: { exam_single: { credits: 1 }, exam_pack_5: { credits: 5 }, exam_pack_10: { credits: 10 } },
  });
}

/** Legacy learning collections (subjects, lessons, practice questions) for the Learn tab. */
export async function seedLearning(db) {
  const seed = JSON.parse(readFileSync(path.join(root, 'firebase_seed_data.json'), 'utf8'));
  const batch = db.batch();
  for (const s of seed.subjects ?? []) batch.set(db.doc(`subjects/${s.id}`), { ...s, is_active: true });
  batch.set(db.doc('lessons/math_quadratic_1'), {
    id: 'math_quadratic_1', subjectId: 'math', subject_id: 'math', order: 1, estimatedTimeMinutes: 15,
    title: { ru: 'Квадратные уравнения и теорема Виета', ky: 'Квадраттык теңдемелер жана Виет теоремасы' },
    summary: { ru: 'Как быстро находить сумму и произведение корней.', ky: 'Тамырлардын суммасын жана көбөйтүндүсүн тез табуу.' },
    content: { ru: 'Для $x^2 + px + q = 0$: $x_1 + x_2 = -p$, $x_1 x_2 = q$.', ky: '$x^2 + px + q = 0$ үчүн: $x_1 + x_2 = -p$, $x_1 x_2 = q$.' },
    sections: [{ title: { ru: 'Теорема Виета', ky: 'Виет теоремасы' }, body: { ru: 'Сумма корней приведённого уравнения равна $-p$, произведение — $q$.', ky: 'Келтирилген теңдеменин тамырларынын суммасы $-p$, көбөйтүндүсү $q$.' } }],
    formulas: [{ latex: 'x_1 + x_2 = -p', caption: { ru: 'Сумма корней', ky: 'Тамырлардын суммасы' } }],
    examples: [{ problem: { ru: 'Найдите сумму корней $x^2 - 7x + 10 = 0$.', ky: '$x^2 - 7x + 10 = 0$ тамырларынын суммасын табыңыз.' }, solution: { ru: '$-(-7) = 7$', ky: '$-(-7) = 7$' } }],
    common_mistakes: [{ ru: 'Забывают знак: сумма равна $-p$, а не $p$.', ky: 'Белгини унутушат: сумма $-p$ га барабар.' }],
    createdBy: 'seed', createdAt: '2026-11-04T00:00:00.000Z', is_active: true,
  });
  const ruItems = sample.items.filter((i) => i.question.language === 'ru' && i.question.type !== 'quantitative_comparison');
  ruItems.forEach((it, k) => {
    const q = it.question;
    batch.set(db.doc(`questions/practice_${k + 1}`), {
      subject_id: 'math', section_id: q.section_id, topic_id: q.topic_id, type: 'single_choice', difficulty: q.difficulty,
      stem: { ru: q.stem }, options: q.options.map((o) => ({ id: o.id, text: { ru: o.text } })),
      correct_answer: it.key.correct, explanation: { ru: it.key.explanation ?? '' },
      is_active: true, is_verified: true, category: 'main', points: 1, tags: [],
      created_at: new Date('2026-11-04T00:00:00Z'), updated_at: new Date('2026-11-04T00:00:00Z'), created_by: 'seed',
    });
  });
  await batch.commit();
}
