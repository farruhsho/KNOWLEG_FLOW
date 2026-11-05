import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/localized_text.dart';
import 'math_markdown.dart';

/// Edits a `{ru, ky, en}` map: one field per locale (ru and ky always, en
/// only when the document already has it or [showEn] is set). Reports the
/// edited values; callers merge them over the original with
/// [mergeLocalized] so untouched translations survive (CMS-12).
class LocalizedFields extends StatefulWidget {
  const LocalizedFields({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.math = false,
    this.minLines = 1,
    this.showEn = false,
  });

  final String label;
  final Map<String, String> initial;
  final ValueChanged<Map<String, String>> onChanged;

  /// Multi-line Markdown/LaTeX fields with preview.
  final bool math;
  final int minLines;
  final bool showEn;

  @override
  State<LocalizedFields> createState() => _LocalizedFieldsState();
}

class _LocalizedFieldsState extends State<LocalizedFields> {
  late final Map<String, String> _values = {...widget.initial};
  late final List<String> _locales = [
    'ru',
    'ky',
    if (widget.showEn || widget.initial.containsKey('en')) 'en',
    for (final k in widget.initial.keys)
      if (!kContentLocales.contains(k)) k,
  ];
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController _controller(String locale) => _controllers.putIfAbsent(
      locale, () => TextEditingController(text: widget.initial[locale] ?? ''));

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(String locale, String v) {
    _values[locale] = v;
    widget.onChanged(Map<String, String>.from(_values));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final locale in _locales)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: widget.math
                ? MathTextField(
                    label: '${widget.label} (${locale.toUpperCase()})',
                    initialValue: widget.initial[locale] ?? '',
                    minLines: widget.minLines,
                    onChanged: (v) => _set(locale, v),
                  )
                : TextField(
                    controller: _controller(locale),
                    minLines: widget.minLines,
                    maxLines: widget.minLines > 1 ? null : 1,
                    decoration: InputDecoration(
                      labelText: '${widget.label} (${locale.toUpperCase()})',
                    ),
                    onChanged: (v) => _set(locale, v),
                  ),
          ),
      ],
    );
  }
}
