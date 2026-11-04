import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../data/repositories/content_repositories.dart';
import '../../domain/localized_text.dart';
import '../../domain/practice_question_codec.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/file_io.dart';

String practiceIssueText(AppLocalizations l, String code) => switch (code) {
      PracticeIssue.subjectRequired => l.adminPracticeIssueSubject,
      PracticeIssue.stemRequired => l.adminIssueStem,
      PracticeIssue.optionsMin => l.adminPracticeIssueOptionsMin,
      PracticeIssue.optionEmpty => l.adminIssueOptionEmpty,
      PracticeIssue.correctRequired => l.adminIssueCorrectRequired,
      PracticeIssue.correctNotInOptions => l.adminIssueCorrectNotInOptions,
      PracticeIssue.difficultyRange => l.adminIssueDifficulty,
      PracticeIssue.typeUnknown => l.adminPracticeIssueType,
      PracticeIssue.parseError => l.adminImportParseError,
      PracticeIssue.emptyFile => l.adminImportEmpty,
      PracticeIssue.duplicateId => l.adminImportDuplicateId,
      _ => code,
    };

String practiceTypeLabel(AppLocalizations l, String type) => switch (type) {
      'single_choice' => l.adminTypeSingle,
      'multiple_choice' => l.adminTypeMultiple,
      'analogy' => l.adminTypeAnalogy,
      'completion' => l.adminTypeCompletion,
      'matching' => l.adminTypeMatching,
      'ordering' => l.adminTypeOrdering,
      'true_false' => l.adminTypeTrueFalse,
      'text_based' => l.adminTypeTextBased,
      'quantitative_comparison' => l.adminTypeComparison,
      _ => type,
    };

/// Legacy practice bank (`questions`): paginated list with filters, CSV/JSON
/// import (validated, a fresh batch per 400 docs) and export.
class PracticeQuestionsPage extends ConsumerStatefulWidget {
  const PracticeQuestionsPage({super.key});

  @override
  ConsumerState<PracticeQuestionsPage> createState() => _PracticeQuestionsPageState();
}

class _PracticeQuestionsPageState extends ConsumerState<PracticeQuestionsPage> {
  PracticeFilter _filter = (subjectId: null, difficulty: null, type: null, active: null);

  Future<void> _open(String id) async {
    final changed = await context.push<bool>('/admin/questions/$id');
    if (changed == true) ref.read(practicePageProvider(_filter).notifier).refresh();
  }

  Future<void> _import() async {
    final imported = await showDialog<int>(context: context, builder: (_) => const _ImportDialog());
    if (imported != null && imported > 0) {
      ref.read(practicePageProvider(_filter).notifier).refresh();
    }
  }

  Future<void> _export() =>
      showDialog<void>(context: context, builder: (_) => _ExportDialog(filter: _filter));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final subjects = ref.watch(adminSubjectsProvider).valueOrNull ?? const [];
    final state = ref.watch(practicePageProvider(_filter));
    final notifier = ref.read(practicePageProvider(_filter).notifier);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open('new'),
        icon: const Icon(Icons.add),
        label: Text(l.adminPracticeNew),
      ),
      body: Column(
        children: [
          AdminFilterBar(children: [
            AdminDropdown<String>(
              label: l.adminFieldSubject,
              value: _filter.subjectId,
              allLabel: l.adminAll,
              items: {for (final s in subjects) s.id: localizedOf(s.title, locale).isEmpty ? s.id : localizedOf(s.title, locale)},
              onChanged: (v) => setState(() => _filter = (
                    subjectId: v,
                    difficulty: _filter.difficulty,
                    type: _filter.type,
                    active: _filter.active,
                  )),
            ),
            AdminDropdown<int>(
              label: l.adminFieldDifficulty,
              value: _filter.difficulty,
              allLabel: l.adminAll,
              width: 140,
              items: {1: l.adminDifficulty1, 2: l.adminDifficulty2, 3: l.adminDifficulty3},
              onChanged: (v) => setState(() => _filter = (
                    subjectId: _filter.subjectId,
                    difficulty: v,
                    type: _filter.type,
                    active: _filter.active,
                  )),
            ),
            AdminDropdown<String>(
              label: l.adminFieldType,
              value: _filter.type,
              allLabel: l.adminAll,
              items: {for (final t in kPracticeQuestionTypes) t: practiceTypeLabel(l, t)},
              onChanged: (v) => setState(() => _filter = (
                    subjectId: _filter.subjectId,
                    difficulty: _filter.difficulty,
                    type: v,
                    active: _filter.active,
                  )),
            ),
            AdminDropdown<bool>(
              label: l.adminFieldStatus,
              value: _filter.active,
              allLabel: l.adminAll,
              width: 150,
              items: {true: l.adminActive, false: l.adminInactive},
              onChanged: (v) => setState(() => _filter = (
                    subjectId: _filter.subjectId,
                    difficulty: _filter.difficulty,
                    type: _filter.type,
                    active: v,
                  )),
            ),
            OutlinedButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.upload_outlined),
              label: Text(l.adminImport),
            ),
            OutlinedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.download_outlined),
              label: Text(l.adminExport),
            ),
          ]),
          Expanded(
            child: PagedListBody<PracticeQuestionDraft>(
              state: state,
              onLoadMore: notifier.loadMore,
              onRetry: notifier.retry,
              onRefresh: notifier.refresh,
              emptyMessage: l.adminPracticeEmpty,
              itemBuilder: (context, q) {
                final stem = localizedOf(q.stem, locale);
                return AdminListTile(
                  title: stem.isEmpty ? (q.id ?? '') : stem.split('\n').first,
                  subtitle:
                      '${q.subjectId} · ${practiceTypeLabel(l, q.type)} · ${l.adminDifficultyN(q.difficulty)}',
                  chips: [
                    AdminPill(q.isActive ? l.adminActive : l.adminInactive,
                        tone: q.isActive ? AdminTone.success : AdminTone.neutral),
                    if (!q.typeKnown) AdminPill(l.adminPracticeIssueType, tone: AdminTone.danger),
                    for (final loc in const ['ru', 'ky'])
                      if (!(q.stem[loc]?.isNotEmpty ?? false))
                        AdminPill(l.adminMissingTranslation(loc.toUpperCase()), tone: AdminTone.warning),
                  ],
                  onTap: () => _open(q.id!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  String? _fileName;
  ImportParseResult? _result;
  bool _busy = false;
  int _done = 0;
  Object? _error;

  Future<void> _pick() async {
    final picked = await pickFileBytes(extensions: const ['csv', 'json', 'txt']);
    if (picked == null) return;
    final text = utf8.decode(picked.bytes, allowMalformed: true);
    final isJson = picked.name.toLowerCase().endsWith('.json') || text.trimLeft().startsWith('[') ||
        text.trimLeft().startsWith('{');
    setState(() {
      _fileName = picked.name;
      _result = isJson ? parsePracticeJson(text) : parsePracticeCsv(text);
      _error = null;
      _done = 0;
    });
  }

  Future<void> _run() async {
    final valid = _result?.valid ?? const [];
    if (valid.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final n = await ref.read(practiceRepoProvider).import(
            valid,
            actor: ref.read(adminActorProvider),
            onProgress: (done, _) {
              if (mounted) setState(() => _done = done);
            },
          );
      if (mounted) Navigator.pop(context, n);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final r = _result;
    return AlertDialog(
      title: Text(l.adminImportTitle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.adminImportHelp(PracticeQuestionsRepository.batchSize)),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(
                '${practiceCsvHeader().take(12).join(',')},…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.attach_file),
                label: Text(_fileName ?? l.adminImportPick),
              ),
              if (r != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(l.adminImportSummary(r.totalRows, r.valid.length, r.invalidRows)),
                if (r.issues.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: context.tokens.warningContainer,
                      borderRadius: AppRadii.smAll,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final i in r.issues.take(100))
                          Text(
                            i.row == 0
                                ? practiceIssueText(l, i.code)
                                : l.adminImportRowIssue(i.row, practiceIssueText(l, i.code)),
                            style: TextStyle(color: context.tokens.warning),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
              if (_busy) ...[
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(
                  value: (r?.valid.isEmpty ?? true) ? null : _done / r!.valid.length,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(l.adminImportProgress(_done, r?.valid.length ?? 0)),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(l.adminImportFailedAfter(_done, adminErrorMessage(l, _error!)),
                    style: TextStyle(color: context.tokens.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.adminCancel)),
        FilledButton(
          onPressed: _busy || (r?.valid.isEmpty ?? true) ? null : _run,
          child: Text(l.adminImportRun(r?.valid.length ?? 0)),
        ),
      ],
    );
  }
}

class _ExportDialog extends ConsumerStatefulWidget {
  const _ExportDialog({required this.filter});
  final PracticeFilter filter;

  @override
  ConsumerState<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<_ExportDialog> {
  bool _csv = false;
  bool _busy = false;

  Future<String> _build() async {
    final data = await ref.read(practiceRepoProvider).export(widget.filter);
    // CMS-17: Timestamps are converted to ISO strings (jsonSafe) before
    // encoding; CSV uses the same columns the importer reads.
    return _csv
        ? practiceQuestionsToCsv(data.drafts)
        : const JsonEncoder.withIndent('  ').convert(data.raw);
  }

  Future<void> _go({required bool toFile}) async {
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final content = await _build();
      if (toFile) {
        final name = 'questions_${DateTime.now().millisecondsSinceEpoch}.${_csv ? 'csv' : 'json'}';
        final bytes = Uint8List.fromList([if (_csv) ...[0xEF, 0xBB, 0xBF], ...utf8.encode(content)]);
        final saved = await saveFileBytes(name, bytes);
        if (!mounted) return;
        if (saved) showAdminSnack(context, l.adminExportSaved);
      } else {
        await Clipboard.setData(ClipboardData(text: content));
        if (!mounted) return;
        showAdminSnack(context, l.adminExportCopied);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAdminSnack(context, adminErrorMessage(l, e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.adminExportTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.adminExportHelp),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('JSON')),
                ButtonSegment(value: true, label: Text('CSV')),
              ],
              selected: {_csv},
              onSelectionChanged: _busy ? null : (s) => setState(() => _csv = s.first),
            ),
            if (_busy) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.adminCancel)),
        OutlinedButton(
          onPressed: _busy ? null : () => _go(toFile: false),
          child: Text(l.adminExportCopy),
        ),
        FilledButton(
          onPressed: _busy ? null : () => _go(toFile: true),
          child: Text(l.adminExportSave),
        ),
      ],
    );
  }
}
