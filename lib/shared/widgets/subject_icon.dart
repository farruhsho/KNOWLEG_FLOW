import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';

/// Renders a subject's `icon` field (CMS-28).
///
/// Seed data stores Material icon *names* ("calculate", "history_edu");
/// older docs store emoji. Names are mapped to [IconData]; anything else that
/// is short is drawn as text (emoji); unknown values fall back to a subject
/// default by id.
class SubjectIcon extends StatelessWidget {
  final String icon;
  final String subjectId;
  final double size;
  final Color? color;

  const SubjectIcon({
    super.key,
    required this.icon,
    required this.subjectId,
    this.size = 24,
    this.color,
  });

  static const Map<String, IconData> _byName = {
    'calculate': Icons.calculate_outlined,
    'functions': Icons.functions,
    'math': Icons.calculate_outlined,
    'book': Icons.menu_book_outlined,
    'menu_book': Icons.menu_book_outlined,
    'auto_stories': Icons.auto_stories_outlined,
    'history_edu': Icons.history_edu_outlined,
    'history': Icons.history_edu_outlined,
    'language': Icons.translate,
    'translate': Icons.translate,
    'science': Icons.science_outlined,
    'biotech': Icons.biotech_outlined,
    'eco': Icons.eco_outlined,
    'bolt': Icons.bolt_outlined,
    'electric_bolt': Icons.bolt_outlined,
    'public': Icons.public,
    'spellcheck': Icons.spellcheck,
    'psychology': Icons.psychology_outlined,
    'school': Icons.school_outlined,
    'quiz': Icons.quiz_outlined,
    'chrome_reader_mode': Icons.chrome_reader_mode_outlined,
  };

  static const Map<String, IconData> _bySubject = {
    'math': Icons.calculate_outlined,
    'mathematics': Icons.calculate_outlined,
    'physics': Icons.bolt_outlined,
    'chemistry': Icons.science_outlined,
    'biology': Icons.biotech_outlined,
    'history': Icons.history_edu_outlined,
    'history_kg': Icons.history_edu_outlined,
    'english': Icons.translate,
    'kyrgyz': Icons.translate,
    'kyrgyz_lang': Icons.translate,
    'russian': Icons.translate,
    'russian_lang': Icons.translate,
    'analogies': Icons.psychology_outlined,
    'reading': Icons.chrome_reader_mode_outlined,
    'grammar': Icons.spellcheck,
  };

  /// IconData for a Material icon name or subject id, if known.
  static IconData? resolve(String icon, String subjectId) =>
      _byName[icon.trim().toLowerCase()] ?? (icon.trim().isEmpty ? _bySubject[subjectId] : null);

  @override
  Widget build(BuildContext context) {
    final c = color ?? SubjectColors.of(subjectId);
    final data = resolve(icon, subjectId);
    if (data != null) return Icon(data, size: size, color: c);
    final t = icon.trim();
    // Emoji / short glyphs; long unknown words would read as text, so use a default.
    if (t.isNotEmpty && t.runes.length <= 3 && !RegExp(r'^[a-z_]+$').hasMatch(t)) {
      return Text(t, style: TextStyle(fontSize: size * 0.9, height: 1.1));
    }
    return Icon(_bySubject[subjectId] ?? Icons.school_outlined, size: size, color: c);
  }
}
