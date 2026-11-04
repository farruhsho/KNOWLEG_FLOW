/// Codec for the legacy practice bank (`questions` collection).
///
/// One tolerant reader for every shape that exists in the wild (snake_case
/// from `QuestionModel.toFirestore`, camelCase from `toJson`/exports, the old
/// admin model with per-option `is_correct`, `kg` locale keys) and one
/// canonical writer: snake_case fields, snake_case `type` wire values
/// (FB-13 / CMS-18) plus a `subjectId` mirror because the student app still
/// filters practice questions by `subjectId`.
library;

import 'dart:convert';

import 'package:csv/csv.dart';

import 'localized_text.dart';

/// Canonical `type` wire values understood by the student parser.
const List<String> kPracticeQuestionTypes = [
  'single_choice',
  'multiple_choice',
  'analogy',
  'completion',
  'matching',
  'ordering',
  'true_false',
  'text_based',
];

const Map<String, String> _typeAliases = {
  'singlechoice': 'single_choice',
  'single': 'single_choice',
  'mcq': 'single_choice',
  'multiplechoice': 'multiple_choice',
  'multiple': 'multiple_choice',
  'multi': 'multiple_choice',
  'analogy': 'analogy',
  'analogies': 'analogy',
  'completion': 'completion',
  'fillblank': 'completion',
  'fillintheblank': 'completion',
  'matching': 'matching',
  'ordering': 'ordering',
  'truefalse': 'true_false',
  'tf': 'true_false',
  'textbased': 'text_based',
  'reading': 'text_based',
};

/// Maps any known spelling (`multipleChoice`, `multiple_choice`, `fill_blank`,
/// `QuestionType.trueFalse`) to its canonical wire value, or `null`.
String? normalizeQuestionType(Object? raw) {
  if (raw is! String) return null;
  var v = raw.trim();
  if (v.contains('.')) v = v.split('.').last; // QuestionType.trueFalse
  v = v.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
  if (v.isEmpty) return null;
  return _typeAliases[v];
}

const List<String> kOptionIds = ['A', 'B', 'C', 'D', 'E'];

class PracticeOption {
  final String id;
  final Map<String, String> text;
  const PracticeOption(this.id, this.text);

  Map<String, dynamic> toMap() => {'id': id, 'text': text};
}

/// Validation / import issue codes (localized in the UI).
abstract final class PracticeIssue {
  static const subjectRequired = 'subject_required';
  static const stemRequired = 'stem_required';
  static const optionsMin = 'options_min';
  static const optionEmpty = 'option_empty';
  static const correctRequired = 'correct_required';
  static const correctNotInOptions = 'correct_not_in_options';
  static const difficultyRange = 'difficulty_range';
  static const typeUnknown = 'type_unknown';
  static const parseError = 'parse_error';
  static const emptyFile = 'empty_file';
  static const duplicateId = 'duplicate_id';
}

int? _toInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

bool? _toBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (const ['true', '1', 'yes', 'y', 'да', 'ооба', '+'].contains(s)) return true;
    if (const ['false', '0', 'no', 'n', 'нет', 'жок', '-'].contains(s)) return false;
  }
  return null;
}

List<String> _toStringList(Object? v) {
  if (v is List) {
    return [
      for (final e in v)
        if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
  }
  if (v is String) {
    return v
        .split(RegExp(r'[|;,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}

T? _first<T>(Map raw, List<String> keys) {
  for (final k in keys) {
    final v = raw[k];
    if (v is T) return v;
  }
  return null;
}

class PracticeQuestionDraft {
  final String? id;
  final String subjectId;
  final String sectionId;
  final String? topicId;
  final String? lessonId;

  /// Canonical type wire value, or the raw value when it is unknown.
  final String type;
  final bool typeKnown;
  final int difficulty;
  final int points;
  final Map<String, String> stem;
  final List<PracticeOption> options;
  final String correctAnswer;
  final List<String>? correctAnswers;
  final Map<String, String> explanation;
  final Map<String, String> hint;
  final List<String> tags;
  final bool isActive;
  final String? imageUrl;
  final String category;
  final String? source;

  const PracticeQuestionDraft({
    this.id,
    required this.subjectId,
    this.sectionId = '',
    this.topicId,
    this.lessonId,
    this.type = 'single_choice',
    this.typeKnown = true,
    this.difficulty = 1,
    this.points = 1,
    required this.stem,
    required this.options,
    required this.correctAnswer,
    this.correctAnswers,
    this.explanation = const {},
    this.hint = const {},
    this.tags = const [],
    this.isActive = true,
    this.imageUrl,
    this.category = 'subject',
    this.source,
  });

  bool get isMultiple => type == 'multiple_choice';

  /// Tolerant reader for Firestore docs, exports and import rows.
  factory PracticeQuestionDraft.fromMap(Map raw, {String? id}) {
    final options = <PracticeOption>[];
    final derivedCorrect = <String>[];
    final rawOptions = raw['options'];
    if (rawOptions is List) {
      for (var i = 0; i < rawOptions.length; i++) {
        final o = rawOptions[i];
        final fallbackId = i < kOptionIds.length ? kOptionIds[i] : '$i';
        if (o is Map) {
          final oid = (o['id'] ?? fallbackId).toString().trim().toUpperCase();
          options.add(PracticeOption(oid, readLocalized(o['text'] ?? o['label'])));
          if (_toBool(o['is_correct'] ?? o['isCorrect']) == true) derivedCorrect.add(oid);
        } else if (o is String) {
          options.add(PracticeOption(fallbackId, readLocalized(o)));
        }
      }
    }
    final rawType = _first<String>(raw, ['type', 'question_type', 'questionType']);
    final normType = normalizeQuestionType(rawType ?? 'single_choice');
    var correct =
        (_first<String>(raw, ['correct_answer', 'correctAnswer', 'correct']) ?? '')
            .trim()
            .toUpperCase();
    final correctList = _toStringList(raw['correct_answers'] ?? raw['correctAnswers'])
        .map((e) => e.toUpperCase())
        .toList();
    if (correct.isEmpty && derivedCorrect.isNotEmpty) correct = derivedCorrect.first;
    final multi = normType == 'multiple_choice';
    List<String>? multiAnswers;
    if (multi) {
      if (correctList.isNotEmpty) {
        multiAnswers = correctList;
      } else if (derivedCorrect.isNotEmpty) {
        multiAnswers = derivedCorrect;
      } else {
        multiAnswers = correct.isEmpty ? <String>[] : [correct];
      }
    }
    return PracticeQuestionDraft(
      id: id ?? _first<String>(raw, ['id']),
      subjectId:
          (_first<String>(raw, ['subject_id', 'subjectId', 'subject']) ?? '').trim(),
      sectionId:
          (_first<String>(raw, ['section_id', 'sectionId', 'section']) ?? '').trim(),
      topicId: _first<String>(raw, ['topic_id', 'topicId']),
      lessonId: _first<String>(raw, ['lesson_id', 'lessonId']),
      type: normType ?? (rawType ?? ''),
      typeKnown: normType != null,
      difficulty: _toInt(raw['difficulty']) ?? 1,
      points: _toInt(raw['points']) ?? 1,
      stem: readLocalized(raw['stem'] ?? raw['question'] ?? raw['text']),
      options: options,
      correctAnswer: correct,
      correctAnswers: multiAnswers,
      explanation: readLocalized(raw['explanation']),
      hint: readLocalized(raw['hint']),
      tags: _toStringList(raw['tags']),
      isActive: _toBool(raw['is_active'] ?? raw['isActive']) ?? true,
      imageUrl: _first<String>(raw, ['image_url', 'imageUrl']),
      category: _first<String>(raw, ['category']) ?? 'subject',
      source: raw['source'] is String ? raw['source'] as String : null,
    );
  }

  /// Issue codes; empty means valid.
  List<String> validate() {
    final issues = <String>[];
    if (subjectId.isEmpty) issues.add(PracticeIssue.subjectRequired);
    if (!typeKnown) issues.add(PracticeIssue.typeUnknown);
    if (stem.values.every((v) => v.trim().isEmpty)) issues.add(PracticeIssue.stemRequired);
    if (difficulty < 1 || difficulty > 3) issues.add(PracticeIssue.difficultyRange);
    if (options.length < 2) issues.add(PracticeIssue.optionsMin);
    if (options.any((o) => o.text.values.every((v) => v.trim().isEmpty))) {
      issues.add(PracticeIssue.optionEmpty);
    }
    final ids = options.map((o) => o.id).toSet();
    if (isMultiple) {
      final list = correctAnswers ?? const <String>[];
      if (list.isEmpty) {
        issues.add(PracticeIssue.correctRequired);
      } else if (!list.every(ids.contains)) {
        issues.add(PracticeIssue.correctNotInOptions);
      }
    } else if (correctAnswer.isEmpty) {
      issues.add(PracticeIssue.correctRequired);
    } else if (!ids.contains(correctAnswer)) {
      issues.add(PracticeIssue.correctNotInOptions);
    }
    return issues;
  }

  /// Canonical content fields. Audit fields (`created_*`, `updated_*`) are
  /// added by the repository with server timestamps.
  Map<String, dynamic> toFirestoreFields() => {
        'subject_id': subjectId,
        'subjectId': subjectId, // read by FirebaseDataService.getQuestions
        'section_id': sectionId,
        'topic_id': topicId,
        'lesson_id': lessonId,
        'type': type,
        'difficulty': difficulty,
        'points': points,
        'stem': stem,
        'options': [for (final o in options) o.toMap()],
        'correct_answer': isMultiple && (correctAnswers?.isNotEmpty ?? false)
            ? correctAnswers!.first
            : correctAnswer,
        'correct_answers': isMultiple ? correctAnswers : null,
        'explanation': explanation,
        'hint': hint.isEmpty ? null : hint,
        'tags': tags,
        'is_active': isActive,
        'image_url': imageUrl,
        'category': category,
        if (source != null) 'source': source,
      };
}

// ---------------------------------------------------------------------------
// Import
// ---------------------------------------------------------------------------

class ImportIssue {
  /// 1-based data row (CSV: excluding the header; JSON: array index + 1).
  /// 0 = file-level issue.
  final int row;
  final String code;
  const ImportIssue(this.row, this.code);

  @override
  String toString() => 'ImportIssue(row $row: $code)';
}

class ImportParseResult {
  final List<PracticeQuestionDraft> valid;
  final List<ImportIssue> issues;
  final int totalRows;
  const ImportParseResult(this.valid, this.issues, this.totalRows);

  int get invalidRows =>
      issues.map((i) => i.row).where((r) => r > 0).toSet().length;
}

/// Canonical CSV columns (also the export header).
List<String> practiceCsvHeader() => [
      'id',
      'subject_id',
      'section_id',
      'topic_id',
      'type',
      'difficulty',
      'points',
      for (final l in kContentLocales) 'stem_$l',
      for (final o in kOptionIds)
        for (final l in kContentLocales) 'option_${o.toLowerCase()}_$l',
      'correct_answer',
      'correct_answers',
      for (final l in kContentLocales) 'explanation_$l',
      'tags',
      'is_active',
      'image_url',
    ];

String _canonHeader(String h) {
  var s = h
      .replaceAll('﻿', '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-]+'), '_');
  s = s.replaceAll(RegExp(r'_kg$'), '_ky');
  const aliases = {
    'subject': 'subject_id',
    'subjectid': 'subject_id',
    'section': 'section_id',
    'sectionid': 'section_id',
    'topic': 'topic_id',
    'topicid': 'topic_id',
    'correct': 'correct_answer',
    'answer': 'correct_answer',
    'correctanswer': 'correct_answer',
    'stem': 'stem_ru',
    'question': 'stem_ru',
    'explanation': 'explanation_ru',
    'active': 'is_active',
  };
  if (aliases.containsKey(s)) return aliases[s]!;
  final q = RegExp(r'^question_(ru|ky|en)$').firstMatch(s);
  if (q != null) return 'stem_${q.group(1)}';
  final o = RegExp(r'^(?:option_)?([a-e])(?:_(ru|ky|en))?$').firstMatch(s);
  if (o != null) return 'option_${o.group(1)}_${o.group(2) ?? 'ru'}';
  return s;
}

/// Converts one CSV row (canonical header → cell) into the map shape
/// [PracticeQuestionDraft.fromMap] reads.
Map<String, dynamic> csvRowToMap(Map<String, String> row) {
  String? cell(String k) {
    final v = row[k];
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Map<String, String> localized(String prefix) => {
        for (final l in kContentLocales)
          if (cell('${prefix}_$l') != null) l: cell('${prefix}_$l')!,
      };

  final options = <Map<String, dynamic>>[];
  for (final o in kOptionIds) {
    final text = localized('option_${o.toLowerCase()}');
    if (text.isNotEmpty) options.add({'id': o, 'text': text});
  }
  return {
    if (cell('id') != null) 'id': cell('id'),
    'subject_id': cell('subject_id') ?? '',
    'section_id': cell('section_id') ?? '',
    if (cell('topic_id') != null) 'topic_id': cell('topic_id'),
    if (cell('lesson_id') != null) 'lesson_id': cell('lesson_id'),
    'type': cell('type') ?? 'single_choice',
    'difficulty': cell('difficulty') ?? '1',
    'points': cell('points') ?? '1',
    'stem': localized('stem'),
    'options': options,
    'correct_answer': cell('correct_answer') ?? '',
    if (cell('correct_answers') != null) 'correct_answers': cell('correct_answers'),
    'explanation': localized('explanation'),
    'hint': localized('hint'),
    if (cell('tags') != null) 'tags': cell('tags'),
    if (cell('is_active') != null) 'is_active': cell('is_active'),
    if (cell('image_url') != null) 'image_url': cell('image_url'),
    if (cell('category') != null) 'category': cell('category'),
  };
}

String _detectDelimiter(String headerLine) {
  final semis = ';'.allMatches(headerLine).length;
  final commas = ','.allMatches(headerLine).length;
  final tabs = '\t'.allMatches(headerLine).length;
  if (tabs > semis && tabs > commas) return '\t';
  return semis > commas ? ';' : ',';
}

ImportParseResult _finish(List<Map> rows) {
  final valid = <PracticeQuestionDraft>[];
  final issues = <ImportIssue>[];
  final ids = <String>{};
  for (var i = 0; i < rows.length; i++) {
    final rowNo = i + 1;
    final draft = PracticeQuestionDraft.fromMap(rows[i]);
    final rowIssues = draft.validate();
    if (draft.id != null && draft.id!.isNotEmpty && !ids.add(draft.id!)) {
      rowIssues.add(PracticeIssue.duplicateId);
    }
    if (rowIssues.isEmpty) {
      valid.add(draft);
    } else {
      issues.addAll(rowIssues.map((c) => ImportIssue(rowNo, c)));
    }
  }
  return ImportParseResult(valid, issues, rows.length);
}

/// Parses CSV exported from Excel / Google Sheets (`,`, `;` or tab separated,
/// optional BOM, CRLF line endings, quoted multi-line cells).
ImportParseResult parsePracticeCsv(String input) {
  final text = input
      .replaceAll('﻿', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  if (text.trim().isEmpty) {
    return const ImportParseResult([], [ImportIssue(0, PracticeIssue.emptyFile)], 0);
  }
  final firstLine = text.split('\n').first;
  List<List<dynamic>> table;
  try {
    table = CsvToListConverter(
      fieldDelimiter: _detectDelimiter(firstLine),
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);
  } catch (_) {
    return const ImportParseResult([], [ImportIssue(0, PracticeIssue.parseError)], 0);
  }
  table = table
      .where((r) => r.any((c) => c != null && c.toString().trim().isNotEmpty))
      .toList();
  if (table.length < 2) {
    return const ImportParseResult([], [ImportIssue(0, PracticeIssue.emptyFile)], 0);
  }
  final header = [for (final h in table.first) _canonHeader(h.toString())];
  final rows = <Map>[];
  for (final r in table.skip(1)) {
    final m = <String, String>{};
    for (var c = 0; c < header.length && c < r.length; c++) {
      m[header[c]] = r[c]?.toString() ?? '';
    }
    rows.add(csvRowToMap(m));
  }
  return _finish(rows);
}

/// Parses a JSON array (or `{"questions": [...]}`) in export, Firestore or
/// camelCase shape.
ImportParseResult parsePracticeJson(String input) {
  Object? decoded;
  try {
    decoded = jsonDecode(input.replaceAll('﻿', ''));
  } catch (_) {
    return const ImportParseResult([], [ImportIssue(0, PracticeIssue.parseError)], 0);
  }
  final list = decoded is Map ? decoded['questions'] : decoded;
  if (list is! List || list.isEmpty) {
    return const ImportParseResult([], [ImportIssue(0, PracticeIssue.emptyFile)], 0);
  }
  final notObjects = <int>{};
  final rows = <Map>[];
  for (var i = 0; i < list.length; i++) {
    final e = list[i];
    if (e is Map) {
      rows.add(e);
    } else {
      rows.add(const {});
      notObjects.add(i + 1);
    }
  }
  final result = _finish(rows);
  return ImportParseResult(
    result.valid,
    [
      for (final r in notObjects) ImportIssue(r, PracticeIssue.parseError),
      ...result.issues.where((i) => !notObjects.contains(i.row)),
    ],
    result.totalRows,
  );
}

/// Splits [items] into chunks of at most [size]. Firestore batches allow 500
/// operations; the CMS commits a fresh batch per 400 documents (FB-16).
List<List<T>> chunked<T>(List<T> items, int size) {
  if (size <= 0) throw ArgumentError.value(size, 'size');
  return [
    for (var i = 0; i < items.length; i += size)
      items.sublist(i, i + size > items.length ? items.length : i + size),
  ];
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

/// CSV export using the same columns the importer reads (round-trips).
String practiceQuestionsToCsv(List<PracticeQuestionDraft> questions) {
  final rows = <List<String>>[practiceCsvHeader()];
  for (final q in questions) {
    final opt = {for (final o in q.options) o.id: o.text};
    rows.add([
      q.id ?? '',
      q.subjectId,
      q.sectionId,
      q.topicId ?? '',
      q.type,
      '${q.difficulty}',
      '${q.points}',
      for (final l in kContentLocales) q.stem[l] ?? '',
      for (final o in kOptionIds)
        for (final l in kContentLocales) opt[o]?[l] ?? '',
      q.correctAnswer,
      (q.correctAnswers ?? const <String>[]).join('|'),
      for (final l in kContentLocales) q.explanation[l] ?? '',
      q.tags.join('|'),
      q.isActive ? 'true' : 'false',
      q.imageUrl ?? '',
    ]);
  }
  return const ListToCsvConverter().convert(rows);
}
