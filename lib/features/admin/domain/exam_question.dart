/// Exam bank documents — ARCHITECTURE.md §1.3:
/// `exam_questions/{id}` (one language per document, translations linked by
/// `translation_group_id`), `exam_question_keys/{id}` (correct option and
/// explanations, never readable by students) and `exam_passages/{id}`.
///
/// Pure Dart: Firestore timestamps are added by the repository.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'review_workflow.dart';

const List<String> kExamLanguages = ['ru', 'ky', 'en'];
const List<String> kExamOptionIds = ['A', 'B', 'C', 'D', 'E'];

String _str(Object? v) => v == null ? '' : v.toString();
String? _strOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

T? _pick<T>(Map raw, List<String> keys) {
  for (final k in keys) {
    final v = raw[k];
    if (v is T) return v;
  }
  return null;
}

String _lang(Object? v) {
  final s = _str(v).trim().toLowerCase();
  return s == 'kg' ? 'ky' : s;
}

/// Tolerant date reader: DateTime, ISO string, epoch millis or a Firestore
/// `Timestamp` (anything with `toDate()`).
DateTime? readDateTolerant(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  try {
    final d = (v as dynamic).toDate();
    if (d is DateTime) return d;
  } catch (_) {}
  return null;
}

class ExamOption {
  final String id;
  final String text;
  const ExamOption(this.id, this.text);

  Map<String, dynamic> toMap() => {'id': id, 'text': text};

  static List<ExamOption> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <ExamOption>[];
    for (var i = 0; i < raw.length; i++) {
      final o = raw[i];
      final fallback = i < kExamOptionIds.length ? kExamOptionIds[i] : '$i';
      if (o is Map) {
        final text = o['text'];
        out.add(ExamOption(
          _str(o['id'] ?? fallback).trim().toUpperCase(),
          text is Map ? _str(text.values.isEmpty ? '' : text.values.first) : _str(text),
        ));
      } else if (o != null) {
        out.add(ExamOption(fallback, o.toString()));
      }
    }
    return out;
  }
}

class ExamReview {
  final ReviewStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String notes;

  const ExamReview({
    this.status = ReviewStatus.draft,
    this.reviewedBy,
    this.reviewedAt,
    this.notes = '',
  });

  factory ExamReview.fromMap(Object? raw) {
    if (raw is! Map) return const ExamReview();
    return ExamReview(
      status: ReviewStatus.parse(raw['status']),
      reviewedBy: _strOrNull(raw['reviewed_by']),
      reviewedAt: readDateTolerant(raw['reviewed_at']),
      notes: _str(raw['notes']),
    );
  }
}

/// Source metadata (`source.kind`: original | adapted | ai).
class ExamSource {
  final String kind;
  final String basis;
  final String author;
  const ExamSource({this.kind = 'original', this.basis = '', this.author = ''});

  factory ExamSource.fromMap(Object? raw) {
    if (raw is! Map) return const ExamSource();
    return ExamSource(
      kind: _strOrNull(raw['kind']) ?? 'original',
      basis: _str(raw['basis']),
      author: _str(raw['author']),
    );
  }

  Map<String, dynamic> toMap() => {'kind': kind, 'basis': basis, 'author': author};
}

class ExamQuestionDoc {
  final String id;
  final String subjectId;
  final String sectionId;

  /// Blueprint part (additive field, not in §1.3 — lets the variant builder
  /// count part quotas exactly). `null` for single-part sections.
  final String? partId;
  final String topicId;
  final String? subtopicId;
  final int difficulty;
  final String language;
  final String? translationGroupId;
  final String type;
  final String stem;
  final List<ExamOption> options;
  final String? passageId;
  final String? imagePath;
  final Map<String, dynamic>? table;
  final ExamSource source;
  final ExamReview review;
  final int contentVersion;
  final String? contentHash;
  final DateTime? updatedAt;

  const ExamQuestionDoc({
    required this.id,
    required this.subjectId,
    required this.sectionId,
    this.partId,
    required this.topicId,
    this.subtopicId,
    this.difficulty = 2,
    required this.language,
    this.translationGroupId,
    this.type = 'single_choice',
    required this.stem,
    required this.options,
    this.passageId,
    this.imagePath,
    this.table,
    this.source = const ExamSource(),
    this.review = const ExamReview(),
    this.contentVersion = 1,
    this.contentHash,
    this.updatedAt,
  });

  factory ExamQuestionDoc.fromMap(String id, Map raw) {
    final stem = raw['stem'];
    return ExamQuestionDoc(
      id: id,
      subjectId: _str(_pick<String>(raw, ['subject_id', 'subjectId'])).trim(),
      sectionId: _str(_pick<String>(raw, ['section_id', 'sectionId'])).trim(),
      partId: _strOrNull(_pick<String>(raw, ['part_id', 'partId'])),
      topicId: _str(_pick<String>(raw, ['topic_id', 'topicId'])).trim(),
      subtopicId: _strOrNull(_pick<String>(raw, ['subtopic_id', 'subtopicId'])),
      difficulty: _int(raw['difficulty'], 2),
      language: _lang(raw['language']),
      translationGroupId:
          _strOrNull(_pick<String>(raw, ['translation_group_id', 'translationGroupId'])),
      type: _strOrNull(raw['type']) ?? 'single_choice',
      stem: stem is Map ? _str(stem.values.isEmpty ? '' : stem.values.first) : _str(stem),
      options: ExamOption.listFrom(raw['options']),
      passageId: _strOrNull(_pick<String>(raw, ['passage_id', 'passageId'])),
      imagePath: _strOrNull(_pick<String>(raw, ['image_path', 'imagePath'])),
      table: raw['table'] is Map ? Map<String, dynamic>.from(raw['table'] as Map) : null,
      source: ExamSource.fromMap(raw['source']),
      review: ExamReview.fromMap(raw['review']),
      contentVersion: _int(raw['content_version'], 1),
      contentHash: _strOrNull(raw['content_hash']),
      updatedAt: readDateTolerant(raw['updated_at']),
    );
  }

  ExamQuestionDoc copyWith({
    String? subjectId,
    String? sectionId,
    String? partId,
    bool clearPart = false,
    String? topicId,
    String? subtopicId,
    bool clearSubtopic = false,
    int? difficulty,
    String? language,
    String? translationGroupId,
    String? type,
    String? stem,
    List<ExamOption>? options,
    String? passageId,
    bool clearPassage = false,
    String? imagePath,
    bool clearImage = false,
    ExamSource? source,
    ExamReview? review,
    int? contentVersion,
    String? contentHash,
  }) =>
      ExamQuestionDoc(
        id: id,
        subjectId: subjectId ?? this.subjectId,
        sectionId: sectionId ?? this.sectionId,
        partId: clearPart ? null : (partId ?? this.partId),
        topicId: topicId ?? this.topicId,
        subtopicId: clearSubtopic ? null : (subtopicId ?? this.subtopicId),
        difficulty: difficulty ?? this.difficulty,
        language: language ?? this.language,
        translationGroupId: translationGroupId ?? this.translationGroupId,
        type: type ?? this.type,
        stem: stem ?? this.stem,
        options: options ?? this.options,
        passageId: clearPassage ? null : (passageId ?? this.passageId),
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        table: table,
        source: source ?? this.source,
        review: review ?? this.review,
        contentVersion: contentVersion ?? this.contentVersion,
        contentHash: contentHash ?? this.contentHash,
        updatedAt: updatedAt,
      );

  /// Content fields written to `exam_questions/{id}`. `review`, timestamps and
  /// `created_*` are added by the repository.
  Map<String, dynamic> toContentFields() => {
        'subject_id': subjectId,
        'section_id': sectionId,
        'part_id': partId,
        'topic_id': topicId,
        'subtopic_id': subtopicId,
        'difficulty': difficulty,
        'language': language,
        'translation_group_id': translationGroupId,
        'type': type,
        'stem': stem,
        'options': [for (final o in options) o.toMap()],
        'passage_id': passageId,
        'image_path': imagePath,
        'table': table,
        'source': source.toMap(),
        'content_version': contentVersion,
        'content_hash': contentHash,
      };

  /// True when the student-visible content differs from [other].
  bool contentDiffers(ExamQuestionDoc other) =>
      stem != other.stem ||
      jsonEncode([for (final o in options) o.toMap()]) !=
          jsonEncode([for (final o in other.options) o.toMap()]) ||
      passageId != other.passageId ||
      imagePath != other.imagePath ||
      language != other.language;
}

/// `content_hash` = `sha256:` + hex digest over language, stem, options and
/// the correct key (used by the pipeline for de-duplication).
String computeContentHash(ExamQuestionDoc q, String correct) {
  final canonical = jsonEncode({
    'language': q.language,
    'stem': q.stem.trim(),
    'options': [
      for (final o in q.options) [o.id, o.text.trim()],
    ],
    'correct': correct,
  });
  return 'sha256:${sha256.convert(utf8.encode(canonical))}';
}

class ExamKeyDoc {
  final String correct;
  final String explanation;
  final Map<String, String> wrongOptionNotes;
  final List<String> solutionSteps;

  const ExamKeyDoc({
    this.correct = '',
    this.explanation = '',
    this.wrongOptionNotes = const {},
    this.solutionSteps = const [],
  });

  bool get hasCorrect => correct.trim().isNotEmpty;

  factory ExamKeyDoc.fromMap(Object? raw) {
    if (raw is! Map) return const ExamKeyDoc();
    final notes = <String, String>{};
    final rawNotes = raw['wrong_option_notes'] ?? raw['wrongOptionNotes'];
    if (rawNotes is Map) {
      rawNotes.forEach((k, v) {
        final s = _str(v).trim();
        if (k != null && s.isNotEmpty) notes[k.toString().toUpperCase()] = s;
      });
    }
    final steps = <String>[];
    final rawSteps = raw['solution_steps'] ?? raw['solutionSteps'];
    if (rawSteps is List) {
      for (final s in rawSteps) {
        final t = _str(s).trim();
        if (t.isNotEmpty) steps.add(t);
      }
    }
    return ExamKeyDoc(
      correct: _str(raw['correct'] ?? raw['correct_answer'] ?? raw['correctAnswer'])
          .trim()
          .toUpperCase(),
      explanation: _str(raw['explanation']),
      wrongOptionNotes: notes,
      solutionSteps: steps,
    );
  }

  Map<String, dynamic> toMap() => {
        'correct': correct,
        'explanation': explanation,
        'wrong_option_notes': wrongOptionNotes,
        'solution_steps': solutionSteps,
      };
}

class ExamPassageDoc {
  final String id;
  final String language;
  final String subjectId;
  final String sectionId;
  final String title;
  final String text;
  final String source;

  const ExamPassageDoc({
    required this.id,
    required this.language,
    required this.subjectId,
    required this.sectionId,
    required this.title,
    required this.text,
    this.source = '',
  });

  factory ExamPassageDoc.fromMap(String id, Map raw) {
    final src = raw['source'];
    return ExamPassageDoc(
      id: id,
      language: _lang(raw['language']),
      subjectId: _str(raw['subject_id']),
      sectionId: _str(raw['section_id']),
      title: _str(raw['title']),
      text: _str(raw['text']),
      source: src is Map ? _str(src['basis'] ?? src['url']) : _str(src),
    );
  }

  Map<String, dynamic> toMap() => {
        'language': language,
        'subject_id': subjectId,
        'section_id': sectionId,
        'title': title,
        'text': text,
        'source': source,
      };
}

/// Validation issue codes for the exam question editor (localized in the UI).
abstract final class ExamQuestionIssue {
  static const sectionRequired = 'section_required';
  static const topicRequired = 'topic_required';
  static const languageInvalid = 'language_invalid';
  static const difficultyRange = 'difficulty_range';
  static const stemRequired = 'stem_required';
  static const optionsCount = 'options_count';
  static const optionEmpty = 'option_empty';
  static const optionDuplicate = 'option_duplicate';
  static const correctRequired = 'correct_required';
  static const correctNotInOptions = 'correct_not_in_options';
  static const passageRequired = 'passage_required';
}

/// Validates a question + key before saving. [expectedOptions] comes from the
/// blueprint part (`null` = only "at least two").
List<String> validateExamQuestion(
  ExamQuestionDoc q,
  ExamKeyDoc key, {
  int? expectedOptions,
  bool needsPassage = false,
}) {
  final issues = <String>[];
  if (q.sectionId.isEmpty || q.subjectId.isEmpty) {
    issues.add(ExamQuestionIssue.sectionRequired);
  }
  if (q.topicId.isEmpty) issues.add(ExamQuestionIssue.topicRequired);
  if (!kExamLanguages.contains(q.language)) issues.add(ExamQuestionIssue.languageInvalid);
  if (q.difficulty < 1 || q.difficulty > 3) issues.add(ExamQuestionIssue.difficultyRange);
  if (q.stem.trim().isEmpty) issues.add(ExamQuestionIssue.stemRequired);
  final countOk =
      expectedOptions != null ? q.options.length == expectedOptions : q.options.length >= 2;
  if (!countOk) issues.add(ExamQuestionIssue.optionsCount);
  if (q.options.any((o) => o.text.trim().isEmpty)) issues.add(ExamQuestionIssue.optionEmpty);
  final ids = q.options.map((o) => o.id).toList();
  if (ids.toSet().length != ids.length) issues.add(ExamQuestionIssue.optionDuplicate);
  if (!key.hasCorrect) {
    issues.add(ExamQuestionIssue.correctRequired);
  } else if (!ids.contains(key.correct)) {
    issues.add(ExamQuestionIssue.correctNotInOptions);
  }
  if (needsPassage && (q.passageId == null || q.passageId!.isEmpty)) {
    issues.add(ExamQuestionIssue.passageRequired);
  }
  return issues;
}

/// One draft returned by `adminAiDraftQuestions` (`{drafts: [question без id + key]}`).
class AiDraft {
  final ExamQuestionDoc question;
  final ExamKeyDoc key;
  const AiDraft(this.question, this.key);
}

/// Parses a draft tolerantly; missing metadata falls back to the request
/// parameters. The result is always `review.status == draft` with
/// `source.kind == 'ai'` — AI output is never trusted as approved.
AiDraft parseAiDraft(
  Map raw, {
  required String id,
  required String subjectId,
  required String sectionId,
  required String? partId,
  required String topicId,
  required int difficulty,
  required String language,
  required String type,
}) {
  final parsed = ExamQuestionDoc.fromMap(id, raw);
  final keyRaw = raw['key'] is Map ? raw['key'] as Map : raw;
  final key = ExamKeyDoc.fromMap(keyRaw);
  final rawDifficulty = raw['difficulty'];
  final q = ExamQuestionDoc(
    id: id,
    subjectId: parsed.subjectId.isEmpty ? subjectId : parsed.subjectId,
    sectionId: parsed.sectionId.isEmpty ? sectionId : parsed.sectionId,
    partId: parsed.partId ?? partId,
    topicId: parsed.topicId.isEmpty ? topicId : parsed.topicId,
    subtopicId: parsed.subtopicId,
    difficulty: (rawDifficulty != null && parsed.difficulty >= 1 && parsed.difficulty <= 3)
        ? parsed.difficulty
        : difficulty,
    language: parsed.language.isEmpty ? language : parsed.language,
    type: raw['type'] == null ? type : parsed.type,
    stem: parsed.stem,
    options: parsed.options,
    passageId: parsed.passageId,
    source: ExamSource(
      kind: 'ai',
      basis: parsed.source.basis,
      author: parsed.source.author.isEmpty ? 'ai:adminAiDraftQuestions' : parsed.source.author,
    ),
    review: const ExamReview(status: ReviewStatus.draft),
  );
  return AiDraft(q, key);
}
