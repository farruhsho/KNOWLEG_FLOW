import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { questionContentHash, questionIdFromHash } from '../src/bank';
import { dedupRecords, docFromItem, externalDocsFrom, isDedupExcluded, runDedup, similarPairs } from '../src/dedup';
import { BankItem } from '../src/schema';
import { jaccard, normalizeText, shingles } from '../src/text';
import { realBlueprint, realMatrix, synthItem } from './fixtures';
import { languageMatrix } from '../src/matrix';

const bp = realBlueprint('ort_main_2026');
const lmKy = languageMatrix(realMatrix('ort_main_2026'), 'ky');
const lmRu = languageMatrix(realMatrix('ort_main_2026'), 'ru');
let serial = 0;

/** A completion item with the given stem/options (hash and id recomputed). */
function item(language: 'ru' | 'ky', stem: string, options: string[], tg: string | null = null): BankItem {
  const lm = language === 'ky' ? lmKy : lmRu;
  const section = lm.sections.find((s) => s.section_id === 'verbal')!;
  const part = section.parts.find((p) => p.part_id === 'completion')!;
  const base = synthItem({ bp, section, part, language, topicId: 'completion.vocabulary_in_context', difficulty: 2, serial: `d${serial}`, status: 'draft', keyIndex: serial++ });
  const q = { ...base.question, stem, options: options.map((text, i) => ({ id: (['A', 'B', 'C', 'D'] as const)[i]!, text })) };
  q.content_hash = questionContentHash(q);
  if (tg) q.translation_group_id = tg;
  return { ...base, id: questionIdFromHash(q.content_hash), question: q };
}

describe('text normalisation keeps Cyrillic, including Kyrgyz ң ө ү', () => {
  it('does not fold ң ө ү into н о у', () => {
    assert.equal(normalizeText('Төрт'), 'төрт');
    assert.notEqual(normalizeText('төрт'), normalizeText('торт'));
    assert.notEqual(normalizeText('үй'), normalizeText('уй'));
    assert.notEqual(normalizeText('көң'), normalizeText('кон'));
  });

  it('unifies look-alike code points and Latin homoglyphs inside Cyrillic words', () => {
    assert.equal(normalizeText('ӊ ӧ ӱ'), 'ң ө ү');
    assert.equal(normalizeText('мaтематика'), normalizeText('математика')); // Latin "a"
    assert.equal(normalizeText('ЁЛКА'), 'елка');
    assert.equal(normalizeText('area'), 'area', 'pure Latin words are untouched');
  });

  it('keeps maths and strips markup', () => {
    assert.equal(normalizeText('Найдите $x^2 - 5x + 6 = 0$!'), 'найдите x^2 - 5x + 6 = 0');
    assert.equal(normalizeText('$2{,}5 \\cdot 4$'), '2,5 * 4');
  });

  it('shingle Jaccard is 1 for equal texts and low for unrelated ones', () => {
    const a = shingles(normalizeText('Тоолордо кар эрте түштү.'));
    const b = shingles(normalizeText('ТООЛОРДО  кар  эрте түштү.'));
    const c = shingles(normalizeText('Шаарда жамгыр жаады.'));
    assert.equal(jaccard(a, b), 1);
    assert.ok(jaccard(a, c) < 0.2);
  });
});

describe('dedup', () => {
  const stemKy = 'Мугалим сабакты ушунчалык ____ түшүндүрдү, окуучулардын баары татаал терминдерди дароо түшүнүштү.';
  const optsKy = ['түшүнүктүү', 'чаташтырып', 'шашып', 'салтанаттуу'];
  const a = item('ky', stemKy, optsKy);
  const exact = item('ky', `  ${stemKy.toUpperCase()} `, [...optsKy].reverse()); // same text, other case/order
  const near = item('ky', stemKy.replace('дароо', 'ошол замат'), optsKy);
  const otherLetter = item('ky', stemKy.replace('түшүндүрдү', 'тушундурду'), optsKy); // ү → у: still near, not exact
  const unrelated = item('ky', 'Китеп ____ болгондуктан, аны бир күндө окуп бүттүм.', ['кызыктуу', 'оор', 'эски', 'кымбат']);
  const ruTwin = item('ru', 'Учитель объяснял урок так ____, что все ученики сразу поняли сложные термины.', ['понятно', 'сбивчиво', 'поспешно', 'торжественно']);

  it('finds exact and near duplicates within a language, never across languages', () => {
    const pairs = similarPairs([a, exact, near, otherLetter, unrelated, ruTwin].map(docFromItem), 0.7);
    const has = (x: BankItem, y: BankItem): boolean => pairs.some((p) => (p.a === x.id && p.b === y.id) || (p.a === y.id && p.b === x.id));
    assert.ok(has(a, exact));
    assert.equal(pairs.find((p) => (p.a === a.id || p.b === a.id) && (p.a === exact.id || p.b === exact.id))!.exact, true);
    assert.ok(has(a, near));
    assert.ok(has(a, otherLetter));
    assert.equal(pairs.find((p) => [p.a, p.b].includes(otherLetter.id) && [p.a, p.b].includes(a.id))!.exact, false, 'ү and у are different letters');
    assert.ok(!has(a, unrelated));
    assert.ok(!pairs.some((p) => p.a === ruTwin.id || p.b === ruTwin.id));
  });

  it('does not compare the language versions of one translation group', () => {
    const x = item('ky', stemKy, optsKy, 'tg_same');
    const y = item('ky', stemKy + ' ', optsKy, 'tg_same');
    // Same language but same group (e.g. a re-translation draft) is skipped as well.
    assert.equal(similarPairs([x, y].map(docFromItem), 0.5).length, 0);
  });

  it('clusters duplicates, keeps the most-reviewed member canonical and excludes the rest', () => {
    const approved = { ...near, question: { ...near.question, review: { ...near.question.review, status: 'methodologist_approved' as const } } };
    const report = runDedup([a, exact, approved, unrelated], [], 0.7);
    assert.equal(report.clusters.length, 1);
    const c = report.clusters[0]!;
    assert.equal(c.canonical, approved.id);
    assert.equal(c.members.length, 3);
    const recs = dedupRecords(report, '2026-11-02T00:00:00.000Z');
    assert.equal(recs.get(approved.id)!.duplicate_of, null);
    assert.equal(recs.get(a.id)!.duplicate_of, approved.id);
    assert.equal(recs.has(unrelated.id), false);
    assert.equal(isDedupExcluded({ ...a, pipeline: { ...a.pipeline, dedup: recs.get(a.id)! } }), true);
    assert.equal(isDedupExcluded({ ...approved, pipeline: { ...approved.pipeline, dedup: recs.get(approved.id)! } }), false);
  });

  it('matches existing content, including legacy multilingual `questions` documents', () => {
    const legacy = {
      questions: [
        {
          id: 'legacy_1',
          stem: { ru: 'Учитель объяснял урок так ____, что все ученики сразу поняли сложные термины.', ky: 'Башка суроо' },
          options: [{ text: { ru: 'понятно', ky: 'а' } }, { text: { ru: 'сбивчиво', ky: 'б' } }, { text: { ru: 'поспешно', ky: 'в' } }, { text: { ru: 'торжественно', ky: 'г' } }],
        },
      ],
    };
    const ext = externalDocsFrom(legacy, 'legacy.json');
    assert.equal(ext.length, 2);
    const report = runDedup([ruTwin, a], [], 0.85, ext);
    assert.deepEqual(report.external_matches.map((m) => [m.id, m.external_ref]), [[ruTwin.id, 'legacy.json#legacy_1:ru']]);
    const recs = dedupRecords(report, '2026-11-02T00:00:00.000Z');
    assert.equal(isDedupExcluded({ ...ruTwin, pipeline: { ...ruTwin.pipeline, dedup: recs.get(ruTwin.id)! } }), true);
  });

  it('scales with MinHash LSH for large groups and still finds the planted duplicate', () => {
    const many: BankItem[] = [];
    for (let i = 0; i < 1600; i++) many.push(item('ky', `Сүйлөм номери ${i}: ${'абвгдеёжзийклмнңоөпрстуүфхцчшщ'[i % 31]} ${i * 7919} ____ ${i % 13}.`, [`а${i}`, `б${i}`, `в${i}`, `г${i}`]));
    // Same text up to spacing: a different content hash (and id), identical normalised text.
    const planted = item('ky', many[42]!.question.stem + '  ', many[42]!.question.options.map((o) => o.text));
    assert.notEqual(planted.id, many[42]!.id);
    many.push(planted);
    const report = runDedup(many, [], 0.9);
    const cluster = report.clusters.find((c) => c.members.some((m) => m.id === many[42]!.id));
    assert.ok(cluster);
    assert.ok(cluster.members.some((m) => m.id === planted.id));
    assert.equal(cluster.kind, 'exact');
  });
});
