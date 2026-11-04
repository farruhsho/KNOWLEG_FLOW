import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../data/models/subject_doc.dart';
import '../../domain/localized_text.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/localized_fields.dart';

/// Subjects & topics (`subjects/{id}`, topics inline). Doc id == subject id
/// (CMS-05/06); deleting is a soft deactivation unless nothing references the
/// subject (CMS-22).
class SubjectsPage extends ConsumerWidget {
  const SubjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final subjects = ref.watch(adminSubjectsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text(l.adminSubjectsNew),
      ),
      body: AsyncBody(
        value: subjects,
        onRetry: () => ref.invalidate(adminSubjectsProvider),
        data: (list) => list.isEmpty
            ? AdminEmptyView(message: l.adminSubjectsEmpty)
            : RefreshIndicator(
                onRefresh: () => ref.refresh(adminSubjectsProvider.future),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(AppSpacing.gutter(context), AppSpacing.lg,
                      AppSpacing.gutter(context), AppSpacing.huge * 2),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _SubjectTile(subject: list[i]),
                ),
              ),
      ),
    );
  }
}

Future<void> _edit(BuildContext context, WidgetRef ref, SubjectDoc? subject) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _SubjectEditor(subject: subject),
  );
  if (saved == true) ref.invalidate(adminSubjectsProvider);
}

class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({required this.subject});
  final SubjectDoc subject;

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref.read(subjectsRepoProvider).setActive(subject.id, !subject.isActive);
      ref.invalidate(adminSubjectsProvider);
    } catch (e) {
      if (context.mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final ok = await confirmAdminAction(
      context,
      title: l.adminSubjectsDeleteTitle,
      message: l.adminSubjectsDeleteBody(subject.id),
      confirmLabel: l.adminDelete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(subjectsRepoProvider).deleteIfUnused(subject.id);
      ref.invalidate(adminSubjectsProvider);
      if (context.mounted) showAdminSnack(context, l.adminDeleted);
    } catch (e) {
      if (context.mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    return AdminListTile(
      title: localizedOf(subject.title, locale).isEmpty ? subject.id : localizedOf(subject.title, locale),
      subtitle: '${subject.id} · ${l.adminSubjectsTopicsCount(subject.topics.length)}',
      leading: Icon(Icons.category_outlined, color: Theme.of(context).colorScheme.primary),
      chips: [
        AdminPill(subject.isActive ? l.adminActive : l.adminInactive,
            tone: subject.isActive ? AdminTone.success : AdminTone.neutral),
      ],
      onTap: () => _edit(context, ref, subject),
      trailing: PopupMenuButton<String>(
        tooltip: l.adminMore,
        onSelected: (v) {
          if (v == 'edit') _edit(context, ref, subject);
          if (v == 'toggle') _toggleActive(context, ref);
          if (v == 'delete') _delete(context, ref);
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(l.adminEdit)),
          PopupMenuItem(
              value: 'toggle', child: Text(subject.isActive ? l.adminDeactivate : l.adminActivate)),
          PopupMenuItem(value: 'delete', child: Text(l.adminDeletePermanently)),
        ],
      ),
    );
  }
}

class _TopicRow {
  _TopicRow(this.suffix, this.title);
  final TextEditingController suffix;
  Map<String, String> title;
}

class _SubjectEditor extends ConsumerStatefulWidget {
  const _SubjectEditor({required this.subject});
  final SubjectDoc? subject;

  @override
  ConsumerState<_SubjectEditor> createState() => _SubjectEditorState();
}

class _SubjectEditorState extends ConsumerState<_SubjectEditor> {
  final _formKey = GlobalKey<FormState>();
  late final bool _isNew = widget.subject == null;
  late final _id = TextEditingController(text: widget.subject?.id ?? '');
  late final _icon = TextEditingController(text: widget.subject?.icon ?? 'book');
  late final _color = TextEditingController(text: widget.subject?.color ?? '#4D6BEE');
  late final _order = TextEditingController(text: '${widget.subject?.order ?? 0}');
  late Map<String, String> _title = widget.subject?.title ?? {};
  late Map<String, String> _description = widget.subject?.description ?? {};
  late bool _active = widget.subject?.isActive ?? true;
  late final List<_TopicRow> _topics = [
    for (final t in widget.subject?.topics ?? const <TopicDoc>[])
      _TopicRow(TextEditingController(text: _suffixOf(t.id)), t.title),
  ];
  bool _saving = false;

  String _suffixOf(String topicId) {
    final prefix = '${widget.subject?.id}.';
    return topicId.startsWith(prefix) ? topicId.substring(prefix.length) : topicId;
  }

  @override
  void dispose() {
    for (final c in [_id, _icon, _color, _order, for (final t in _topics) t.suffix]) {
      c.dispose();
    }
    super.dispose();
  }

  Color? _parseColor(String hex) {
    final h = hex.replaceAll('#', '').trim();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color.fromARGB(255, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if ((_title['ru'] ?? '').trim().isEmpty && (_title['ky'] ?? '').trim().isEmpty) {
      showAdminSnack(context, l.adminTitleRequired, error: true);
      return;
    }
    final id = _id.text.trim();
    final topicIds = <String>{};
    final topics = <TopicDoc>[];
    for (var i = 0; i < _topics.length; i++) {
      final suffix = _topics[i].suffix.text.trim();
      if (suffix.isEmpty) continue;
      final topicId = suffix.contains('.') && suffix.startsWith('$id.') ? suffix : '$id.$suffix';
      if (!topicIds.add(topicId)) {
        showAdminSnack(context, l.adminSubjectsTopicDuplicate(topicId), error: true);
        return;
      }
      topics.add(TopicDoc(id: topicId, title: _topics[i].title, order: i));
    }
    final base = widget.subject ?? SubjectDoc(id: id, title: const {}, description: const {});
    final doc = base.copyWith(
      title: mergeLocalized(base.title, _title),
      description: mergeLocalized(base.description, _description),
      icon: _icon.text.trim().isEmpty ? 'book' : _icon.text.trim(),
      color: _color.text.trim(),
      order: int.tryParse(_order.text.trim()) ?? 0,
      isActive: _active,
      topics: topics,
    );
    setState(() => _saving = true);
    try {
      final repo = ref.read(subjectsRepoProvider);
      if (_isNew) {
        await repo.create(doc);
      } else {
        await repo.update(doc);
      }
      if (mounted) Navigator.pop(context, true);
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
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final swatch = _parseColor(_color.text);
    final form = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextFormField(
            controller: _id,
            enabled: _isNew,
            decoration: InputDecoration(labelText: l.adminSubjectsId, helperText: l.adminSubjectsIdHelp),
            validator: (v) => SubjectDoc.idPattern.hasMatch(v?.trim() ?? '') ? null : l.adminSubjectsIdInvalid,
          ),
          const SizedBox(height: AppSpacing.md),
          LocalizedFields(label: l.adminFieldTitle, initial: _title, onChanged: (v) => _title = v),
          LocalizedFields(
            label: l.adminFieldDescription,
            initial: _description,
            minLines: 2,
            onChanged: (v) => _description = v,
          ),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: TextField(controller: _icon, decoration: InputDecoration(labelText: l.adminSubjectsIcon)),
              ),
              SizedBox(
                width: 160,
                child: TextFormField(
                  controller: _color,
                  decoration: InputDecoration(labelText: l.adminSubjectsColor),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => _parseColor(v ?? '') == null ? l.adminSubjectsColorInvalid : null,
                ),
              ),
              if (swatch != null)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: swatch,
                    borderRadius: AppRadii.smAll,
                    border: Border.all(color: context.tokens.border),
                  ),
                ),
              SizedBox(
                width: 120,
                child: TextFormField(
                  controller: _order,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: l.adminFieldOrder),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: Text(l.adminActive),
            subtitle: Text(l.adminSubjectsActiveHelp),
          ),
          const Divider(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(child: Text(l.adminSubjectsTopics, style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                onPressed: () => setState(() => _topics.add(_TopicRow(TextEditingController(), {}))),
                icon: const Icon(Icons.add),
                label: Text(l.adminSubjectsAddTopic),
              ),
            ],
          ),
          Text(l.adminSubjectsTopicsHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _topics.length; i++)
            AdminCard(
              key: ObjectKey(_topics[i]),
              padding: const EdgeInsets.all(AppSpacing.md),
              title: l.adminSubjectsTopicN(i + 1),
              trailing: IconButton(
                tooltip: l.adminRemove,
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  final row = _topics[i];
                  setState(() => _topics.removeAt(i));
                  WidgetsBinding.instance.addPostFrameCallback((_) => row.suffix.dispose());
                },
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _topics[i].suffix,
                    decoration: InputDecoration(
                      labelText: l.adminSubjectsTopicId,
                      prefixText: '${_id.text.trim()}.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LocalizedFields(
                    label: l.adminFieldTitle,
                    initial: _topics[i].title,
                    onChanged: (v) => _topics[i].title = mergeLocalized(_topics[i].title, v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    final actions = [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(l.adminCancel)),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(l.adminSave),
      ),
    ];
    final title = _isNew ? l.adminSubjectsNew : l.adminSubjectsEdit;
    if (narrow) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l.adminCancel,
              onPressed: _saving ? null : () => Navigator.pop(context),
            ),
            actions: [actions.last, const SizedBox(width: AppSpacing.sm)],
          ),
          body: form,
        ),
      );
    }
    return AlertDialog(
      title: Text(title),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(width: 640, height: MediaQuery.sizeOf(context).height * 0.7, child: form),
      actions: actions,
    );
  }
}
