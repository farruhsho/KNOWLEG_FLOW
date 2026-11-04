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

/// Simple table attached to a question: `{headers: [...], rows: [[...]]}`.
@immutable
class QuestionTable {
  final List<String> headers;
  final List<List<String>> rows;

  const QuestionTable({required this.headers, required this.rows});

  static QuestionTable? fromJson(Object? json) {
    final m = asJsonMap(json);
    if (m.isEmpty) return null;
    final headers = asJsonList(m['headers']).map((e) => asString(e) ?? '').toList();
    final rows = asJsonList(m['rows'])
        .map((r) => asJsonList(r).map((c) => asString(c) ?? '').toList())
        .toList();
    if (headers.isEmpty && rows.isEmpty) return null;
    return QuestionTable(headers: headers, rows: rows);
  }

  Map<String, dynamic> toJson() => {'headers': headers, 'rows': rows};
}

/// One question of the current section as delivered by the server (never
/// with its correct answer).
@immutable
class ExamQuestion {
  final String id;
  final String stem;
  final List<QuestionOption> options;
  final String? passageId;
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
    final columns = asJsonMap(m['columns']);
    final options = asJsonList(m['options']);
    return ExamQuestion(
      id: asString(pick(m, const ['id', 'questionId', 'question_id'])) ?? '',
      stem: asString(m['stem']) ?? '',
      options: [
        for (var i = 0; i < options.length; i++)
          QuestionOption.fromJson(options[i], i),
      ],
      passageId: asString(pick(m, const ['passageId', 'passage_id'])),
      imageUrl: asString(pick(m, const ['imageUrl', 'image_url', 'image_path'])),
      table: QuestionTable.fromJson(m['table']),
      topicId: asString(pick(m, const ['topicId', 'topic_id'])),
      partId: asString(pick(m, const ['partId', 'part_id'])),
      columnA: asString(pick(m, const ['columnA', 'column_a'])) ??
          asString(columns['a'] ?? columns['A']),
      columnB: asString(pick(m, const ['columnB', 'column_b'])) ??
          asString(columns['b'] ?? columns['B']),
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
