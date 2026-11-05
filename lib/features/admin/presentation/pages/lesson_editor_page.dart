import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../domain/lesson_doc.dart';
import '../../domain/localized_text.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/file_io.dart';
import '../widgets/localized_fields.dart';
import '../widgets/storage_image.dart';

/// Structured lesson editor (`lessons/{id}`). New lessons get their id up
/// front so media can be uploaded to `lesson_media/{lessonId}/` before the
/// first save.
class LessonEditorPage extends ConsumerStatefulWidget {
  const LessonEditorPage({super.key, required this.lessonId, this.subjectId});

  /// Document id, or `new`.
  final String lessonId;
  final String? subjectId;

  @override
  ConsumerState<LessonEditorPage> createState() => _LessonEditorPageState();
}

class _Item<T> {
  _Item(this.value);
  T value;
}

class _LessonEditorPageState extends ConsumerState<LessonEditorPage> {
  late final bool _isNew = widget.lessonId == 'new';
  late Future<LessonDoc?> _load = _isNew
      ? Future.value(LessonDoc(id: ref.read(lessonsRepoProvider).newId(), subjectId: widget.subjectId ?? ''))
      : ref.read(lessonsRepoProvider).get(widget.lessonId);

  LessonDoc? _original;
  late LessonDoc _doc;
  Map<String, String> _title = {};
  Map<String, String> _summary = {};
  final List<_Item<LessonSection>> _sections = [];
  final List<_Item<LessonFormula>> _formulas = [];
  final List<_Item<LessonExample>> _examples = [];
  final List<_Item<Map<String, String>>> _mistakes = [];
  final _order = TextEditingController();
  final _minutes = TextEditingController();
  final _practiceIds = TextEditingController();
  final _video = TextEditingController();
  final _pdf = TextEditingController();
  bool _saving = false;
  bool _uploading = false;

  void _init(LessonDoc doc) {
    if (_original != null) return;
    _original = doc;
    _doc = doc;
    _title = {...doc.title};
    _summary = {...doc.summary};
    _sections.addAll(doc.sections.map(_Item.new));
    _formulas.addAll(doc.formulas.map(_Item.new));
    _examples.addAll(doc.examples.map(_Item.new));
    _mistakes.addAll(doc.commonMistakes.map(_Item.new));
    _order.text = '${doc.order}';
    _minutes.text = '${doc.estimatedMinutes}';
    _practiceIds.text = doc.practiceQuestionIds.join(', ');
    _video.text = doc.videoUrl ?? '';
    _pdf.text = doc.pdfUrl ?? '';
  }

  @override
  void dispose() {
    for (final c in [_order, _minutes, _practiceIds, _video, _pdf]) {
      c.dispose();
    }
    super.dispose();
  }

  LessonDoc _collect() {
    final o = _original!;
    String? nn(String s) => s.trim().isEmpty ? null : s.trim();
    return _doc.copyWith(
      title: mergeLocalized(o.title, _title),
      summary: mergeLocalized(o.summary, _summary),
      sections: [for (final s in _sections) if (!s.value.isEmpty) s.value],
      formulas: [for (final f in _formulas) if (!f.value.isEmpty) f.value],
      examples: [for (final e in _examples) if (!e.value.isEmpty) e.value],
      commonMistakes: [for (final m in _mistakes) if (m.value.isNotEmpty) m.value],
      practiceQuestionIds: _practiceIds.text
          .split(RegExp(r'[\s,;]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(),
      order: int.tryParse(_order.text.trim()) ?? -1,
      estimatedMinutes: int.tryParse(_minutes.text.trim()) ?? 0,
      videoUrl: nn(_video.text),
      clearVideo: nn(_video.text) == null,
      pdfUrl: nn(_pdf.text),
      clearPdf: nn(_pdf.text) == null,
    );
  }

  String _issueText(AppLocalizations l, String code) => switch (code) {
        LessonIssue.subjectRequired => l.adminLessonIssueSubject,
        LessonIssue.titleRequired => l.adminTitleRequired,
        LessonIssue.contentRequired => l.adminLessonIssueContent,
        LessonIssue.minutesRange => l.adminLessonIssueMinutes,
        LessonIssue.orderRange => l.adminLessonIssueOrder,
        LessonIssue.urlInvalid => l.adminLessonIssueUrl,
        _ => code,
      };

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final doc = _collect();
    final issues = doc.validate();
    if (issues.isNotEmpty) {
      showAdminSnack(context, issues.map((c) => _issueText(l, c)).join('\n'), error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(lessonsRepoProvider).save(doc, isNew: _isNew, actor: ref.read(adminActorProvider));
      if (!mounted) return;
      showAdminSnack(context, l.adminSaved);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAdminSnack(context, adminErrorMessage(l, e), error: true);
      }
    }
  }

  Future<void> _upload({required bool pdf}) async {
    final l = AppLocalizations.of(context)!;
    final picked = await pickFileBytes(images: !pdf, extensions: pdf ? const ['pdf'] : null);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final path = await ref.read(mediaRepoProvider).upload(
            folder: 'lesson_media',
            ownerId: _doc.id,
            fileName: picked.name,
            bytes: picked.bytes,
          );
      if (!mounted) return;
      setState(() {
        if (pdf) {
          _pdf.text = path;
        } else {
          _doc = _doc.copyWith(images: [..._doc.images, path]);
        }
      });
      showAdminSnack(context, l.adminUploaded);
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<LessonDoc?>(
      future: _load,
      builder: (context, snap) {
        Widget body;
        if (snap.hasError) {
          body = AdminErrorView(
            error: snap.error!,
            onRetry: () => setState(() => _load = ref.read(lessonsRepoProvider).get(widget.lessonId)),
          );
        } else if (snap.connectionState != ConnectionState.done) {
          body = const AdminLoadingView();
        } else if (snap.data == null) {
          body = AdminEmptyView(message: l.adminErrNotFound);
        } else {
          _init(snap.data!);
          body = _form(l);
        }
        final ready = _original != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(_isNew ? l.adminLessonsNew : l.adminLessonsEdit),
            actions: [
              if (ready)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilledButton(
                    onPressed: _saving || _uploading ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.adminSave),
                  ),
                ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  Widget _form(AppLocalizations l) {
    final locale = Localizations.localeOf(context).languageCode;
    final subjects = ref.watch(adminSubjectsProvider).valueOrNull ?? const [];
    final subject = subjects.where((s) => s.id == _doc.subjectId).firstOrNull;
    final topics = subject?.topics ?? const [];
    return AdminPageBody(
      maxWidth: 900,
      children: [
        AdminCard(
          title: l.adminLessonBasics,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  AdminDropdown<String>(
                    label: l.adminFieldSubject,
                    value: _doc.subjectId.isEmpty ? null : _doc.subjectId,
                    width: 260,
                    items: {
                      for (final s in subjects) s.id: '${localizedOf(s.title, locale)} (${s.id})',
                      if (_doc.subjectId.isNotEmpty && subject == null) _doc.subjectId: _doc.subjectId,
                    },
                    onChanged: (v) => setState(
                        () => _doc = _doc.copyWith(subjectId: v ?? '', clearTopic: true)),
                  ),
                  AdminDropdown<String>(
                    label: l.adminFieldTopic,
                    value: _doc.topicId,
                    width: 260,
                    allLabel: l.adminNone,
                    items: {
                      for (final t in topics) t.id: localizedOf(t.title, locale).isEmpty ? t.id : localizedOf(t.title, locale),
                      if (_doc.topicId != null && !topics.any((t) => t.id == _doc.topicId))
                        _doc.topicId!: _doc.topicId!,
                    },
                    onChanged: (v) => setState(() => _doc = _doc.copyWith(topicId: v, clearTopic: v == null)),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _order,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: l.adminFieldOrder),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: l.adminLessonMinutes),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _doc.isPublished,
                title: Text(l.adminPublished),
                subtitle: Text(l.adminLessonPublishedHelp),
                onChanged: (v) => setState(() => _doc = _doc.copyWith(isPublished: v)),
              ),
            ],
          ),
        ),
        AdminCard(
          title: l.adminLessonTitleSummary,
          child: Column(children: [
            LocalizedFields(label: l.adminFieldTitle, initial: _title, onChanged: (v) => _title = v),
            LocalizedFields(
              label: l.adminLessonSummary,
              initial: _summary,
              math: true,
              minLines: 3,
              onChanged: (v) => _summary = v,
            ),
          ]),
        ),
        _ListCard<LessonSection>(
          title: l.adminLessonSections,
          items: _sections,
          addLabel: l.adminLessonAddSection,
          create: () => const LessonSection(),
          onChanged: () => setState(() {}),
          itemBuilder: (item) => Column(children: [
            LocalizedFields(
              label: l.adminLessonSectionTitle,
              initial: item.value.title,
              onChanged: (v) => item.value = LessonSection(title: v, body: item.value.body),
            ),
            LocalizedFields(
              label: l.adminLessonSectionBody,
              initial: item.value.body,
              math: true,
              minLines: 4,
              onChanged: (v) => item.value = LessonSection(title: item.value.title, body: v),
            ),
          ]),
        ),
        _ListCard<LessonFormula>(
          title: l.adminLessonFormulas,
          items: _formulas,
          addLabel: l.adminLessonAddFormula,
          create: () => const LessonFormula(),
          onChanged: () => setState(() {}),
          itemBuilder: (item) => _FormulaEditor(item: item),
        ),
        _ListCard<LessonExample>(
          title: l.adminLessonExamples,
          items: _examples,
          addLabel: l.adminLessonAddExample,
          create: () => const LessonExample(),
          onChanged: () => setState(() {}),
          itemBuilder: (item) => Column(children: [
            LocalizedFields(
              label: l.adminLessonProblem,
              initial: item.value.problem,
              math: true,
              minLines: 2,
              onChanged: (v) => item.value = LessonExample(problem: v, solution: item.value.solution),
            ),
            LocalizedFields(
              label: l.adminLessonSolution,
              initial: item.value.solution,
              math: true,
              minLines: 3,
              onChanged: (v) => item.value = LessonExample(problem: item.value.problem, solution: v),
            ),
          ]),
        ),
        _ListCard<Map<String, String>>(
          title: l.adminLessonMistakes,
          items: _mistakes,
          addLabel: l.adminLessonAddMistake,
          create: () => <String, String>{},
          onChanged: () => setState(() {}),
          itemBuilder: (item) => LocalizedFields(
            label: l.adminLessonMistake,
            initial: item.value,
            math: true,
            onChanged: (v) => item.value = v,
          ),
        ),
        AdminCard(
          title: l.adminLessonPracticeAndMedia,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _practiceIds,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l.adminLessonPracticeIds,
                  helperText: l.adminLessonPracticeIdsHelp,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _video,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: l.adminLessonVideoUrl),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pdf,
                      decoration: InputDecoration(
                        labelText: l.adminLessonPdf,
                        helperText: l.adminLessonPdfHelp,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.outlined(
                    tooltip: l.adminUploadPdf,
                    onPressed: _uploading ? null : () => _upload(pdf: true),
                    icon: const Icon(Icons.upload_file),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: Text(l.adminLessonImages, style: Theme.of(context).textTheme.titleSmall)),
                  TextButton.icon(
                    onPressed: _uploading ? null : () => _upload(pdf: false),
                    icon: _uploading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(l.adminUploadImage),
                  ),
                ],
              ),
              if (_doc.images.isEmpty)
                Text(l.adminLessonNoImages, style: TextStyle(color: context.tokens.textTertiary))
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final img in _doc.images)
                      Stack(
                        children: [
                          StorageImage(img),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              tooltip: l.adminRemove,
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() => _doc = _doc.copyWith(
                                  images: _doc.images.where((i) => i != img).toList())),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormulaEditor extends StatefulWidget {
  const _FormulaEditor({required this.item});
  final _Item<LessonFormula> item;

  @override
  State<_FormulaEditor> createState() => _FormulaEditorState();
}

class _FormulaEditorState extends State<_FormulaEditor> {
  late final _latex = TextEditingController(text: widget.item.value.latex);

  @override
  void dispose() {
    _latex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _latex,
          maxLines: null,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(labelText: l.adminLessonLatex),
          onChanged: (v) => widget.item.value = LessonFormula(latex: v, caption: widget.item.value.caption),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _latex,
          builder: (context, v, _) => v.text.trim().isEmpty
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: context.tokens.surfaceMuted, borderRadius: AppRadii.smAll),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Math.tex(
                      v.text,
                      mathStyle: MathStyle.display,
                      onErrorFallback: (e) =>
                          Text(e.message, style: TextStyle(color: context.tokens.danger)),
                    ),
                  ),
                ),
        ),
        LocalizedFields(
          label: l.adminLessonCaption,
          initial: widget.item.value.caption,
          onChanged: (v) => widget.item.value = LessonFormula(latex: widget.item.value.latex, caption: v),
        ),
      ],
    );
  }
}

/// Card with an editable, reorderable list of items.
class _ListCard<T> extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.items,
    required this.addLabel,
    required this.create,
    required this.itemBuilder,
    required this.onChanged,
  });

  final String title;
  final List<_Item<T>> items;
  final String addLabel;
  final T Function() create;
  final Widget Function(_Item<T> item) itemBuilder;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AdminCard(
      title: title,
      trailing: TextButton.icon(
        onPressed: () {
          items.add(_Item(create()));
          onChanged();
        },
        icon: const Icon(Icons.add),
        label: Text(addLabel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Text(l.adminListNoItems, style: TextStyle(color: context.tokens.textTertiary)),
          for (var i = 0; i < items.length; i++)
            Container(
              key: ObjectKey(items[i]),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: context.tokens.border),
                borderRadius: AppRadii.smAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('#${i + 1}', style: Theme.of(context).textTheme.labelLarge)),
                      IconButton(
                        tooltip: l.adminMoveUp,
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: i == 0
                            ? null
                            : () {
                                items.insert(i - 1, items.removeAt(i));
                                onChanged();
                              },
                      ),
                      IconButton(
                        tooltip: l.adminMoveDown,
                        icon: const Icon(Icons.arrow_downward),
                        onPressed: i == items.length - 1
                            ? null
                            : () {
                                items.insert(i + 1, items.removeAt(i));
                                onChanged();
                              },
                      ),
                      IconButton(
                        tooltip: l.adminRemove,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          items.removeAt(i);
                          onChanged();
                        },
                      ),
                    ],
                  ),
                  itemBuilder(items[i]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
