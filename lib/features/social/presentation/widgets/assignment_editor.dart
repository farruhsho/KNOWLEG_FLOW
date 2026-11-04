import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/content/topic_names.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/utils/content_locale.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../exam/presentation/widgets/exam_common.dart' show examLanguageName;
import '../../../exam/presentation/widgets/exam_labels.dart' show examBlueprintName;
import '../../application/social_providers.dart';
import '../../domain/social_models.dart';
import '../social_messages.dart';
import 'social_widgets.dart';

/// Opens the "Новое задание" sheet for the owner of [groupId]. Resolves to
/// true when an assignment was created.
Future<bool?> showAssignmentEditor(BuildContext context, {required String groupId}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AssignmentEditor(groupId: groupId),
    );

/// Title, type (lesson / practice / exam variant), what exactly, due date.
class AssignmentEditor extends ConsumerStatefulWidget {
  const AssignmentEditor({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AssignmentEditor> createState() => _AssignmentEditorState();
}

class _AssignmentEditorState extends ConsumerState<AssignmentEditor> {
  final _title = TextEditingController();
  AssignmentKind _kind = AssignmentKind.lesson;
  AssignableItem? _target;
  late DateTime _due;
  bool _busy = false;
  String? _titleError;
  String? _error;

  /// The practice "any subject" option (quick practice).
  static const _quickPractice = AssignableItem(id: '', title: '');

  @override
  void initState() {
    super.initState();
    final now = ref.read(socialClockProvider)();
    final inAWeek = now.add(const Duration(days: 7));
    _due = DateTime(inAWeek.year, inAWeek.month, inAWeek.day, 23, 59);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _setKind(AssignmentKind k) => setState(() {
        if (_kind == k) return;
        _kind = k;
        _target = null;
        _error = null;
      });

  Future<void> _pickTarget() async {
    final picked = await showModalBottomSheet<AssignableItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _TargetPicker(kind: _kind),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _target = picked;
      _error = null;
      // A sensible default title the owner can still edit.
      if (_title.text.trim().isEmpty && picked.id.isNotEmpty) _title.text = picked.title;
    });
  }

  Future<void> _pickDate() async {
    final now = ref.read(socialClockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _due = DateTime(picked.year, picked.month, picked.day, 23, 59));
  }

  Future<void> _save() async {
    if (_busy) return;
    final l = AppLocalizations.of(context)!;
    final title = _title.text.trim();
    final titleBad = title.isEmpty || title.length > AssignmentDraft.maxTitleLength;
    final target = _target;
    setState(() {
      _titleError = titleBad ? l.socialAssignmentTitleInvalid : null;
      _error = target == null ? l.socialAssignmentPickRequired : null;
    });
    if (titleBad || target == null) return;
    final uid = ref.read(socialUidProvider);
    if (uid == null) return;
    final draft = AssignmentDraft(title: title, kind: _kind, refId: target.id, dueAt: _due);
    setState(() => _busy = true);
    try {
      await ref.read(socialRepositoryProvider).createAssignment(widget.groupId, draft, uid: uid);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.socialErrorMessage(e, SocialAction.other);
      });
    }
  }

  String _pickLabel(AppLocalizations l) => switch (_kind) {
        AssignmentKind.lesson => l.socialAssignmentPickLesson,
        AssignmentKind.practice => l.socialAssignmentPickSubject,
        AssignmentKind.examVariant => l.socialAssignmentPickVariant,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final gutter = AppSpacing.gutter(context);
    final target = _target;
    final targetLabel = target == null
        ? _pickLabel(l)
        : (target.id.isEmpty ? l.socialAssignmentQuickPractice : target.title);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.socialAssignmentNewTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final k in AssignmentKind.values)
                  ChoiceChip(
                    key: ValueKey('assignment_kind_${k.wire}'),
                    label: Text(switch (k) {
                      AssignmentKind.lesson => l.socialAssignmentKindLesson,
                      AssignmentKind.practice => l.socialAssignmentKindPractice,
                      AssignmentKind.examVariant => l.socialAssignmentKindExam,
                    }),
                    selected: _kind == k,
                    onSelected: _busy ? null : (_) => _setKind(k),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('assignment_pick_target'),
              onPressed: _busy ? null : _pickTarget,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(targetLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('assignment_title_field'),
              controller: _title,
              enabled: !_busy,
              maxLength: AssignmentDraft.maxTitleLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.socialAssignmentTitleLabel,
                errorText: _titleError,
                errorMaxLines: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l.socialAssignmentDueLabel),
              subtitle: Text(socialDate(context, _due)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _busy ? null : _pickDate,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.danger)),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const ValueKey('assignment_save'),
              onPressed: _busy ? null : _save,
              child: _busy ? const SocialButtonProgress() : Text(l.socialSave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable list of lessons / practice subjects / published variants.
class _TargetPicker extends ConsumerStatefulWidget {
  const _TargetPicker({required this.kind});

  final AssignmentKind kind;

  @override
  ConsumerState<_TargetPicker> createState() => _TargetPickerState();
}

class _TargetPickerState extends ConsumerState<_TargetPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final gutter = AppSpacing.gutter(context);
    final lang = contentLanguageOf(context);
    final key = (kind: widget.kind, lang: lang);
    final items = ref.watch(assignableItemsProvider(key));
    final names = ref.watch(topicNamesProvider).valueOrNull ?? TopicNames.empty;
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpacing.sm),
              child: TextField(
                key: const ValueKey('assignment_picker_search'),
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l.socialAssignmentSearch,
                ),
              ),
            ),
            Expanded(
              child: items.when(
                loading: () => const Center(child: SocialButtonProgress()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.socialErrorMessage(e, SocialAction.other), textAlign: TextAlign.center),
                        TextButton(
                          onPressed: () => ref.invalidate(assignableItemsProvider(key)),
                          child: Text(l.socialRetry),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (all) {
                  final filtered = all.where((i) => i.matches(_query)).toList();
                  final showQuick = widget.kind == AssignmentKind.practice && _query.trim().isEmpty;
                  if (filtered.isEmpty && !showQuick) {
                    return Center(child: SocialMuted(l.socialAssignmentNothingFound));
                  }
                  return ListView.builder(
                    itemCount: filtered.length + (showQuick ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (showQuick && i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.bolt_outlined),
                          title: Text(l.socialAssignmentQuickPractice),
                          onTap: () => Navigator.of(context).pop(_AssignmentEditorState._quickPractice),
                        );
                      }
                      final item = filtered[i - (showQuick ? 1 : 0)];
                      return ListTile(
                        key: ValueKey('assignable_${item.id}'),
                        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: item.blueprintId == null
                            ? null
                            : Text(
                                [
                                  examBlueprintName(item.blueprintId!, l: l, names: names, lang: lang),
                                  if (item.language != null) examLanguageName(l, item.language!),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
