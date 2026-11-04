/// Question table (`exam_questions.table`).
///
/// Storage shape (decision D2): `{headers: [string], rows: [{cells: [string]}]}`
/// — Firestore cannot hold nested arrays. Callables normalise it to the wire
/// shape `rows: [[string]]`; this reader accepts both so the CMS can show any
/// document, and always writes the `{cells}` shape.
///
/// Pure Dart (no Flutter / Firebase imports) so it can be unit-tested.
library;

import 'dart:convert';

class ExamTableDoc {
  const ExamTableDoc({this.headers = const [], this.rows = const []});

  /// Header row; empty = the table has no header row.
  final List<String> headers;

  /// Body rows (cells as Markdown/LaTeX strings, like the stem).
  final List<List<String>> rows;

  /// A 2×1 table (header + one row) — the usual quantitative-comparison layout.
  factory ExamTableDoc.blank({int columns = 2, int rows = 1}) => ExamTableDoc(
        headers: List.filled(columns, ''),
        rows: List.generate(rows, (_) => List.filled(columns, '')),
      );

  static String _cell(Object? v) => v == null ? '' : v.toString();

  /// Reads `rows[i]` as a list (wire shape) or as `{cells: [...]}` (storage
  /// shape). Returns `null` for anything that is not a non-empty table.
  static ExamTableDoc? fromAny(Object? raw) {
    if (raw is! Map) return null;
    final rawHeaders = raw['headers'];
    final headers = rawHeaders is List ? [for (final h in rawHeaders) _cell(h)] : <String>[];
    final rows = <List<String>>[];
    final rawRows = raw['rows'];
    if (rawRows is List) {
      for (final r in rawRows) {
        if (r is List) {
          rows.add([for (final c in r) _cell(c)]);
        } else if (r is Map && r['cells'] is List) {
          rows.add([for (final c in r['cells'] as List) _cell(c)]);
        }
      }
    }
    if (headers.isEmpty && rows.isEmpty) return null;
    return ExamTableDoc(headers: headers, rows: rows);
  }

  /// Widest row (header included).
  int get columnCount => [headers.length, for (final r in rows) r.length]
      .fold<int>(0, (m, n) => n > m ? n : m);

  bool get hasHeader => headers.any((h) => h.trim().isNotEmpty);

  /// No text anywhere — saved as `table: null`.
  bool get isBlank =>
      !hasHeader && rows.every((r) => r.every((c) => c.trim().isEmpty));

  List<String> _pad(List<String> cells, int n) =>
      [...cells, for (var i = cells.length; i < n; i++) ''];

  /// Headers padded to [columnCount] (for the editor grid).
  List<String> get paddedHeaders => _pad(headers, columnCount);

  /// Rows padded to [columnCount] (for the editor grid and the preview).
  List<List<String>> get paddedRows => [for (final r in rows) _pad(r, columnCount)];

  /// Storage shape (D2). Rows are padded to the same width, rows without any
  /// text are dropped, and a header row without text is stored as `[]`.
  Map<String, dynamic> toFirestore() {
    final n = columnCount;
    return {
      'headers': hasHeader ? _pad(headers, n) : <String>[],
      'rows': [
        for (final r in rows)
          if (r.any((c) => c.trim().isNotEmpty)) {'cells': _pad(r, n)},
      ],
    };
  }

  ExamTableDoc setHeader(int col, String value) {
    final h = _pad(headers, columnCount > col ? columnCount : col + 1);
    h[col] = value;
    return ExamTableDoc(headers: h, rows: rows);
  }

  ExamTableDoc setCell(int row, int col, String value) {
    final n = columnCount > col ? columnCount : col + 1;
    final next = [for (final r in rows) [...r]];
    while (next.length <= row) {
      next.add(List.filled(n, ''));
    }
    next[row] = _pad(next[row], n)..[col] = value;
    return ExamTableDoc(headers: headers, rows: next);
  }

  ExamTableDoc addRow() {
    final n = columnCount == 0 ? 2 : columnCount;
    return ExamTableDoc(headers: headers, rows: [...rows, List.filled(n, '')]);
  }

  ExamTableDoc removeRow(int index) {
    if (index < 0 || index >= rows.length) return this;
    return ExamTableDoc(headers: headers, rows: [...rows]..removeAt(index));
  }

  ExamTableDoc addColumn() {
    final n = columnCount + 1;
    return ExamTableDoc(
      headers: _pad(headers, n),
      rows: [for (final r in rows) _pad(r, n)],
    );
  }

  ExamTableDoc removeColumn(int index) {
    if (index < 0 || index >= columnCount || columnCount <= 1) return this;
    List<String> drop(List<String> cells) {
      final c = _pad(cells, columnCount);
      return c..removeAt(index);
    }

    return ExamTableDoc(
      headers: headers.isEmpty ? const [] : drop(headers),
      rows: [for (final r in rows) drop(r)],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExamTableDoc && jsonEncode(toFirestore()) == jsonEncode(other.toFirestore());

  @override
  int get hashCode => jsonEncode(toFirestore()).hashCode;

  @override
  String toString() => 'ExamTableDoc(${jsonEncode(toFirestore())})';
}
