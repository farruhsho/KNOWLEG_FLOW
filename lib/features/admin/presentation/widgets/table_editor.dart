import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/exam_table.dart';
import 'math_markdown.dart';

const double _cellWidth = 168;
const double _gutter = 40;

/// Read-only rendering of a question table (header row + body rows), the way
/// the exam shows it. Scrolls horizontally instead of overflowing.
class AdminTablePreview extends StatelessWidget {
  const AdminTablePreview({super.key, required this.table});
  final ExamTableDoc table;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = table.columnCount;
    if (n == 0) return const SizedBox.shrink();
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
          decoration: header ? BoxDecoration(color: t.surfaceMuted) : null,
          children: [
            for (final c in cells)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: header
                    ? DefaultTextStyle.merge(
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        child: MathMarkdownText(c),
                      )
                    : MathMarkdownText(c),
              ),
          ],
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(_cellWidth),
        border: TableBorder.all(color: t.border, borderRadius: AppRadii.smAll),
        children: [
          if (table.hasHeader) row(table.paddedHeaders, header: true),
          for (final r in table.paddedRows) row(r),
        ],
      ),
    );
  }
}

/// Grid editor for `exam_questions.table` (D2: stored as
/// `{headers, rows: [{cells}]}`): header row, body rows, add/remove rows and
/// columns, and a live preview. Cells accept the same Markdown/LaTeX as the
/// stem.
class AdminTableEditor extends StatefulWidget {
  const AdminTableEditor({super.key, required this.initial, required this.onChanged});

  final ExamTableDoc initial;
  final ValueChanged<ExamTableDoc> onChanged;

  @override
  State<AdminTableEditor> createState() => _AdminTableEditorState();
}

class _AdminTableEditorState extends State<AdminTableEditor> {
  late ExamTableDoc _t = widget.initial;

  /// Bumped on structural edits so every cell re-reads its value.
  int _epoch = 0;

  void _update(ExamTableDoc next, {bool structural = false}) {
    setState(() {
      _t = next;
      if (structural) _epoch++;
    });
    widget.onChanged(next);
  }

  Widget _cell(String key, String value, String hint, ValueChanged<String> onChanged) => SizedBox(
        width: _cellWidth,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: TextFormField(
            key: ValueKey('$key-$_epoch'),
            initialValue: value,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            onChanged: onChanged,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final n = _t.columnCount;
    final headers = _t.paddedHeaders;
    final rows = _t.paddedRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.adminExamTableHelp, style: TextStyle(color: t.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SizedBox(
                  width: _gutter,
                  child: Text(l.adminExamTableHeaderShort, style: TextStyle(color: t.textTertiary)),
                ),
                for (var c = 0; c < n; c++)
                  _cell('h$c', headers[c], l.adminExamTableHeader,
                      (v) => _update(_t.setHeader(c, v))),
              ]),
              for (var r = 0; r < rows.length; r++)
                Row(children: [
                  SizedBox(
                    width: _gutter,
                    child: IconButton(
                      tooltip: l.adminExamTableRemoveRow,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () => _update(_t.removeRow(r), structural: true),
                    ),
                  ),
                  for (var c = 0; c < n; c++)
                    _cell('r${r}c$c', rows[r][c], l.adminExamTableCell,
                        (v) => _update(_t.setCell(r, c, v))),
                ]),
              Row(children: [
                const SizedBox(width: _gutter),
                for (var c = 0; c < n; c++)
                  SizedBox(
                    width: _cellWidth,
                    child: Center(
                      child: IconButton(
                        tooltip: l.adminExamTableRemoveColumn,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        onPressed:
                            n > 1 ? () => _update(_t.removeColumn(c), structural: true) : null,
                      ),
                    ),
                  ),
              ]),
            ],
          ),
        ),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
          TextButton.icon(
            onPressed: () => _update(_t.addRow(), structural: true),
            icon: const Icon(Icons.table_rows_outlined),
            label: Text(l.adminExamTableAddRow),
          ),
          TextButton.icon(
            onPressed: () => _update(_t.addColumn(), structural: true),
            icon: const Icon(Icons.view_column_outlined),
            label: Text(l.adminExamTableAddColumn),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(l.adminExamTablePreview, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        if (_t.isBlank)
          Text(l.adminExamTableEmpty, style: TextStyle(color: t.textTertiary))
        else
          AdminTablePreview(table: _t),
      ],
    );
  }
}
