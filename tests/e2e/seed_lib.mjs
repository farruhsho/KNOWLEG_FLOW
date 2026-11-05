// Seeding for local development on the emulators (seed_dev.mjs). e2e.test.mjs
// keeps its own fixture with deterministic answer keys. Writes the real ORT 2026 blueprints plus structurally
// complete exam variants. Where the hand-written sample bank
// (content/bank/sample/items.json) has an original item for a part, it is used;
// the rest of each variant is clearly-labelled synthetic filler.
import { existsSync, readdirSync, readFileSync } from 'node:fs';
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
    // Demo filler of the library variants only: never part of the fresh-variant pool (seedPilotBank is).
    assembly_excluded: true,
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

/**
 * Web products (ARCHITECTURE §10.3): the base product 1 credit = 100 som is on
 * sale, the packs stay off until the owner approves their prices.
 */
export const WEB_PRODUCTS = {
  exam_single: { credits: 1, amount_som: 100, enabled: true },
  exam_pack_5: { credits: 5, amount_som: 450, enabled: false },
  exam_pack_10: { credits: 10, amount_som: 800, enabled: false },
};

export async function seedExamBase(db) {
  for (const bp of blueprints) await db.doc(`exam_blueprints/${bp.id}`).set(bp);
  await db.doc('config/pricing').set({
    free_exams_per_user: 1,
    products: { exam_single: { credits: 1 }, exam_pack_5: { credits: 5 }, exam_pack_10: { credits: 10 } },
    web_products: WEB_PRODUCTS,
  });
  // EMULATOR-ONLY pilot setting (§10.1): the pilot bank is `ai_verified`
  // (checked by an independent AI solver, not yet by a methodologist), so the
  // local fresh variants accept it. Production keeps the default
  // `methodologist_approved` until the owner decides otherwise
  // (adminUpdateExamPool, super_admin).
  await db.doc('config/exam_pool').set({
    fresh_enabled: true,
    min_review_status: 'ai_verified',
    note: 'emulator-only pilot setting (seed_dev.mjs): ai_verified items are not methodologist-approved',
    updated_by: 'seed',
  });
}

const tsOrNull = (iso) => (typeof iso === 'string' && iso ? new Date(iso) : null);

/** Same rules as the pipeline importer (tools/content_pipeline/src/importer.ts questionDoc). */
const isDedupExcluded = (it) => !!it.pipeline?.dedup && (it.pipeline.dedup.duplicate_of != null || String(it.pipeline.dedup.cluster_id ?? '').startsWith('ext:'));
const isAssemblyExcluded = (it) => it.pipeline?.translate_check?.status === 'failed';

/** Blueprint × language of the emulator fresh-variant pool (seedPilotBank). */
export const POOL_BLUEPRINT = 'ort_main_2026';
export const POOL_LANGUAGE = 'ru';

/**
 * Imports every committed bank for ort_main_2026 ru (content/bank/<batch>/items.json
 * except `sample`: the pilot set pilot_main_ru_v1_* and set 2 main_ru_v2_*, 150
 * original `ai_verified` items + 3 reading passages each) into exam_questions /
 * exam_question_keys / exam_passages in the shape the pipeline importer writes
 * (§1.3 incl. part_id, plus the fields the fresh-variant pool reads:
 * `blueprint_id`, `passage_order` (question order in its text),
 * `dedup_excluded`, `assembly_excluded`, and the passage `layout`).
 * With config/exam_pool.min_review_status = ai_verified the 300 items make two
 * disjoint fresh ort_main_2026 ru variants (later attempts honestly report repeats).
 */
export async function seedPilotBank(db) {
  const bankDir = path.join(root, 'content/bank');
  const dirs = readdirSync(bankDir).filter((d) => d !== 'sample' && existsSync(path.join(bankDir, d, 'items.json')));
  const ops = [];
  let items = 0;
  let passages = 0;
  for (const dir of dirs.sort()) {
    const file = JSON.parse(readFileSync(path.join(bankDir, dir, 'items.json'), 'utf8'));
    const chosen = (file.items ?? []).filter((it) => it.target?.blueprint_id === POOL_BLUEPRINT && it.question?.language === POOL_LANGUAGE && it.question.review?.status !== 'rejected');
    const usedPassages = new Set(chosen.map((it) => it.question.passage_id).filter(Boolean));
    for (const p of file.passages ?? []) {
      if (!usedPassages.has(p.id)) continue;
      const x = p.passage;
      ops.push([`exam_passages/${p.id}`, {
        language: x.language, subject_id: x.subject_id, section_id: x.section_id, layout: p.layout, title: x.title, text: x.text,
        source: { ...x.source }, content_hash: p.content_hash, pipeline_hash: p.content_hash,
      }]);
      passages++;
    }
    for (const it of chosen) {
      const q = it.question;
      ops.push([`exam_questions/${it.id}`, {
        subject_id: q.subject_id, section_id: q.section_id, part_id: it.target.part_id, blueprint_id: it.target.blueprint_id,
        passage_order: it.passage_order ?? null, dedup_excluded: isDedupExcluded(it), assembly_excluded: isAssemblyExcluded(it),
        topic_id: q.topic_id, subtopic_id: q.subtopic_id ?? null, difficulty: q.difficulty, language: q.language,
        translation_group_id: q.translation_group_id ?? null, pipeline_translation_group_id: q.translation_group_id ?? null, type: q.type, stem: q.stem,
        options: (q.options ?? []).map((o) => ({ id: o.id, text: o.text })),
        passage_id: q.passage_id ?? null, image_path: q.image_path ?? null,
        table: storedTable(q.table), source: { ...q.source },
        review: { status: q.review.status, reviewed_by: q.review.reviewed_by ?? null, reviewed_at: tsOrNull(q.review.reviewed_at), notes: q.review.notes ?? '' },
        content_version: q.content_version ?? 1, content_hash: q.content_hash, pipeline_hash: q.content_hash,
        created_at: tsOrNull(q.created_at), updated_at: tsOrNull(q.updated_at),
      }]);
      ops.push([`exam_question_keys/${it.id}`, {
        correct: it.key.correct, explanation: it.key.explanation ?? '', wrong_option_notes: it.key.wrong_option_notes ?? {},
        solution_steps: it.key.solution_steps ?? [],
      }]);
      items++;
    }
  }
  for (let i = 0; i < ops.length; i += 400) {
    const batch = db.batch();
    for (const [p, data] of ops.slice(i, i + 400)) batch.set(db.doc(p), data);
    await batch.commit();
  }
  return { items, passages };
}

/**
 * Phase 3 (ARCHITECTURE §9) demo data: an active promo code `DEMO2026`
 * (2 credits, up to 1000 redemptions, no expiry) for trying promoRedeem in
 * the app. Re-running keeps the redemption counter.
 */
export async function seedGrowth(db) {
  const ref = db.doc('promo_codes/DEMO2026');
  const snap = await ref.get();
  await ref.set({
    credits: 2, max_redemptions: 1000, expires_at: null, active: true, note: 'emulator demo code',
    ...(snap.exists ? {} : { redemptions: 0, created_by: 'seed', created_at: new Date('2026-11-05T00:00:00Z') }),
  }, { merge: true });
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
