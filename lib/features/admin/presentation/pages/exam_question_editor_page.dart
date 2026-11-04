import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/admin_access_provider.dart';
import '../../application/admin_providers.dart';
import '../../domain/admin_role.dart';
import '../../domain/blueprint_spec.dart';
import '../../domain/exam_question.dart';
import '../../domain/review_workflow.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/file_io.dart';
import '../widgets/math_markdown.dart';
import '../widgets/storage_image.dart';

String examIssueText(AppLocalizations l, String code, {int? expectedOptions}) => switch (code) {
      ExamQuestionIssue.sectionRequired => l.adminExamIssueSection,
      ExamQuestionIssue.topicRequired => l.adminExamIssueTopic,
      ExamQuestionIssue.languageInvalid => l.adminExamIssueLanguage,
      ExamQuestionIssue.difficultyRange => l.adminIssueDifficulty,
      ExamQuestionIssue.stemRequired => l.adminIssueStem,
      ExamQuestionIssue.optionsCount => l.adminExamIssueOptionsCount(expectedOptions ?? 2),
      ExamQuestionIssue.optionEmpty => l.adminIssueOptionEmpty,
      ExamQuestionIssue.optionDuplicate => l.adminExamIssueOptionDuplicate,
      ExamQuestionIssue.correctRequired => l.adminIssueCorrectRequired,
      ExamQuestionIssue.correctNotInOptions => l.adminIssueCorrectNotInOptions,
      ExamQuestionIssue.passageRequired => l.adminExamIssuePassage,
      _ => code,
    };

/// Editor for one exam bank question + its key (`exam_questions/{id}` +
/// `exam_question_keys/{id}`), with LaTeX preview, passage link, image upload
/// to `exam_media/{questionId}/`, ru↔ky translation linking and the review
/// workflow (approve / reject only with `review_questions`).
class ExamQuestionEditorPage extends ConsumerStatefulWidget {
  const ExamQuestionEditorPage({super.key, required this.questionId, this.prefill});

  /// Document id or `new`.
  final String questionId;

  /// Metadata for a new question (e.g. a translation of another question).
  final ExamQuestionDoc? prefill;

  @override
  ConsumerState<ExamQuestionEditorPage> createState() => _ExamQuestionEditorPageState();
}

class _ExamQuestionEditorPageState extends ConsumerState<ExamQuestionEditorPage> {
  late final bool _isNew = widget.questionId == 'new';
  late Future<({ExamQuestionDoc question, ExamKeyDoc key})?> _load = _fetch();

  ExamQuestionDoc? _savedQ;
  ExamKeyDoc _savedKey = const ExamKeyDoc();
  late ExamQuestionDoc _q;
  late ExamKeyDoc _key;
  String? _blueprintId;
  bool _dirty = false;
  bool _busy = false;
  final _notes = TextEditingController();
  final _topic = TextEditingController();
  final _subtopic = TextEditingController();
  final _basis = TextEditingController();
  final _author = TextEditingController();

  /// Bumped to rebuild text fields after programmatic changes.
  int _formEpoch = 0;

  Future<({ExamQuestionDoc question, ExamKeyDoc key})?> _fetch() {
    if (!_isNew) return ref.read(examBankRepoProvider).get(widget.questionId);
    final id = ref.read(examBankRepoProvider).newId();
    final p = widget.prefill;
    final q = p == null
        ? ExamQuestionDoc(id: id, subjectId: '', sectionId: '', topicId: '', language: 'ru', stem: '', options: const [])
        : ExamQuestionDoc(
            id: id,
            subjectId: p.subjectId,
            sectionId: p.sectionId,
            partId: p.partId,
            topicId: p.topicId,
            subtopicId: p.subtopicId,
            difficulty: p.difficulty,
            language: p.language,
            translationGroupId: p.translationGroupId,
            type: p.type,
            stem: '',
            options: const [],
            passageId: null,
            source: const ExamSource(kind: 'adapted'),
          );
    return Future.value((question: q, key: const ExamKeyDoc()));
  }

  void _init(({ExamQuestionDoc question, ExamKeyDoc key}) data, List<BlueprintSpec> blueprints) {
    if (_savedQ != null) return;
    _savedQ = data.question;
    _savedKey = data.key;
    _q = data.question;
    _key = data.key;
    _notes.text = _q.review.notes;
    _topic.text = _q.topicId;
    _subtopic.text = _q.subtopicId ?? '';
    _basis.text = _q.source.basis;
    _author.text = _q.source.author;
    _blueprintId = locateSection(blueprints, _q.subjectId, _q.sectionId)?.blueprint.id;
    if (_isNew) _applyPlacement(blueprints);
  }

  @override
  void dispose() {
    for (final c in [_notes, _topic, _subtopic, _basis, _author]) {
      c.dispose();
    }
    super.dispose();
  }

  BlueprintSpec? _blueprint(List<BlueprintSpec> all) =>
      all.where((b) => b.id == _blueprintId).firstOrNull;

  SectionSpec? _section(List<BlueprintSpec> all) => _blueprint(all)?.section(_q.sectionId);

  PartSpec? _part(List<BlueprintSpec> all) {
    final s = _section(all);
    if (s == null) return null;
    if (_q.partId != null) return s.part(_q.partId);
    return s.parts.length == 1 ? s.parts.first : null;
  }

  /// Aligns subject, type and the options list with the chosen placement.
  void _applyPlacement(List<BlueprintSpec> all) {
    final b = _blueprint(all);
    final s = _section(all);
    if (b == null || s == null) return;
    final part = _part(all);
    final expected = b.optionsFor(part);
    List<ExamOption> options;
    if (part != null && part.hasFixedOptions) {
      options = [for (final o in fixedOptionsFor(part, _q.language)) ExamOption(o.id, o.text)];
    } else {
      final current = {for (final o in _q.options) o.id: o.text};
      options = [
        for (final id in kExamOptionIds.take(expected))
          ExamOption(id, current[id] ?? ''),
      ];
    }
    _q = _q.copyWith(
      subjectId: b.subjectIdFor(s),
      type: part?.itemType ?? _q.type,
      options: options,
      partId: (s.parts.length > 1) ? part?.id : null,
      clearPart: s.parts.length <= 1,
    );
    if (!b.languages.contains(_q.language) && b.languages.isNotEmpty) {
      _q = _q.copyWith(language: b.languages.first);
    }
  }

  void _change(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  ExamQuestionDoc _collectQ() => _q.copyWith(
        topicId: _topic.text.trim(),
        subtopicId: _subtopic.text.trim().isEmpty ? null : _subtopic.text.trim(),
        clearSubtopic: _subtopic.text.trim().isEmpty,
        source: ExamSource(kind: _q.source.kind, basis: _basis.text.trim(), author: _author.text.trim()),
      );

  Future<void> _save(List<BlueprintSpec> blueprints) async {
    final l = AppLocalizations.of(context)!;
    final role = ref.read(adminRoleProvider);
    if (role == null) return;
    var q = _collectQ();
    final b = _blueprint(blueprints);
    final part = _part(blueprints);
    final expected = b?.optionsFor(part);
    final issues = validateExamQuestion(
      q,
      _key,
      expectedOptions: expected,
      needsPassage: part?.needsPassage ?? false,
    );
    if (issues.isNotEmpty) {
      showAdminSnack(
        context,
        issues.map((c) => examIssueText(l, c, expectedOptions: expected)).join('\n'),
        error: true,
      );
      return;
    }
    final saved = _savedQ!;
    final keyChanged = _key.correct != _savedKey.correct;
    final contentChanged = _isNew || q.contentDiffers(saved) || keyChanged;
    final current = _isNew ? ReviewStatus.draft : saved.review.status;
    final next = contentChanged && !_isNew
        ? ReviewWorkflow.statusAfterContentEdit(current, role)
        : current;
    q = q.copyWith(contentVersion: contentChanged && !_isNew ? saved.contentVersion + 1 : q.contentVersion);
    setState(() => _busy = true);
    try {
      await ref.read(examBankRepoProvider).save(
            q,
            _key,
            isNew: _isNew,
            actor: ref.read(adminActorProvider),
            review: next,
            reviewChanged: next != current,
          );
      if (!mounted) return;
      showAdminSnack(context, next != current ? l.adminExamSavedBackToDraft : l.adminSaved);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAdminSnack(context, adminErrorMessage(l, e), error: true);
      }
    }
  }

  Future<void> _review(ReviewStatus target) async {
    final l = AppLocalizations.of(context)!;
    if (target == ReviewStatus.methodologistApproved && !_savedKey.hasCorrect) {
      showAdminSnack(context, l.adminExamErrApproveNoKey, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(examBankRepoProvider).setReview(
            _savedQ!.id,
            target,
            actor: ref.read(adminActorProvider),
            notes: _notes.text.trim(),
          );
      if (!mounted) return;
      showAdminSnack(context, l.adminExamReviewDone(reviewStatusLabel(l, target)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAdminSnack(context, adminErrorMessage(l, e), error: true);
      }
    }
  }

  Future<void> _uploadImage() async {
    final l = AppLocalizations.of(context)!;
    final picked = await pickFileBytes(images: true);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final path = await ref.read(mediaRepoProvider).upload(
            folder: 'exam_media',
            ownerId: _q.id,
            fileName: picked.name,
            bytes: picked.bytes,
          );
      if (mounted) _change(() => _q = _q.copyWith(imagePath: path));
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createTranslation(String targetLanguage) async {
    final l = AppLocalizations.of(context)!;
    final saved = _savedQ!;
    try {
      final group = await ref.read(examBankRepoProvider).ensureGroup(saved.id, saved.translationGroupId);
      if (!mounted) return;
      final prefill = saved.copyWith(language: targetLanguage, translationGroupId: group);
      await context.push<bool>('/admin/exam-bank/new', extra: prefill);
      ref.invalidate(translationsProvider(group));
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  Future<void> _linkExisting() async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.adminExamLinkTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l.adminExamQuestionId),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.adminCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(l.adminExamLink)),
        ],
      ),
    );
    controller.dispose();
    if (id == null || id.isEmpty || id == _savedQ!.id || !mounted) return;
    try {
      final group = await ref.read(examBankRepoProvider).link(_savedQ!.id, _savedQ!.translationGroupId, id);
      if (!mounted) return;
      setState(() {
        _savedQ = _savedQ!.copyWith(translationGroupId: group);
        _q = _q.copyWith(translationGroupId: group);
      });
      ref.invalidate(translationsProvider(group));
      showAdminSnack(context, l.adminExamLinked);
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  Future<void> _newPassage() async {
    final l = AppLocalizations.of(context)!;
    final title = TextEditingController();
    final text = TextEditingController();
    final source = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.adminExamNewPassage),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: InputDecoration(labelText: l.adminFieldTitle)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: text,
                minLines: 6,
                maxLines: null,
                decoration: InputDecoration(labelText: l.adminExamPassageText),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: source, decoration: InputDecoration(labelText: l.adminExamSourceBasis)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.adminCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.adminSave)),
        ],
      ),
    );
    final repo = ref.read(examBankRepoProvider);
    final passage = ExamPassageDoc(
      id: repo.newPassageId(),
      language: _q.language,
      subjectId: _q.subjectId,
      sectionId: _q.sectionId,
      title: title.text.trim(),
      text: text.text.trim(),
      source: source.text.trim(),
    );
    title.dispose();
    text.dispose();
    source.dispose();
    if (ok != true || !mounted) return;
    if (passage.text.isEmpty) {
      showAdminSnack(context, l.adminExamPassageEmpty, error: true);
      return;
    }
    try {
      await repo.savePassage(passage, actor: ref.read(adminActorProvider));
      if (!mounted) return;
      ref.invalidate(passagesProvider((sectionId: _q.sectionId, language: _q.language)));
      _change(() => _q = _q.copyWith(passageId: passage.id));
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final blueprintsAsync = ref.watch(adminBlueprintsProvider);
    return FutureBuilder<({ExamQuestionDoc question, ExamKeyDoc key})?>(
      future: _load,
      builder: (context, snap) {
        Widget body;
        final err = snap.error ?? blueprintsAsync.error;
        if (err != null) {
          body = AdminErrorView(
            error: err,
            onRetry: () {
              ref.invalidate(adminBlueprintsProvider);
              setState(() => _load = _fetch());
            },
          );
        } else if (snap.connectionState != ConnectionState.done || !blueprintsAsync.hasValue) {
          body = const AdminLoadingView();
        } else if (snap.data == null) {
          body = AdminEmptyView(message: l.adminErrNotFound);
        } else {
          _init(snap.data!, blueprintsAsync.requireValue);
          body = _form(l, blueprintsAsync.requireValue);
        }
        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final leave = await confirmAdminAction(
              context,
              title: l.adminUnsavedTitle,
              message: l.adminUnsavedBody,
              confirmLabel: l.adminDiscard,
              destructive: true,
            );
            if (leave && context.mounted) {
              setState(() => _dirty = false);
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_isNew ? l.adminExamNew : l.adminExamEdit),
              actions: [
                if (_savedQ != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilledButton(
                      onPressed: _busy ? null : () => _save(blueprintsAsync.requireValue),
                      child: Text(l.adminSave),
                    ),
                  ),
              ],
            ),
            body: body,
          ),
        );
      },
    );
  }

  Widget _form(AppLocalizations l, List<BlueprintSpec> blueprints) {
    final locale = Localizations.localeOf(context).languageCode;
    final role = ref.watch(adminRoleProvider) ?? AdminRole.support;
    final b = _blueprint(blueprints);
    final s = _section(blueprints);
    final part = _part(blueprints);
    final fixed = part?.hasFixedOptions ?? false;
    final showPassage = (part?.needsPassage ?? false) || (s?.usesPassages ?? false) || _q.passageId != null;
    final subjects = ref.watch(adminSubjectsProvider).valueOrNull ?? const [];
    final topics = subjects.where((x) => x.id == _q.subjectId).firstOrNull?.topics ?? const [];
    return AdminPageBody(
      maxWidth: 960,
      children: [
        if (!_isNew)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
              AdminPill(reviewStatusLabel(l, _savedQ!.review.status),
                  tone: reviewStatusTone(_savedQ!.review.status)),
              AdminPill('id: ${_q.id}'),
              AdminPill('v${_q.contentVersion}'),
            ]),
          ),
        AdminCard(
          title: l.adminExamPlacement,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  AdminDropdown<String>(
                    label: l.adminFieldBlueprint,
                    value: _blueprintId,
                    width: 260,
                    items: {for (final x in blueprints) x.id: pickLocalized(x.title, locale)},
                    onChanged: (v) => _change(() {
                      _blueprintId = v;
                      final first = _blueprint(blueprints)?.sections.firstOrNull;
                      _q = _q.copyWith(sectionId: first?.id ?? '', clearPart: true);
                      _applyPlacement(blueprints);
                      _formEpoch++;
                    }),
                  ),
                  if (b != null)
                    AdminDropdown<String>(
                      label: l.adminFieldSection,
                      value: s?.id,
                      width: 220,
                      items: {for (final x in b.sections) x.id: pickLocalized(x.title, locale)},
                      onChanged: (v) => _change(() {
                        _q = _q.copyWith(sectionId: v ?? '', clearPart: true);
                        _applyPlacement(blueprints);
                        _formEpoch++;
                      }),
                    ),
                  if (s != null && s.parts.length > 1)
                    AdminDropdown<String>(
                      label: l.adminFieldPart,
                      value: _q.partId,
                      width: 260,
                      items: {for (final p in s.parts) p.id: pickLocalized(p.title, locale)},
                      onChanged: (v) => _change(() {
                        _q = _q.copyWith(partId: v);
                        _applyPlacement(blueprints);
                        _formEpoch++;
                      }),
                    ),
                  AdminDropdown<String>(
                    label: l.adminFieldLanguage,
                    value: _q.language.isEmpty ? null : _q.language,
                    width: 160,
                    items: {
                      for (final c in (b?.languages ?? kExamLanguages)) c: languageLabel(l, c),
                    },
                    onChanged: (v) => _change(() {
                      _q = _q.copyWith(language: v ?? _q.language);
                      if (fixed) _applyPlacement(blueprints);
                    }),
                  ),
                  AdminDropdown<int>(
                    label: l.adminFieldDifficulty,
                    value: _q.difficulty,
                    width: 150,
                    items: {1: l.adminDifficulty1, 2: l.adminDifficulty2, 3: l.adminDifficulty3},
                    onChanged: (v) => _change(() => _q = _q.copyWith(difficulty: v ?? _q.difficulty)),
                  ),
                ],
              ),
              if (b == null && !_isNew)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(l.adminExamNoBlueprint(_q.subjectId, _q.sectionId),
                      style: TextStyle(color: context.tokens.warning)),
                ),
              if (part != null && !part.verified)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(l.adminExamPartUnverified,
                      style: TextStyle(color: context.tokens.textSecondary)),
                ),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _topic,
                    decoration: InputDecoration(labelText: l.adminFieldTopicId, helperText: l.adminFieldTopicIdHelp),
                    onChanged: (_) => _dirty = true,
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _subtopic,
                    decoration: InputDecoration(labelText: l.adminFieldSubtopicId),
                    onChanged: (_) => _dirty = true,
                  ),
                ),
              ]),
              if (topics.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                  for (final t in topics)
                    ActionChip(
                      label: Text(pickLocalized(t.title, locale).isEmpty ? t.id : pickLocalized(t.title, locale)),
                      onPressed: () => _change(() => _topic.text = t.id),
                    ),
                ]),
              ],
            ],
          ),
        ),
        AdminCard(
          title: l.adminFieldStem,
          child: MathTextField(
            key: ValueKey('stem$_formEpoch'),
            label: l.adminExamStemLabel,
            helper: l.adminMathHelp,
            initialValue: _q.stem,
            minLines: 3,
            onChanged: (v) {
              _q = _q.copyWith(stem: v);
              _dirty = true;
            },
          ),
        ),
        if (showPassage) _passageCard(l),
        _imageCard(l),
        _optionsCard(l, fixed),
        _keyCard(l),
        _sourceCard(l),
        if (!_isNew) _translationCard(l),
        if (!_isNew) _reviewCard(l, role),
      ],
    );
  }

  Widget _passageCard(AppLocalizations l) {
    final passages = ref.watch(passagesProvider((sectionId: _q.sectionId, language: _q.language)));
    return AdminCard(
      title: l.adminExamPassage,
      trailing: TextButton.icon(
        onPressed: _q.sectionId.isEmpty ? null : _newPassage,
        icon: const Icon(Icons.add),
        label: Text(l.adminExamNewPassage),
      ),
      child: passages.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => AdminErrorView(
          error: e,
          onRetry: () => ref.invalidate(passagesProvider((sectionId: _q.sectionId, language: _q.language))),
        ),
        data: (list) {
          final selected = list.where((p) => p.id == _q.passageId).firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDropdown<String>(
                label: l.adminExamPassage,
                value: _q.passageId,
                width: double.infinity,
                allLabel: l.adminNone,
                items: {
                  for (final p in list) p.id: p.title.isEmpty ? p.id : p.title,
                  if (_q.passageId != null && selected == null) _q.passageId!: _q.passageId!,
                },
                onChanged: (v) => _change(() => _q = _q.copyWith(passageId: v, clearPassage: v == null)),
              ),
              if (selected != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  selected.text.length > 400 ? '${selected.text.substring(0, 400)}…' : selected.text,
                  style: TextStyle(color: context.tokens.textSecondary),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _imageCard(AppLocalizations l) => AdminCard(
        title: l.adminExamImage,
        trailing: TextButton.icon(
          onPressed: _busy ? null : _uploadImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(l.adminUploadImage),
        ),
        child: _q.imagePath == null
            ? Text(l.adminExamNoImage, style: TextStyle(color: context.tokens.textTertiary))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StorageImage(_q.imagePath!, size: 120),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: SelectableText(_q.imagePath!)),
                  IconButton(
                    tooltip: l.adminRemove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _change(() => _q = _q.copyWith(clearImage: true)),
                  ),
                ],
              ),
      );

  Widget _optionsCard(AppLocalizations l, bool fixed) => AdminCard(
        title: l.adminFieldOptions,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(fixed ? l.adminExamFixedOptions : l.adminCorrectSingleHelp,
                style: TextStyle(color: context.tokens.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            if (_q.options.isEmpty)
              Text(l.adminExamChoosePlacement, style: TextStyle(color: context.tokens.warning)),
            for (var i = 0; i < _q.options.length; i++)
              Container(
                key: ValueKey('opt${_q.options[i].id}$_formEpoch'),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _key.correct == _q.options[i].id ? context.tokens.success : context.tokens.border,
                  ),
                  borderRadius: AppRadii.smAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: l.adminMarkCorrect,
                      color: _key.correct == _q.options[i].id ? context.tokens.success : null,
                      icon: Icon(_key.correct == _q.options[i].id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked),
                      onPressed: () => _change(() => _key = ExamKeyDoc(
                            correct: _q.options[i].id,
                            explanation: _key.explanation,
                            wrongOptionNotes: _key.wrongOptionNotes,
                            solutionSteps: _key.solutionSteps,
                          )),
                    ),
                    Expanded(
                      child: fixed
                          ? Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.md),
                              child: Text('${_q.options[i].id}. ${_q.options[i].text}'),
                            )
                          : MathTextField(
                              label: l.adminOptionN(_q.options[i].id),
                              initialValue: _q.options[i].text,
                              minLines: 1,
                              onChanged: (v) {
                                final opts = [..._q.options];
                                opts[i] = ExamOption(opts[i].id, v);
                                _q = _q.copyWith(options: opts);
                                _dirty = true;
                              },
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _keyCard(AppLocalizations l) {
    final wrong = _q.options.where((o) => o.id != _key.correct).toList();
    ExamKeyDoc withKey({String? explanation, Map<String, String>? notes, List<String>? steps}) => ExamKeyDoc(
          correct: _key.correct,
          explanation: explanation ?? _key.explanation,
          wrongOptionNotes: notes ?? _key.wrongOptionNotes,
          solutionSteps: steps ?? _key.solutionSteps,
        );
    return AdminCard(
      title: l.adminExamKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _key.hasCorrect ? l.adminExamCorrectIs(_key.correct) : l.adminIssueCorrectRequired,
            style: TextStyle(color: _key.hasCorrect ? context.tokens.success : context.tokens.warning),
          ),
          const SizedBox(height: AppSpacing.md),
          MathTextField(
            key: ValueKey('expl$_formEpoch'),
            label: l.adminFieldExplanation,
            initialValue: _key.explanation,
            minLines: 3,
            onChanged: (v) {
              _key = withKey(explanation: v);
              _dirty = true;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          for (final o in wrong)
            Padding(
              key: ValueKey('note${o.id}$_formEpoch'),
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: MathTextField(
                label: l.adminExamWrongNote(o.id),
                initialValue: _key.wrongOptionNotes[o.id] ?? '',
                minLines: 1,
                showPreview: false,
                onChanged: (v) {
                  final notes = {..._key.wrongOptionNotes};
                  if (v.trim().isEmpty) {
                    notes.remove(o.id);
                  } else {
                    notes[o.id] = v;
                  }
                  _key = withKey(notes: notes);
                  _dirty = true;
                },
              ),
            ),
          MathTextField(
            key: ValueKey('steps$_formEpoch'),
            label: l.adminExamSolutionSteps,
            helper: l.adminExamSolutionStepsHelp,
            initialValue: _key.solutionSteps.join('\n'),
            minLines: 2,
            onChanged: (v) {
              _key = withKey(
                steps: v.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
              );
              _dirty = true;
            },
          ),
        ],
      ),
    );
  }

  Widget _sourceCard(AppLocalizations l) => AdminCard(
        title: l.adminExamSource,
        child: Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
          AdminDropdown<String>(
            label: l.adminExamSourceKind,
            value: _q.source.kind,
            width: 200,
            items: {
              'original': l.adminExamSourceOriginal,
              'adapted': l.adminExamSourceAdapted,
              'ai': l.adminExamSourceAi,
            },
            onChanged: (v) => _change(() => _q = _q.copyWith(
                source: ExamSource(kind: v ?? 'original', basis: _basis.text, author: _author.text))),
          ),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _basis,
              decoration: InputDecoration(labelText: l.adminExamSourceBasis),
              onChanged: (_) => _dirty = true,
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _author,
              decoration: InputDecoration(labelText: l.adminExamSourceAuthor),
              onChanged: (_) => _dirty = true,
            ),
          ),
        ]),
      );

  Widget _translationCard(AppLocalizations l) {
    final group = _savedQ!.translationGroupId;
    final others = kExamLanguages.where((c) => c != _q.language && c != 'en').toList();
    return AdminCard(
      title: l.adminExamTranslations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(group == null ? l.adminExamNoGroup : l.adminExamGroup(group),
              style: TextStyle(color: context.tokens.textSecondary)),
          if (group != null)
            Consumer(builder: (context, ref, _) {
              final list = ref.watch(translationsProvider(group));
              return list.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(adminErrorMessage(l, e), style: TextStyle(color: context.tokens.danger)),
                data: (items) => Column(children: [
                  for (final t in items.where((t) => t.id != _q.id))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AdminPill(t.language.toUpperCase(), tone: AdminTone.info),
                      title: Text(t.stem.split('\n').first, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(reviewStatusLabel(l, t.review.status)),
                      onTap: () => context.push('/admin/exam-bank/${t.id}'),
                    ),
                ]),
              );
            }),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            for (final c in others)
              OutlinedButton.icon(
                onPressed: _busy || _dirty ? null : () => _createTranslation(c),
                icon: const Icon(Icons.translate),
                label: Text(l.adminExamCreateTranslation(languageLabel(l, c))),
              ),
            OutlinedButton.icon(
              onPressed: _busy || _dirty ? null : _linkExisting,
              icon: const Icon(Icons.link),
              label: Text(l.adminExamLinkTitle),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _reviewCard(AppLocalizations l, AdminRole role) {
    final current = _savedQ!.review.status;
    final targets = ReviewWorkflow.allowedTargets(current, role);
    String actionLabel(ReviewStatus s) => switch (s) {
          ReviewStatus.methodologistApproved => l.adminExamApprove,
          ReviewStatus.rejected => l.adminExamReject,
          ReviewStatus.draft => l.adminExamBackToDraft,
          ReviewStatus.aiVerified => l.adminExamMarkAiVerified,
        };
    return AdminCard(
      title: l.adminExamReview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
            AdminPill(reviewStatusLabel(l, current), tone: reviewStatusTone(current)),
            if (_savedQ!.review.reviewedBy != null)
              Text(l.adminExamReviewedBy(_savedQ!.review.reviewedBy!, formatAdminDate(_savedQ!.review.reviewedAt)),
                  style: TextStyle(color: context.tokens.textSecondary)),
          ]),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: null,
            decoration: InputDecoration(labelText: l.adminExamReviewNotes),
          ),
          const SizedBox(height: AppSpacing.md),
          if (targets.isEmpty)
            Text(l.adminExamReviewNoRights, style: TextStyle(color: context.tokens.textSecondary))
          else ...[
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(l.adminExamSaveBeforeReview, style: TextStyle(color: context.tokens.warning)),
              ),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              for (final t in targets)
                t == ReviewStatus.methodologistApproved
                    ? FilledButton.icon(
                        onPressed: _busy || _dirty ? null : () => _review(t),
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(actionLabel(t)),
                      )
                    : OutlinedButton(
                        onPressed: _busy || _dirty ? null : () => _review(t),
                        child: Text(actionLabel(t)),
                      ),
            ]),
          ],
        ],
      ),
    );
  }
}
