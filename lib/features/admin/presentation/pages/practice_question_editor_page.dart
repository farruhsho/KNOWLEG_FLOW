import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../domain/localized_text.dart';
import '../../domain/practice_question_codec.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/localized_fields.dart';
import 'practice_questions_page.dart' show practiceIssueText, practiceTypeLabel;

class _Opt {
  _Opt(this.id, this.text);
  String id;
  Map<String, String> text;
}

/// Editor for one legacy practice question. Writes through
/// [PracticeQuestionsRepository] with the canonical codec, so the `type`
/// survives a round trip (FB-13 / CMS-18) and unknown fields are kept.
class PracticeQuestionEditorPage extends ConsumerStatefulWidget {
  const PracticeQuestionEditorPage({super.key, required this.questionId});

  /// Document id or `new`.
  final String questionId;

  @override
  ConsumerState<PracticeQuestionEditorPage> createState() => _PracticeQuestionEditorPageState();
}

class _PracticeQuestionEditorPageState extends ConsumerState<PracticeQuestionEditorPage> {
  late final bool _isNew = widget.questionId == 'new';
  late Future<PracticeQuestionDraft?> _load = _fetch();

  PracticeQuestionDraft? _original;
  String _subjectId = '';
  String? _topicId;
  String _type = 'single_choice';
  int _difficulty = 1;
  bool _active = true;
  Map<String, String> _stem = {};
  Map<String, String> _explanation = {};
  Map<String, String> _hint = {};
  final List<_Opt> _options = [];
  String _correct = '';
  final Set<String> _correctMulti = {};
  final _section = TextEditingController();
  final _points = TextEditingController(text: '1');
  final _tags = TextEditingController();
  final _image = TextEditingController();
  bool _saving = false;

  Future<PracticeQuestionDraft?> _fetch() => _isNew
      ? Future.value(PracticeQuestionDraft(
          subjectId: '',
          stem: const {},
          options: [for (final id in kOptionIds.take(4)) PracticeOption(id, const {})],
          correctAnswer: '',
        ))
      : ref.read(practiceRepoProvider).get(widget.questionId);

  void _init(PracticeQuestionDraft q) {
    if (_original != null) return;
    _original = q;
    _subjectId = q.subjectId;
    _topicId = q.topicId;
    _type = q.type;
    _difficulty = q.difficulty.clamp(1, 3);
    _active = q.isActive;
    _stem = {...q.stem};
    _explanation = {...q.explanation};
    _hint = {...q.hint};
    _options.addAll(q.options.map((o) => _Opt(o.id, {...o.text})));
    _correct = q.correctAnswer;
    _correctMulti.addAll(q.correctAnswers ?? const []);
    _section.text = q.sectionId;
    _points.text = '${q.points}';
    _tags.text = q.tags.join(', ');
    _image.text = q.imageUrl ?? '';
  }

  @override
  void dispose() {
    for (final c in [_section, _points, _tags, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  PracticeQuestionDraft _collect() {
    final o = _original!;
    final multi = _type == 'multiple_choice';
    return PracticeQuestionDraft(
      id: _isNew ? null : o.id,
      subjectId: _subjectId,
      sectionId: _section.text.trim(),
      topicId: _topicId,
      lessonId: o.lessonId,
      type: _type,
      typeKnown: normalizeQuestionType(_type) != null,
      difficulty: _difficulty,
      points: int.tryParse(_points.text.trim()) ?? 1,
      stem: mergeLocalized(o.stem, _stem),
      options: [
        for (final opt in _options)
          PracticeOption(
            opt.id,
            mergeLocalized(
              o.options.where((x) => x.id == opt.id).firstOrNull?.text ?? const {},
              opt.text,
            ),
          ),
      ],
      correctAnswer: multi ? (_correctMulti.isEmpty ? '' : _correctMulti.first) : _correct,
      correctAnswers: multi ? _correctMulti.toList() : null,
      explanation: mergeLocalized(o.explanation, _explanation),
      hint: mergeLocalized(o.hint, _hint),
      tags: _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      isActive: _active,
      imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
      category: o.category,
      source: o.source,
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final q = _collect();
    final issues = q.validate();
    if (issues.isNotEmpty) {
      showAdminSnack(context, issues.map((c) => practiceIssueText(l, c)).join('\n'), error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(practiceRepoProvider).save(q, actor: ref.read(adminActorProvider));
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

  Future<void> _delete() async {
    final l = AppLocalizations.of(context)!;
    final ok = await confirmAdminAction(
      context,
      title: l.adminPracticeDeleteTitle,
      message: l.adminPracticeDeleteBody,
      confirmLabel: l.adminDelete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(practiceRepoProvider).delete(widget.questionId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<PracticeQuestionDraft?>(
      future: _load,
      builder: (context, snap) {
        Widget body;
        if (snap.hasError) {
          body = AdminErrorView(error: snap.error!, onRetry: () => setState(() => _load = _fetch()));
        } else if (snap.connectionState != ConnectionState.done) {
          body = const AdminLoadingView();
        } else if (snap.data == null) {
          body = AdminEmptyView(message: l.adminErrNotFound);
        } else {
          _init(snap.data!);
          body = _form(l);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(_isNew ? l.adminPracticeNew : l.adminPracticeEdit),
            actions: [
              if (_original != null && !_isNew)
                IconButton(
                  tooltip: l.adminDelete,
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
              if (_original != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(l.adminSave),
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
    final subject = subjects.where((s) => s.id == _subjectId).firstOrNull;
    final multi = _type == 'multiple_choice';
    final types = {
      for (final t in kPracticeQuestionTypes) t: practiceTypeLabel(l, t),
      if (!kPracticeQuestionTypes.contains(_type)) _type: '${l.adminPracticeIssueType}: $_type',
    };
    return AdminPageBody(
      maxWidth: 900,
      children: [
        AdminCard(
          title: l.adminQuestionMeta,
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              AdminDropdown<String>(
                label: l.adminFieldSubject,
                value: _subjectId.isEmpty ? null : _subjectId,
                width: 240,
                items: {
                  for (final s in subjects) s.id: localizedOf(s.title, locale).isEmpty ? s.id : localizedOf(s.title, locale),
                  if (_subjectId.isNotEmpty && subject == null) _subjectId: _subjectId,
                },
                onChanged: (v) => setState(() {
                  _subjectId = v ?? '';
                  _topicId = null;
                }),
              ),
              AdminDropdown<String>(
                label: l.adminFieldTopic,
                value: _topicId,
                width: 240,
                allLabel: l.adminNone,
                items: {
                  for (final t in subject?.topics ?? const []) t.id: localizedOf(t.title, locale).isEmpty ? t.id : localizedOf(t.title, locale),
                  if (_topicId != null && !(subject?.topics.any((t) => t.id == _topicId) ?? false))
                    _topicId!: _topicId!,
                },
                onChanged: (v) => setState(() => _topicId = v),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _section,
                  decoration: InputDecoration(labelText: l.adminFieldSection),
                ),
              ),
              AdminDropdown<String>(
                label: l.adminFieldType,
                value: _type,
                width: 220,
                items: types,
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              AdminDropdown<int>(
                label: l.adminFieldDifficulty,
                value: _difficulty,
                width: 150,
                items: {1: l.adminDifficulty1, 2: l.adminDifficulty2, 3: l.adminDifficulty3},
                onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _points,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l.adminFieldPoints),
                ),
              ),
              SizedBox(
                width: 200,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  title: Text(l.adminActive),
                  onChanged: (v) => setState(() => _active = v),
                ),
              ),
            ],
          ),
        ),
        AdminCard(
          title: l.adminFieldStem,
          child: LocalizedFields(
            label: l.adminFieldStem,
            initial: _stem,
            math: true,
            minLines: 3,
            onChanged: (v) => _stem = v,
          ),
        ),
        AdminCard(
          title: l.adminFieldOptions,
          trailing: TextButton.icon(
            onPressed: _options.length >= kOptionIds.length
                ? null
                : () => setState(() {
                      final used = _options.map((o) => o.id).toSet();
                      _options.add(_Opt(kOptionIds.firstWhere((id) => !used.contains(id)), {}));
                    }),
            icon: const Icon(Icons.add),
            label: Text(l.adminAddOption),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(multi ? l.adminCorrectMultiHelp : l.adminCorrectSingleHelp,
                  style: TextStyle(color: context.tokens.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              for (final opt in _options)
                Container(
                  key: ObjectKey(opt),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: (multi ? _correctMulti.contains(opt.id) : _correct == opt.id)
                          ? context.tokens.success
                          : context.tokens.border,
                    ),
                    borderRadius: AppRadii.smAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (multi)
                            Checkbox(
                              value: _correctMulti.contains(opt.id),
                              onChanged: (v) => setState(() =>
                                  v == true ? _correctMulti.add(opt.id) : _correctMulti.remove(opt.id)),
                            )
                          else
                            IconButton(
                              tooltip: l.adminMarkCorrect,
                              icon: Icon(_correct == opt.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked),
                              color: _correct == opt.id ? context.tokens.success : null,
                              onPressed: () => setState(() => _correct = opt.id),
                            ),
                          Expanded(
                            child: Text(l.adminOptionN(opt.id),
                                style: Theme.of(context).textTheme.labelLarge),
                          ),
                          IconButton(
                            tooltip: l.adminRemove,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _options.length <= 2
                                ? null
                                : () => setState(() {
                                      _options.remove(opt);
                                      _correctMulti.remove(opt.id);
                                      if (_correct == opt.id) _correct = '';
                                    }),
                          ),
                        ],
                      ),
                      LocalizedFields(
                        label: l.adminOptionText,
                        initial: opt.text,
                        math: true,
                        onChanged: (v) => opt.text = v,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AdminCard(
          title: l.adminFieldExplanation,
          child: Column(children: [
            LocalizedFields(
              label: l.adminFieldExplanation,
              initial: _explanation,
              math: true,
              minLines: 3,
              onChanged: (v) => _explanation = v,
            ),
            LocalizedFields(label: l.adminFieldHint, initial: _hint, onChanged: (v) => _hint = v),
          ]),
        ),
        AdminCard(
          title: l.adminQuestionExtra,
          child: Column(children: [
            TextField(
              controller: _tags,
              decoration: InputDecoration(labelText: l.adminFieldTags, helperText: l.adminFieldTagsHelp),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _image,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: l.adminFieldImageUrl),
            ),
          ]),
        ),
      ],
    );
  }
}
