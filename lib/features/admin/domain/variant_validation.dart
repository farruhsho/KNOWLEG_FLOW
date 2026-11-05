/// Client-side preview of the rules `adminPublishVariant` enforces
/// (ARCHITECTURE.md §1.2–1.3): the variant must match its blueprint section by
/// section and part by part, use one language, contain no duplicates, and every
/// question must be `methodologist_approved` with a key. The server stays the
/// source of truth — this only lets editors see problems before publishing.
library;

import 'blueprint_spec.dart';
import 'review_workflow.dart';

enum ProblemSeverity { error, warning }

/// Stable problem codes (mapped to localized messages in the UI and kept in
/// sync with the backend's `problems[]` wording where possible).
abstract final class VariantProblemCode {
  static const blueprintVersion = 'blueprint_version_mismatch';
  static const languageNotAllowed = 'language_not_allowed';
  static const sectionMissing = 'section_missing';
  static const sectionUnknown = 'section_unknown';
  static const sectionOrder = 'section_order';
  static const sectionCount = 'section_count';
  static const partCount = 'part_count';
  static const partUnknown = 'part_unknown';
  static const questionMissing = 'question_missing';
  static const questionDuplicate = 'question_duplicate';
  static const questionLanguage = 'question_wrong_language';
  static const questionSection = 'question_wrong_section';
  static const questionPart = 'question_wrong_part';
  static const questionNotApproved = 'question_not_approved';
  static const questionNoKey = 'question_no_key';
  static const questionOptionCount = 'question_option_count';
  static const questionNeedsPassage = 'question_needs_passage';
}

class VariantProblem {
  final String code;
  final ProblemSeverity severity;
  final String? sectionId;
  final String? partId;
  final String? questionId;
  final int? expected;
  final int? actual;

  const VariantProblem(
    this.code, {
    this.severity = ProblemSeverity.error,
    this.sectionId,
    this.partId,
    this.questionId,
    this.expected,
    this.actual,
  });

  bool get isError => severity == ProblemSeverity.error;

  @override
  String toString() =>
      'VariantProblem($code, section=$sectionId, part=$partId, q=$questionId, '
      'expected=$expected, actual=$actual, ${severity.name})';
}

/// What the validator needs to know about one referenced exam question.
class VariantQuestionInfo {
  final String id;
  final String sectionId;
  final String? partId;
  final String language;
  final String type;
  final int optionCount;
  final ReviewStatus reviewStatus;
  final bool hasKey;
  final String? passageId;

  const VariantQuestionInfo({
    required this.id,
    required this.sectionId,
    required this.language,
    required this.type,
    required this.optionCount,
    required this.reviewStatus,
    required this.hasKey,
    this.partId,
    this.passageId,
  });
}

class VariantSectionDraft {
  final String sectionId;
  final List<String> questionIds;
  const VariantSectionDraft(this.sectionId, this.questionIds);
}

class VariantDraft {
  final String blueprintId;
  final int blueprintVersion;
  final String language;
  final List<VariantSectionDraft> sections;

  const VariantDraft({
    required this.blueprintId,
    required this.blueprintVersion,
    required this.language,
    required this.sections,
  });
}

class PartCount {
  final String partId;
  final int expected;
  final int actual;
  const PartCount(this.partId, this.expected, this.actual);
  bool get ok => expected == actual;
}

class SectionCount {
  final String sectionId;
  final int expected;
  final int actual;
  final List<PartCount> parts;

  /// Questions whose part could not be determined.
  final int unknownPart;

  const SectionCount({
    required this.sectionId,
    required this.expected,
    required this.actual,
    required this.parts,
    required this.unknownPart,
  });
  bool get ok => expected == actual;
}

class VariantValidationReport {
  final List<VariantProblem> problems;
  final List<SectionCount> counts;

  const VariantValidationReport(this.problems, this.counts);

  Iterable<VariantProblem> get errors => problems.where((p) => p.isError);
  Iterable<VariantProblem> get warnings => problems.where((p) => !p.isError);

  /// Publishing is blocked while any error remains.
  bool get canPublish => errors.isEmpty;
}

/// Determines which blueprint part a question belongs to: its explicit
/// `part_id`, the only part of the section, or the only part whose
/// `item_type` matches the question type. Returns `null` when ambiguous.
PartSpec? inferPart(SectionSpec section, VariantQuestionInfo q) {
  if (q.partId != null && q.partId!.isNotEmpty) return section.part(q.partId);
  if (section.parts.length == 1) return section.parts.first;
  final byType = section.parts.where((p) => p.itemType == q.type).toList();
  return byType.length == 1 ? byType.first : null;
}

VariantValidationReport validateVariant({
  required BlueprintSpec blueprint,
  required VariantDraft variant,
  required Map<String, VariantQuestionInfo> questions,
}) {
  final problems = <VariantProblem>[];
  final counts = <SectionCount>[];

  // An error, as on the server: adminPublishVariant rejects a variant built
  // for another blueprint version (CP-09). The builder offers a re-sync that
  // keeps the sections.
  if (variant.blueprintVersion != blueprint.version) {
    problems.add(VariantProblem(
      VariantProblemCode.blueprintVersion,
      expected: blueprint.version,
      actual: variant.blueprintVersion,
    ));
  }
  if (!blueprint.languages.contains(variant.language)) {
    problems.add(const VariantProblem(VariantProblemCode.languageNotAllowed));
  }

  // Section presence and order.
  final variantSectionIds = variant.sections.map((s) => s.sectionId).toList();
  for (final id in variantSectionIds) {
    if (blueprint.section(id) == null) {
      problems.add(VariantProblem(VariantProblemCode.sectionUnknown, sectionId: id));
    }
  }
  final known = variantSectionIds.where((id) => blueprint.section(id) != null).toList();
  final expectedOrder = blueprint.sections.map((s) => s.id).where(known.contains).toList();
  var orderOk = known.length == expectedOrder.length;
  for (var i = 0; orderOk && i < known.length; i++) {
    if (known[i] != expectedOrder[i]) orderOk = false;
  }
  if (!orderOk) {
    problems.add(const VariantProblem(VariantProblemCode.sectionOrder));
  }

  final seen = <String>{};
  for (final section in blueprint.sections) {
    final drafts = variant.sections.where((s) => s.sectionId == section.id).toList();
    if (drafts.isEmpty) {
      problems.add(VariantProblem(
        VariantProblemCode.sectionMissing,
        sectionId: section.id,
        expected: section.questionCount,
        actual: 0,
      ));
      counts.add(SectionCount(
        sectionId: section.id,
        expected: section.questionCount,
        actual: 0,
        parts: [for (final p in section.parts) PartCount(p.id, p.questionCount, 0)],
        unknownPart: 0,
      ));
      continue;
    }
    final ids = [for (final d in drafts) ...d.questionIds];
    if (ids.length != section.questionCount) {
      problems.add(VariantProblem(
        VariantProblemCode.sectionCount,
        sectionId: section.id,
        expected: section.questionCount,
        actual: ids.length,
      ));
    }

    final partActual = {for (final p in section.parts) p.id: 0};
    var unknownPart = 0;
    for (final qid in ids) {
      if (!seen.add(qid)) {
        problems.add(VariantProblem(
          VariantProblemCode.questionDuplicate,
          sectionId: section.id,
          questionId: qid,
        ));
      }
      final q = questions[qid];
      if (q == null) {
        problems.add(VariantProblem(
          VariantProblemCode.questionMissing,
          sectionId: section.id,
          questionId: qid,
        ));
        unknownPart++;
        continue;
      }
      if (q.language != variant.language) {
        problems.add(VariantProblem(VariantProblemCode.questionLanguage,
            sectionId: section.id, questionId: qid));
      }
      if (q.sectionId != section.id) {
        problems.add(VariantProblem(VariantProblemCode.questionSection,
            sectionId: section.id, questionId: qid));
      }
      if (q.reviewStatus != ReviewStatus.methodologistApproved) {
        problems.add(VariantProblem(VariantProblemCode.questionNotApproved,
            sectionId: section.id, questionId: qid));
      }
      if (!q.hasKey) {
        problems.add(VariantProblem(VariantProblemCode.questionNoKey,
            sectionId: section.id, questionId: qid));
      }

      final explicitPart = q.partId != null && q.partId!.isNotEmpty;
      final part = inferPart(section, q);
      if (explicitPart && part == null) {
        problems.add(VariantProblem(VariantProblemCode.questionPart,
            sectionId: section.id, partId: q.partId, questionId: qid));
        unknownPart++;
        continue;
      }
      if (part == null) {
        problems.add(VariantProblem(
          VariantProblemCode.partUnknown,
          severity: ProblemSeverity.warning,
          sectionId: section.id,
          questionId: qid,
        ));
        unknownPart++;
        continue;
      }
      partActual[part.id] = (partActual[part.id] ?? 0) + 1;

      final expectedOptions = blueprint.optionsFor(part);
      final fixedOk = part.hasFixedOptions && q.optionCount == 0;
      if (!fixedOk && q.optionCount != expectedOptions) {
        problems.add(VariantProblem(
          VariantProblemCode.questionOptionCount,
          sectionId: section.id,
          partId: part.id,
          questionId: qid,
          expected: expectedOptions,
          actual: q.optionCount,
        ));
      }
      if (part.needsPassage && (q.passageId == null || q.passageId!.isEmpty)) {
        problems.add(VariantProblem(VariantProblemCode.questionNeedsPassage,
            sectionId: section.id, partId: part.id, questionId: qid));
      }
    }

    // Part counts are exact once every question's part is known; with unknown
    // parts we can still flag parts that are already over the limit.
    for (final p in section.parts) {
      final actual = partActual[p.id] ?? 0;
      final mismatch = unknownPart == 0
          ? actual != p.questionCount
          : actual > p.questionCount;
      if (section.parts.length > 1 && mismatch) {
        problems.add(VariantProblem(
          VariantProblemCode.partCount,
          sectionId: section.id,
          partId: p.id,
          expected: p.questionCount,
          actual: actual,
        ));
      }
    }

    counts.add(SectionCount(
      sectionId: section.id,
      expected: section.questionCount,
      actual: ids.length,
      parts: [
        for (final p in section.parts)
          PartCount(p.id, p.questionCount, partActual[p.id] ?? 0),
      ],
      unknownPart: unknownPart,
    ));
  }

  return VariantValidationReport(problems, counts);
}
