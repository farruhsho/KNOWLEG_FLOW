import 'package:flutter/foundation.dart';

import 'json_utils.dart';

@immutable
class QuestionOption {
  final String id;
  final String text;

  const QuestionOption({required this.id, required this.text});

  factory QuestionOption.fromJson(Object? json, int index) {
    if (json is String) {
      return QuestionOption(id: String.fromCharCode(65 + index), text: json);
    }
    final m = asJsonMap(json);
    return QuestionOption(
      id: asString(m['id']) ?? String.fromCharCode(65 + index),
      text: asString(m['text']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}

/// Simple table attached to a question.
///
/// Two shapes are accepted (contract D2): the callable wire shape
/// `{headers: [...], rows: [[...]]}` and the Firestore storage shape
/// `{headers: [...], rows: [{cells: [...]}]}` (Firestore cannot hold an array
/// inside an array). A row may also be a map keyed by column index
/// (`{"0": "a", "1": "b"}`). [toJson] always writes the wire shape, which is
/// what the local Hive copy stores.
@immutable
class QuestionTable {
  final List<String> headers;
  final List<List<String>> rows;

  const QuestionTable({required this.headers, required this.rows});

  static QuestionTable? fromJson(Object? json) {
    final m = asJsonMap(json);
    if (m.isEmpty) return null;
    final headers = asJsonList(m['headers']).map((e) => asString(e) ?? '').toList();
    final rows = <List<String>>[
      for (final r in _rowList(m['rows'])) _cells(r),
    ];
    if (headers.isEmpty && rows.isEmpty) return null;
    return QuestionTable(headers: headers, rows: rows);
  }

  /// `rows` as a list; a map keyed by row index is ordered by that index.
  static List<Object?> _rowList(Object? raw) {
    if (raw is List) return raw;
    if (raw is Map) return _indexedValues(asJsonMap(raw));
    return const [];
  }

  static List<String> _cells(Object? row) {
    if (row is List) return [for (final c in row) asString(c) ?? ''];
    if (row is Map) {
      final m = asJsonMap(row);
      final cells = m['cells'];
      if (cells is List) return [for (final c in cells) asString(c) ?? ''];
      return [for (final c in _indexedValues(m)) asString(c) ?? ''];
    }
    final single = asString(row);
    return single == null ? const [] : [single];
  }

  /// Values of a map whose keys are integer indices, in index order;
  /// non-index keys are ignored.
  static List<Object?> _indexedValues(Map<String, dynamic> m) {
    final entries = [
      for (final e in m.entries)
        if (int.tryParse(e.key) != null) (int.parse(e.key), e.value),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final e in entries) e.$2];
  }

  Map<String, dynamic> toJson() => {'headers': headers, 'rows': rows};
}

/// Keys that may carry a question's image, most specific first (contract
/// D3): callables send a Storage path in `imagePath` (and an https URL, if
/// any, in `imageUrl`); stored documents use `image_path`.
const List<String> examImageKeys = ['imageUrl', 'image_url', 'imagePath', 'image_path'];

/// Image reference (https URL or Storage path such as
/// `exam_media/q1/fig.png`) of a question or review item, or null. Blank
/// values are ignored so an empty `imageUrl` does not hide `imagePath`.
String? examImageReference(Map<String, dynamic> m) {
  for (final k in examImageKeys) {
    final v = asString(m[k])?.trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

/// Quantitative-comparison quantities (column A, column B) of a question or
/// review item: `columnA`/`columnB` (callables), `column_a`/`column_b`
/// (stored documents) or a `columns: {a, b}` map.
(String?, String?) examComparisonColumns(Map<String, dynamic> m) {
  final columns = asJsonMap(m['columns']);
  return (
    asString(pick(m, const ['columnA', 'column_a'])) ??
        asString(columns['a'] ?? columns['A']),
    asString(pick(m, const ['columnB', 'column_b'])) ??
        asString(columns['b'] ?? columns['B']),
  );
}

/// One question of the current section as delivered by the server (never
/// with its correct answer).
@immutable
class ExamQuestion {
  final String id;
  final String stem;
  final List<QuestionOption> options;
  final String? passageId;

  /// Image reference: an https URL or a Storage path, resolved to a download
  /// URL by `examImageUrlResolverProvider` when shown.
  final String? imageUrl;
  final QuestionTable? table;
  final String? topicId;
  final String? partId;

  /// Quantitative-comparison columns (math part I). Optional: when absent the
  /// stem is expected to contain both quantities.
  final String? columnA;
  final String? columnB;

  const ExamQuestion({
    required this.id,
    required this.stem,
    required this.options,
    this.passageId,
    this.imageUrl,
    this.table,
    this.topicId,
    this.partId,
    this.columnA,
    this.columnB,
  });

  bool get hasComparisonColumns =>
      (columnA?.isNotEmpty ?? false) || (columnB?.isNotEmpty ?? false);

  factory ExamQuestion.fromJson(Object? json) {
    final m = asJsonMap(json);
    final (columnA, columnB) = examComparisonColumns(m);
    final options = asJsonList(m['options']);
    return ExamQuestion(
      id: asString(pick(m, const ['id', 'questionId', 'question_id'])) ?? '',
      stem: asString(m['stem']) ?? '',
      options: [
        for (var i = 0; i < options.length; i++)
          QuestionOption.fromJson(options[i], i),
      ],
      passageId: asString(pick(m, const ['passageId', 'passage_id'])),
      imageUrl: examImageReference(m),
      table: QuestionTable.fromJson(m['table']),
      topicId: asString(pick(m, const ['topicId', 'topic_id'])),
      partId: asString(pick(m, const ['partId', 'part_id'])),
      columnA: columnA,
      columnB: columnB,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stem': stem,
        'options': options.map((o) => o.toJson()).toList(),
        if (passageId != null) 'passageId': passageId,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (table != null) 'table': table!.toJson(),
        if (topicId != null) 'topicId': topicId,
        if (partId != null) 'partId': partId,
        if (columnA != null) 'columnA': columnA,
        if (columnB != null) 'columnB': columnB,
      };
}

/// Reading passage shared by several questions.
@immutable
class ExamPassage {
  final String id;
  final String title;
  final String text;

  const ExamPassage({required this.id, required this.title, required this.text});

  factory ExamPassage.fromJson(String id, Object? json) {
    if (json is String) return ExamPassage(id: id, title: '', text: json);
    final m = asJsonMap(json);
    return ExamPassage(
      id: id,
      title: asString(m['title']) ?? '',
      text: asString(m['text']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'text': text};

  /// Source lines of the passage (texts are pre-broken by the pipeline so the
  /// official "every 5th line" numbering refers to these lines).
  List<String> get lines => text.replaceAll('\r\n', '\n').split('\n');
}
