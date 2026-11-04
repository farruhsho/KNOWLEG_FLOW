import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/admin/data/models/admin_records.dart';
import 'package:knowledge_flow/features/admin/domain/blueprint_spec.dart';
import 'package:knowledge_flow/features/admin/domain/review_workflow.dart';
import 'package:knowledge_flow/features/admin/domain/variant_validation.dart';

/// Builds a complete, valid variant for [bp] in [language]: every part gets
/// exactly its quota of approved questions with keys and the right number of
/// options (fixed-option parts store no options; text parts get a passage).
({VariantDraft draft, Map<String, VariantQuestionInfo> infos}) buildValid(
  BlueprintSpec bp,
  String language,
) {
  final infos = <String, VariantQuestionInfo>{};
  final sections = <VariantSectionDraft>[];
  for (final s in bp.sections) {
    final ids = <String>[];
    for (final p in s.parts) {
      for (var i = 0; i < p.questionCount; i++) {
        final id = '${bp.id}_${s.id}_${p.id}_$i';
        ids.add(id);
        infos[id] = VariantQuestionInfo(
          id: id,
          sectionId: s.id,
          partId: s.parts.length > 1 ? p.id : null,
          language: language,
          type: p.itemType,
          optionCount: p.hasFixedOptions ? 0 : bp.optionsFor(p),
          reviewStatus: ReviewStatus.methodologistApproved,
          hasKey: true,
          passageId: p.needsPassage ? 'passage_${i ~/ 5}' : null,
        );
      }
    }
    sections.add(VariantSectionDraft(s.id, ids));
  }
  return (
    draft: VariantDraft(
      blueprintId: bp.id,
      blueprintVersion: bp.version,
      language: language,
      sections: sections,
    ),
    infos: infos,
  );
}

VariantInfoEdit edit(Map<String, VariantQuestionInfo> infos) => VariantInfoEdit(infos);

/// Small helper to replace one question's info.
class VariantInfoEdit {
  VariantInfoEdit(this.infos);
  final Map<String, VariantQuestionInfo> infos;

  void set(
    String id, {
    String? language,
    String? sectionId,
    ReviewStatus? review,
    bool? hasKey,
    int? optionCount,
    String? passageId,
    bool clearPassage = false,
    String? partId,
    bool clearPart = false,
  }) {
    final q = infos[id]!;
    infos[id] = VariantQuestionInfo(
      id: q.id,
      sectionId: sectionId ?? q.sectionId,
      partId: clearPart ? null : (partId ?? q.partId),
      language: language ?? q.language,
      type: q.type,
      optionCount: optionCount ?? q.optionCount,
      reviewStatus: review ?? q.reviewStatus,
      hasKey: hasKey ?? q.hasKey,
      passageId: clearPassage ? null : (passageId ?? q.passageId),
    );
  }
}

Set<String> codes(VariantValidationReport r) => r.errors.map((p) => p.code).toSet();

void main() {
  late List<BlueprintSpec> blueprints;
  BlueprintSpec bp(String id) => blueprints.firstWhere((b) => b.id == id);

  setUpAll(() {
    final raw = File('assets/data/exam_blueprints.json').readAsStringSync();
    blueprints = BlueprintSpec.listFromJson(jsonDecode(raw));
  });

  test('bundled blueprints parse with the official ORT 2026 structure', () {
    expect(blueprints.length, greaterThanOrEqualTo(10));
    final main = bp('ort_main_2026');
    expect(main.sections.map((s) => s.id), ['math', 'verbal', 'reading', 'grammar']);
    expect(main.totalQuestions, 150);
    final math = main.section('math')!;
    expect(math.questionCount, 60);
    expect(math.parts.map((p) => p.questionCount), [30, 30]);
    expect(math.part('math_comparison')!.hasFixedOptions, isTrue);
    expect(main.optionsFor(math.part('math_problems')), 5);
    expect(main.section('reading')!.parts.single.needsPassage, isTrue);
    expect(bp('ort_subject_english_2026').totalQuestions, 50);
    expect(bp('ort_subject_english_2026').languages, ['en']);
  });

  test('every blueprint accepts a complete variant built from it', () {
    for (final b in blueprints) {
      final language = b.languages.first;
      final v = buildValid(b, language);
      final r = validateVariant(blueprint: b, variant: v.draft, questions: v.infos);
      expect(r.errors, isEmpty, reason: '${b.id}: ${r.errors.toList()}');
      expect(r.canPublish, isTrue);
      for (final c in r.counts) {
        expect(c.ok, isTrue);
        for (final p in c.parts) {
          expect(p.ok, isTrue, reason: '${b.id}/${c.sectionId}/${p.partId}');
        }
      }
    }
  });

  group('ort_main_2026 errors block publishing', () {
    late BlueprintSpec main;
    late ({VariantDraft draft, Map<String, VariantQuestionInfo> infos}) v;
    setUp(() {
      main = bp('ort_main_2026');
      v = buildValid(main, 'ru');
    });

    VariantValidationReport run([VariantDraft? draft]) =>
        validateVariant(blueprint: main, variant: draft ?? v.draft, questions: v.infos);

    test('missing question in a section → section and part counts', () {
      final sections = [...v.draft.sections];
      final verbal = sections[1];
      sections[1] = VariantSectionDraft(verbal.sectionId, verbal.questionIds.sublist(1));
      final r = run(VariantDraft(
        blueprintId: main.id,
        blueprintVersion: main.version,
        language: 'ru',
        sections: sections,
      ));
      expect(r.canPublish, isFalse);
      expect(codes(r), containsAll([VariantProblemCode.sectionCount, VariantProblemCode.partCount]));
      final verbalCount = r.counts.firstWhere((c) => c.sectionId == 'verbal');
      expect(verbalCount.actual, 29);
      expect(verbalCount.parts.firstWhere((p) => p.partId == 'analogies').actual, 14);
    });

    test('part quota mismatch with the right total', () {
      // Move one completion question into the analogies part.
      final id = v.draft.sections[1].questionIds.last;
      edit(v.infos).set(id, partId: 'analogies');
      final r = run();
      expect(codes(r), {VariantProblemCode.partCount});
      expect(r.errors.where((p) => p.code == VariantProblemCode.partCount).length, 2);
    });

    test('not approved and missing key', () {
      final ids = v.draft.sections[0].questionIds;
      edit(v.infos)
        ..set(ids[0], review: ReviewStatus.aiVerified)
        ..set(ids[1], hasKey: false);
      final r = run();
      expect(codes(r), {VariantProblemCode.questionNotApproved, VariantProblemCode.questionNoKey});
      expect(r.errors.firstWhere((p) => p.code == VariantProblemCode.questionNotApproved).questionId, ids[0]);
    });

    test('wrong language and wrong section', () {
      final ids = v.draft.sections[3].questionIds;
      edit(v.infos)
        ..set(ids[0], language: 'ky')
        ..set(ids[1], sectionId: 'verbal');
      expect(codes(run()), {VariantProblemCode.questionLanguage, VariantProblemCode.questionSection});
    });

    test('option count must follow the part (5 for math problems)', () {
      final problems = v.draft.sections[0].questionIds.sublist(30);
      edit(v.infos).set(problems.first, optionCount: 4);
      final r = run();
      expect(codes(r), {VariantProblemCode.questionOptionCount});
      final p = r.errors.single;
      expect(p.expected, 5);
      expect(p.actual, 4);
    });

    test('fixed-option comparison questions may store 0 or 4 options', () {
      final comparison = v.draft.sections[0].questionIds.first;
      edit(v.infos).set(comparison, optionCount: 4);
      expect(run().canPublish, isTrue);
      edit(v.infos).set(comparison, optionCount: 3);
      expect(codes(run()), {VariantProblemCode.questionOptionCount});
    });

    test('reading questions need a passage', () {
      final reading = v.draft.sections[2].questionIds.first;
      edit(v.infos).set(reading, clearPassage: true);
      expect(codes(run()), {VariantProblemCode.questionNeedsPassage});
    });

    test('duplicates and unknown questions', () {
      final sections = [...v.draft.sections];
      final grammar = sections[3].questionIds;
      sections[3] = VariantSectionDraft('grammar', [...grammar.sublist(0, 29), grammar.first]);
      final r = run(VariantDraft(
        blueprintId: main.id,
        blueprintVersion: main.version,
        language: 'ru',
        sections: sections,
      ));
      expect(codes(r), {VariantProblemCode.questionDuplicate});

      sections[3] = VariantSectionDraft('grammar', [...grammar.sublist(0, 29), 'nope']);
      final r2 = run(VariantDraft(
        blueprintId: main.id,
        blueprintVersion: main.version,
        language: 'ru',
        sections: sections,
      ));
      expect(codes(r2), {VariantProblemCode.questionMissing});
    });

    test('section order, missing and unknown sections', () {
      final s = v.draft.sections;
      final swapped = VariantDraft(
        blueprintId: main.id,
        blueprintVersion: main.version,
        language: 'ru',
        sections: [s[1], s[0], s[2], s[3]],
      );
      expect(codes(run(swapped)), {VariantProblemCode.sectionOrder});

      final missing = VariantDraft(
        blueprintId: main.id,
        blueprintVersion: main.version,
        language: 'ru',
        sections: [s[0], s[1], s[2], const VariantSectionDraft('history', [])],
      );
      expect(codes(run(missing)),
          containsAll([VariantProblemCode.sectionMissing, VariantProblemCode.sectionUnknown]));
    });

    test('language must be allowed by the blueprint', () {
      final en = VariantDraft(
        blueprintId: main.id,
        blueprintVersion: main.version,
        language: 'en',
        sections: v.draft.sections,
      );
      expect(codes(run(en)), contains(VariantProblemCode.languageNotAllowed));
    });

    test('blueprint version mismatch blocks publishing, like the server (CP-09)', () {
      final old = VariantDraft(
        blueprintId: main.id,
        blueprintVersion: main.version + 1,
        language: 'ru',
        sections: v.draft.sections,
      );
      final r = run(old);
      expect(r.canPublish, isFalse);
      expect(r.errors.map((p) => p.code), [VariantProblemCode.blueprintVersion]);
      final p = r.errors.single;
      expect(p.expected, main.version);
      expect(p.actual, main.version + 1);
    });

    test('re-sync keeps every section and clears the version error (CP-09)', () {
      final doc = VariantDoc(
        id: 'v1',
        blueprintId: main.id,
        blueprintVersion: main.version - 1,
        number: 3,
        title: const {'ru': 'Вариант 3'},
        language: 'ru',
        sections: v.draft.sections,
      );
      expect(run(doc.toDraft()).canPublish, isFalse);
      final synced = doc.resyncedTo(main);
      expect(synced.blueprintVersion, main.version);
      expect(synced.sections, same(doc.sections));
      expect(synced.number, 3);
      expect(run(synced.toDraft()).canPublish, isTrue);
      // A different blueprint is never "re-synced" onto this variant.
      final other = bp('ort_state_language_2026');
      expect(doc.resyncedTo(other).blueprintVersion, doc.blueprintVersion);
    });

    test('a question without part_id is placed by its unique item type', () {
      final id = v.draft.sections[1].questionIds.first; // analogies
      edit(v.infos).set(id, clearPart: true);
      final r = run();
      // Type "analogy" maps to exactly one part, so the part is inferred.
      expect(r.canPublish, isTrue);
    });
  });

  test('state language test: kyrgyz only, 40 + 10 with passages', () {
    final b = bp('ort_state_language_2026');
    expect(b.languages, ['ky']);
    final v = buildValid(b, 'ky');
    expect(validateVariant(blueprint: b, variant: v.draft, questions: v.infos).canPublish, isTrue);
    final ru = buildValid(b, 'ru');
    final r = validateVariant(blueprint: b, variant: ru.draft, questions: ru.infos);
    expect(codes(r), contains(VariantProblemCode.languageNotAllowed));
  });

  test('locateSection and fixed options', () {
    final hit = locateSection(blueprints, 'chemistry', 'chemistry')!;
    expect(hit.blueprint.id, 'ort_subject_chemistry_2026');
    final mainMath = locateSection(blueprints, 'math', 'math')!;
    expect(mainMath.section.id, 'math');
    final part = bp('ort_main_2026').section('math')!.part('math_comparison')!;
    final ky = fixedOptionsFor(part, 'ky');
    expect(ky.map((o) => o.id), ['A', 'B', 'C', 'D']);
    expect(ky.every((o) => o.text.isNotEmpty), isTrue);
  });
}
