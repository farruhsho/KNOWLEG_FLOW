import 'package:flutter/material.dart';
import '../../core/utils/content_locale.dart';
import '../../l10n/app_localizations.dart';
import '../models/subject_model.dart';
import 'subject_icon.dart';

/// Searches the already-loaded subjects (no extra Firestore reads) by title
/// in every language. Returns the chosen subject; the caller navigates.
class SubjectSearchDelegate extends SearchDelegate<SubjectModel?> {
  final List<SubjectModel> subjects;

  SubjectSearchDelegate({required this.subjects});

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const BackButtonIcon(),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = contentLanguageOf(context);
    final q = query.trim().toLowerCase();
    final found = q.isEmpty
        ? subjects
        : subjects
            .where((s) => s.title.values.any((t) => t.toLowerCase().contains(q)) || s.id.contains(q))
            .toList();
    if (found.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.learnNoSearchResults, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: found.length,
      itemBuilder: (context, i) {
        final s = found[i];
        return ListTile(
          leading: SubjectIcon(icon: s.icon, subjectId: s.id),
          title: Text(s.getTitle(lang)),
          subtitle: s.getDescription(lang).isEmpty
              ? null
              : Text(s.getDescription(lang), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => close(context, s),
        );
      },
    );
  }
}
