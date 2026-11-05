import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../data/repositories/exam_repositories.dart';
import '../../domain/blueprint_spec.dart';
import '../../domain/exam_question.dart';
import '../../domain/review_workflow.dart';
import '../widgets/admin_widgets.dart';

/// Section id → label, and subject ids, collected from all blueprints.
({Map<String, String> sections, Map<String, String> subjects}) blueprintChoices(
  List<BlueprintSpec> blueprints,
  String locale,
) {
  final sections = <String, String>{};
  final subjects = <String, String>{};
  for (final b in blueprints) {
    for (final s in b.sections) {
      sections.putIfAbsent(s.id, () => '${pickLocalized(s.title, locale)} (${s.id})');
      final subject = b.subjectIdFor(s);
      subjects.putIfAbsent(subject, () => subject);
    }
  }
  return (sections: sections, subjects: subjects);
}

/// Exam bank (`exam_questions`, ARCHITECTURE.md §1.3): paginated list with
/// subject / section / topic / difficulty / language / review filters.
class ExamBankPage extends ConsumerStatefulWidget {
  const ExamBankPage({super.key});

  @override
  ConsumerState<ExamBankPage> createState() => _ExamBankPageState();
}

class _ExamBankPageState extends ConsumerState<ExamBankPage> {
  ExamBankFilter _f = kEmptyExamBankFilter;
  final _topic = TextEditingController();

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  void _set({
    Object? subjectId = _keep,
    Object? sectionId = _keep,
    Object? topicId = _keep,
    Object? difficulty = _keep,
    Object? language = _keep,
    Object? reviewStatus = _keep,
  }) {
    T? pick<T>(Object? v, T? old) => identical(v, _keep) ? old : v as T?;
    setState(() => _f = (
          subjectId: pick<String>(subjectId, _f.subjectId),
          sectionId: pick<String>(sectionId, _f.sectionId),
          partId: null,
          topicId: pick<String>(topicId, _f.topicId),
          difficulty: pick<int>(difficulty, _f.difficulty),
          language: pick<String>(language, _f.language),
          reviewStatus: pick<String>(reviewStatus, _f.reviewStatus),
        ));
  }

  Future<void> _open(String id) async {
    final changed = await context.push<bool>('/admin/exam-bank/$id');
    if (changed == true) ref.read(examBankPageProvider(_f).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final blueprints = ref.watch(adminBlueprintsProvider).valueOrNull ?? const [];
    final choices = blueprintChoices(blueprints, locale);
    final state = ref.watch(examBankPageProvider(_f));
    final notifier = ref.read(examBankPageProvider(_f).notifier);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open('new'),
        icon: const Icon(Icons.add),
        label: Text(l.adminExamNew),
      ),
      body: Column(
        children: [
          AdminFilterBar(children: [
            AdminDropdown<String>(
              label: l.adminFieldSubject,
              value: _f.subjectId,
              allLabel: l.adminAll,
              width: 160,
              items: choices.subjects,
              onChanged: (v) => _set(subjectId: v),
            ),
            AdminDropdown<String>(
              label: l.adminFieldSection,
              value: _f.sectionId,
              allLabel: l.adminAll,
              width: 200,
              items: choices.sections,
              onChanged: (v) => _set(sectionId: v),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _topic,
                decoration: InputDecoration(
                  labelText: l.adminFieldTopic,
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: l.adminApply,
                    icon: const Icon(Icons.search),
                    onPressed: () => _set(topicId: _topic.text.trim().isEmpty ? null : _topic.text.trim()),
                  ),
                ),
                onSubmitted: (v) => _set(topicId: v.trim().isEmpty ? null : v.trim()),
              ),
            ),
            AdminDropdown<int>(
              label: l.adminFieldDifficulty,
              value: _f.difficulty,
              allLabel: l.adminAll,
              width: 140,
              items: {1: l.adminDifficulty1, 2: l.adminDifficulty2, 3: l.adminDifficulty3},
              onChanged: (v) => _set(difficulty: v),
            ),
            AdminDropdown<String>(
              label: l.adminFieldLanguage,
              value: _f.language,
              allLabel: l.adminAll,
              width: 150,
              items: {for (final c in kExamLanguages) c: languageLabel(l, c)},
              onChanged: (v) => _set(language: v),
            ),
            AdminDropdown<String>(
              label: l.adminFieldReview,
              value: _f.reviewStatus,
              allLabel: l.adminAll,
              width: 170,
              items: {for (final s in ReviewStatus.values) s.wire: reviewStatusLabel(l, s)},
              onChanged: (v) => _set(reviewStatus: v),
            ),
          ]),
          Expanded(
            child: PagedListBody<ExamQuestionDoc>(
              state: state,
              onLoadMore: notifier.loadMore,
              onRetry: notifier.retry,
              onRefresh: notifier.refresh,
              emptyMessage: l.adminExamEmpty,
              itemBuilder: (context, q) => AdminListTile(
                title: q.stem.trim().isEmpty ? q.id : q.stem.trim().split('\n').first,
                subtitle: [
                  q.sectionId,
                  if (q.partId != null) q.partId!,
                  q.topicId,
                  l.adminDifficultyN(q.difficulty),
                ].join(' · '),
                chips: [
                  AdminPill(reviewStatusLabel(l, q.review.status), tone: reviewStatusTone(q.review.status)),
                  AdminPill(q.language.toUpperCase(), tone: AdminTone.info),
                  if (q.translationGroupId != null) AdminPill(l.adminExamHasTranslation),
                  if (q.source.kind == 'ai') AdminPill(l.adminExamSourceAi, tone: AdminTone.warning),
                  if (q.table != null) AdminPill(l.adminExamTable),
                  if (q.hasColumns) AdminPill(l.adminExamColumns),
                ],
                onTap: () => _open(q.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const Object _keep = Object();
