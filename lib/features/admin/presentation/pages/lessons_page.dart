import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../domain/lesson_doc.dart';
import '../../domain/localized_text.dart';
import '../widgets/admin_widgets.dart';

/// Single lessons manager over `lessons` (CMS-13/FB-21: the duplicate
/// `daily_lessons` manager was removed).
class LessonsPage extends ConsumerStatefulWidget {
  const LessonsPage({super.key});

  @override
  ConsumerState<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends ConsumerState<LessonsPage> {
  String? _subjectId;

  Future<void> _open(String id) async {
    final subject = _subjectId;
    final changed = await context.push<bool>(
      '/admin/lessons/$id${subject == null ? '' : '?subject=$subject'}',
    );
    if (changed == true && subject != null) ref.invalidate(lessonsBySubjectProvider(subject));
  }

  Future<void> _delete(LessonDoc lesson) async {
    final l = AppLocalizations.of(context)!;
    final ok = await confirmAdminAction(
      context,
      title: l.adminLessonsDeleteTitle,
      message: l.adminLessonsDeleteBody,
      confirmLabel: l.adminDelete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(lessonsRepoProvider).delete(lesson.id);
      ref.invalidate(lessonsBySubjectProvider(lesson.subjectId));
      if (mounted) showAdminSnack(context, l.adminDeleted);
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final subjects = ref.watch(adminSubjectsProvider);
    return Scaffold(
      floatingActionButton: _subjectId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _open('new'),
              icon: const Icon(Icons.add),
              label: Text(l.adminLessonsNew),
            ),
      body: AsyncBody(
        value: subjects,
        onRetry: () => ref.invalidate(adminSubjectsProvider),
        data: (list) {
          if (list.isEmpty) return AdminEmptyView(message: l.adminLessonsNoSubjects);
          final selected = _subjectId ?? list.first.id;
          if (_subjectId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _subjectId == null) setState(() => _subjectId = selected);
            });
          }
          return Column(
            children: [
              AdminFilterBar(children: [
                AdminDropdown<String>(
                  label: l.adminFieldSubject,
                  value: selected,
                  width: 260,
                  items: {for (final s in list) s.id: '${localizedOf(s.title, locale)} (${s.id})'},
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
              ]),
              Expanded(child: _LessonList(subjectId: selected, onOpen: _open, onDelete: _delete)),
            ],
          );
        },
      ),
    );
  }
}

class _LessonList extends ConsumerWidget {
  const _LessonList({required this.subjectId, required this.onOpen, required this.onDelete});
  final String subjectId;
  final ValueChanged<String> onOpen;
  final ValueChanged<LessonDoc> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final lessons = ref.watch(lessonsBySubjectProvider(subjectId));
    return AsyncBody(
      value: lessons,
      onRetry: () => ref.invalidate(lessonsBySubjectProvider(subjectId)),
      data: (list) => list.isEmpty
          ? AdminEmptyView(message: l.adminLessonsEmpty)
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(AppSpacing.gutter(context), AppSpacing.sm,
                  AppSpacing.gutter(context), AppSpacing.huge * 2),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final lesson = list[i];
                final structured = lesson.raw['sections'] is List;
                return AdminListTile(
                  title: localizedOf(lesson.title, locale).isEmpty
                      ? lesson.id
                      : localizedOf(lesson.title, locale),
                  subtitle: l.adminLessonsMeta(lesson.order, lesson.estimatedMinutes),
                  leading: CircleAvatar(child: Text('${lesson.order}')),
                  chips: [
                    AdminPill(lesson.isPublished ? l.adminPublished : l.adminHidden,
                        tone: lesson.isPublished ? AdminTone.success : AdminTone.neutral),
                    if (!structured) AdminPill(l.adminLessonsLegacy, tone: AdminTone.warning),
                    for (final loc in const ['ru', 'ky'])
                      if (!(lesson.title[loc]?.isNotEmpty ?? false))
                        AdminPill(l.adminMissingTranslation(loc.toUpperCase()),
                            tone: AdminTone.warning),
                  ],
                  onTap: () => onOpen(lesson.id),
                  trailing: IconButton(
                    tooltip: l.adminDelete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(lesson),
                  ),
                );
              },
            ),
    );
  }
}
