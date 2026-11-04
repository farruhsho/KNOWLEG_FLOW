import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_functions.dart';
import '../../domain/admin_nav.dart';
import '../../domain/blueprint_spec.dart';
import '../../domain/exam_question.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/math_markdown.dart';
import '../widgets/table_editor.dart';
import 'exam_question_editor_page.dart' show examIssueText;

class _DraftItem {
  _DraftItem(this.draft, this.issues) : selected = issues.isEmpty;
  final AiDraft draft;
  final List<String> issues;
  bool selected;

  /// Drafts may be saved without a passage (linked later in the editor).
  bool get savable =>
      issues.every((i) => i == ExamQuestionIssue.passageRequired);
}

/// AI question drafts (SEC-001 / CMS-03 / CMS-01): generation runs only in
/// the `adminAiDraftQuestions` callable (the Anthropic key is a function
/// secret — the client never sees or sends a key). Selected drafts are saved
/// as `exam_questions` with `review.status == draft` plus their keys, and
/// must pass methodologist review before they can enter a variant.
class AiDraftsPage extends ConsumerStatefulWidget {
  const AiDraftsPage({super.key});

  @override
  ConsumerState<AiDraftsPage> createState() => _AiDraftsPageState();
}

class _AiDraftsPageState extends ConsumerState<AiDraftsPage> {
  String? _blueprintId;
  String? _sectionId;
  String? _partId;
  final _topic = TextEditingController();
  int _difficulty = 2;
  String _language = 'ru';
  int _count = 5;
  bool _generating = false;
  bool _saving = false;
  Object? _error;
  List<_DraftItem> _drafts = const [];

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  ({BlueprintSpec? b, SectionSpec? s, PartSpec? p}) _placement(List<BlueprintSpec> all) {
    final b = all.where((x) => x.id == _blueprintId).firstOrNull;
    final s = b?.section(_sectionId);
    final p = s == null ? null : (s.parts.length == 1 ? s.parts.first : s.part(_partId));
    return (b: b, s: s, p: p);
  }

  Future<void> _generate(List<BlueprintSpec> all) async {
    final l = AppLocalizations.of(context)!;
    final pl = _placement(all);
    final topic = _topic.text.trim();
    if (pl.b == null || pl.s == null || (pl.s!.parts.length > 1 && pl.p == null) || topic.isEmpty) {
      showAdminSnack(context, l.adminAiFillForm, error: true);
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final raw = await ref.read(adminFunctionsServiceProvider).aiDraftQuestions(
            subjectId: pl.b!.subjectIdFor(pl.s!),
            sectionId: pl.s!.id,
            partId: pl.p?.id,
            topicId: topic,
            difficulty: _difficulty,
            language: _language,
            count: _count,
          );
      final repo = ref.read(examBankRepoProvider);
      final expected = pl.b!.optionsFor(pl.p);
      final items = <_DraftItem>[];
      for (final r in raw) {
        var d = parseAiDraft(
          r,
          id: repo.newId(),
          subjectId: pl.b!.subjectIdFor(pl.s!),
          sectionId: pl.s!.id,
          partId: pl.s!.parts.length > 1 ? pl.p?.id : null,
          topicId: topic,
          difficulty: _difficulty,
          language: _language,
          type: pl.p?.itemType ?? 'single_choice',
        );
        if (pl.p != null && pl.p!.hasFixedOptions) {
          // Comparison drafts come back with `options: []`: the part's fixed
          // options are the only valid ones.
          d = AiDraft(
            d.question.copyWith(options: [
              for (final o in fixedOptionsFor(pl.p!, _language)) ExamOption(o.id, o.text),
            ]),
            d.key,
            serverValid: d.serverValid,
          );
        }
        items.add(_DraftItem(
          d,
          validateExamQuestion(
            d.question,
            d.key,
            expectedOptions: expected,
            needsPassage: pl.p?.needsPassage ?? false,
            // The callable puts comparison quantities in column_a/column_b.
            requireColumns: pl.p?.itemType == kQuantitativeComparison,
          ),
        ));
      }
      if (!mounted) return;
      setState(() {
        _drafts = items;
        _generating = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _generating = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _saveSelected() async {
    final l = AppLocalizations.of(context)!;
    final chosen = _drafts.where((d) => d.selected && d.savable).toList();
    if (chosen.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(examBankRepoProvider).saveDrafts(
            [for (final d in chosen) d.draft],
            actor: ref.read(adminActorProvider),
          );
      if (!mounted) return;
      setState(() {
        _drafts = _drafts.where((d) => !chosen.contains(d)).toList();
        _saving = false;
      });
      showAdminSnack(context, l.adminAiSaved(chosen.length));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAdminSnack(context, adminErrorMessage(l, e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final blueprints = ref.watch(adminBlueprintsProvider);
    return AsyncBody(
      value: blueprints,
      onRetry: () => ref.invalidate(adminBlueprintsProvider),
      data: (all) => _body(l, all),
    );
  }

  Widget _body(AppLocalizations l, List<BlueprintSpec> all) {
    final locale = Localizations.localeOf(context).languageCode;
    final pl = _placement(all);
    final subjects = ref.watch(adminSubjectsProvider).valueOrNull ?? const [];
    final topics = pl.b == null || pl.s == null
        ? const []
        : (subjects.where((x) => x.id == pl.b!.subjectIdFor(pl.s!)).firstOrNull?.topics ?? const []);
    final selectedCount = _drafts.where((d) => d.selected && d.savable).length;
    return AdminPageBody(
      maxWidth: 960,
      children: [
        AdminCard(
          child: Text(l.adminAiNotice, style: TextStyle(color: context.tokens.textSecondary)),
        ),
        AdminCard(
          title: l.adminAiRequest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
                AdminDropdown<String>(
                  label: l.adminFieldBlueprint,
                  value: _blueprintId,
                  width: 260,
                  items: {for (final b in all) b.id: pickLocalized(b.title, locale)},
                  onChanged: (v) => setState(() {
                    _blueprintId = v;
                    final b = all.where((x) => x.id == v).firstOrNull;
                    _sectionId = b?.sections.firstOrNull?.id;
                    _partId = null;
                    if (b != null && !b.languages.contains(_language)) _language = b.languages.first;
                  }),
                ),
                if (pl.b != null)
                  AdminDropdown<String>(
                    label: l.adminFieldSection,
                    value: _sectionId,
                    width: 220,
                    items: {for (final s in pl.b!.sections) s.id: pickLocalized(s.title, locale)},
                    onChanged: (v) => setState(() {
                      _sectionId = v;
                      _partId = null;
                    }),
                  ),
                if (pl.s != null && pl.s!.parts.length > 1)
                  AdminDropdown<String>(
                    label: l.adminFieldPart,
                    value: _partId,
                    width: 260,
                    items: {for (final p in pl.s!.parts) p.id: pickLocalized(p.title, locale)},
                    onChanged: (v) => setState(() => _partId = v),
                  ),
                AdminDropdown<String>(
                  label: l.adminFieldLanguage,
                  value: _language,
                  width: 150,
                  items: {for (final c in (pl.b?.languages ?? kExamLanguages)) c: languageLabel(l, c)},
                  onChanged: (v) => setState(() => _language = v ?? _language),
                ),
                AdminDropdown<int>(
                  label: l.adminFieldDifficulty,
                  value: _difficulty,
                  width: 150,
                  items: {1: l.adminDifficulty1, 2: l.adminDifficulty2, 3: l.adminDifficulty3},
                  onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
                ),
                AdminDropdown<int>(
                  label: l.adminAiCount,
                  value: _count,
                  width: 120,
                  items: {for (var i = 1; i <= 10; i++) i: '$i'},
                  onChanged: (v) => setState(() => _count = v ?? _count),
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _topic,
                    decoration: InputDecoration(labelText: l.adminFieldTopicId, helperText: l.adminFieldTopicIdHelp),
                  ),
                ),
              ]),
              if (topics.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
                  for (final t in topics)
                    ActionChip(
                      label: Text(pickLocalized(t.title, locale).isEmpty ? t.id : pickLocalized(t.title, locale)),
                      onPressed: () => setState(() => _topic.text = t.id),
                    ),
                ]),
              ],
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _generating || _saving ? null : () => _generate(all),
                  icon: _generating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(_generating ? l.adminAiGenerating : l.adminAiGenerate),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(adminErrorMessage(l, _error!), style: TextStyle(color: context.tokens.danger)),
              ],
            ],
          ),
        ),
        if (_drafts.isNotEmpty)
          AdminCard(
            title: l.adminAiDrafts(_drafts.length),
            trailing: FilledButton(
              onPressed: _saving || selectedCount == 0 ? null : _saveSelected,
              child: Text(l.adminAiSaveSelected(selectedCount)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final d in _drafts) _DraftCard(item: d, onToggle: () => setState(() => d.selected = !d.selected)),
                TextButton(
                  onPressed: () => context.go(AdminSection.examBank.path),
                  child: Text(l.adminAiOpenBank),
                ),
              ],
            ),
          )
        else if (!_generating)
          AdminEmptyView(message: l.adminAiEmpty),
      ],
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.item, required this.onToggle});
  final _DraftItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final q = item.draft.question;
    final key = item.draft.key;
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: item.selected ? Theme.of(context).colorScheme.primary : t.border),
        borderRadius: AppRadii.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Checkbox(value: item.selected && item.savable, onChanged: item.savable ? (_) => onToggle() : null),
            Expanded(child: Text(l.adminAiDraftMeta(q.topicId, q.difficulty), overflow: TextOverflow.ellipsis)),
          ]),
          if (q.stem.trim().isNotEmpty) MathMarkdownText(q.stem),
          if (q.columnA != null || q.columnB != null) ...[
            const SizedBox(height: AppSpacing.xs),
            MathMarkdownText('**${l.adminExamColumnA}:** ${q.columnA ?? '—'}'),
            MathMarkdownText('**${l.adminExamColumnB}:** ${q.columnB ?? '—'}'),
          ],
          if (q.table != null && !q.table!.isBlank) ...[
            const SizedBox(height: AppSpacing.xs),
            AdminTablePreview(table: q.table!),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (final o in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(o.id == key.correct ? Icons.check_circle : Icons.circle_outlined,
                    size: 18, color: o.id == key.correct ? t.success : t.textTertiary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: MathMarkdownText('${o.id}. ${o.text}')),
              ]),
            ),
          if (key.explanation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l.adminFieldExplanation, style: Theme.of(context).textTheme.labelLarge),
            MathMarkdownText(key.explanation),
          ],
          if (item.issues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final i in item.issues)
              Text('• ${examIssueText(l, i)}',
                  style: TextStyle(color: item.savable ? t.warning : t.danger)),
          ],
        ],
      ),
    );
  }
}
