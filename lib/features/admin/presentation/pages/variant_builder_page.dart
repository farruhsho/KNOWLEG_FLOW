import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/admin_access_provider.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_functions.dart';
import '../../data/models/admin_records.dart';
import '../../domain/admin_role.dart';
import '../../domain/blueprint_spec.dart';
import '../../domain/localized_text.dart';
import '../../domain/variant_validation.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/localized_fields.dart';
import 'variants_page.dart' show variantStatusLabel, variantStatusTone;

String variantProblemText(AppLocalizations l, VariantProblem p) {
  final s = p.sectionId ?? '—';
  final q = p.questionId ?? '—';
  final part = p.partId ?? '—';
  return switch (p.code) {
    VariantProblemCode.blueprintVersion => l.adminVpBlueprintVersion(p.expected ?? 0, p.actual ?? 0),
    VariantProblemCode.languageNotAllowed => l.adminVpLanguage,
    VariantProblemCode.sectionMissing => l.adminVpSectionMissing(s),
    VariantProblemCode.sectionUnknown => l.adminVpSectionUnknown(s),
    VariantProblemCode.sectionOrder => l.adminVpSectionOrder,
    VariantProblemCode.sectionCount => l.adminVpSectionCount(s, p.expected ?? 0, p.actual ?? 0),
    VariantProblemCode.partCount => l.adminVpPartCount(part, p.expected ?? 0, p.actual ?? 0),
    VariantProblemCode.partUnknown => l.adminVpPartUnknown(q),
    VariantProblemCode.questionMissing => l.adminVpQuestionMissing(q),
    VariantProblemCode.questionDuplicate => l.adminVpQuestionDuplicate(q),
    VariantProblemCode.questionLanguage => l.adminVpQuestionLanguage(q),
    VariantProblemCode.questionSection => l.adminVpQuestionSection(q, s),
    VariantProblemCode.questionPart => l.adminVpQuestionPart(q),
    VariantProblemCode.questionNotApproved => l.adminVpQuestionNotApproved(q),
    VariantProblemCode.questionNoKey => l.adminVpQuestionNoKey(q),
    VariantProblemCode.questionOptionCount =>
      l.adminVpQuestionOptions(q, p.expected ?? 0, p.actual ?? 0),
    VariantProblemCode.questionNeedsPassage => l.adminVpQuestionPassage(q),
    _ => p.code,
  };
}

/// Variant builder: per-section / per-part counts against the blueprint and a
/// client-side preview of the `adminPublishVariant` rules. Publish is blocked
/// while the preview has errors; the server re-checks and returns `problems`.
class VariantBuilderPage extends ConsumerStatefulWidget {
  const VariantBuilderPage({super.key, required this.variantId});

  /// Document id or `new`.
  final String variantId;

  @override
  ConsumerState<VariantBuilderPage> createState() => _VariantBuilderPageState();
}

class _VariantBuilderPageState extends ConsumerState<VariantBuilderPage> {
  late bool _isNew = widget.variantId == 'new';
  late Future<VariantDoc?> _load = _fetch();
  VariantDoc? _v;
  Map<String, String> _title = {};
  final _number = TextEditingController(text: '1');
  final Map<String, VariantQuestionInfo> _infos = {};
  bool _loadingInfos = false;
  Object? _infoError;
  bool _dirty = false;
  bool _busy = false;

  Future<VariantDoc?> _fetch() => _isNew
      ? Future.value(VariantDoc(
          id: ref.read(variantsRepoProvider).newId(),
          blueprintId: '',
          blueprintVersion: 1,
          number: 1,
          title: const {},
          language: 'ru',
        ))
      : ref.read(variantsRepoProvider).get(widget.variantId);

  void _init(VariantDoc v) {
    if (_v != null) return;
    _v = v;
    _title = {...v.title};
    _number.text = '${v.number}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshInfos());
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Iterable<String> get _allIds => _v!.sections.expand((s) => s.questionIds);

  Future<void> _refreshInfos({bool all = false}) async {
    if (!mounted || _v == null) return;
    if (all) _infos.clear();
    final missing = _allIds.where((id) => !_infos.containsKey(id)).toSet();
    if (missing.isEmpty) {
      setState(() {});
      return;
    }
    setState(() {
      _loadingInfos = true;
      _infoError = null;
    });
    try {
      final r = await ref.read(examBankRepoProvider).infos(missing);
      if (!mounted) return;
      setState(() {
        _infos.addAll(r);
        _loadingInfos = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
        _loadingInfos = false;
        _infoError = e;
      });
      }
    }
  }

  BlueprintSpec? _bp(List<BlueprintSpec> all) => all.where((b) => b.id == _v!.blueprintId).firstOrNull;

  void _setBlueprint(BlueprintSpec b) {
    setState(() {
      _v = _v!.copyWith(
        blueprintId: b.id,
        blueprintVersion: b.version,
        language: b.languages.contains(_v!.language) ? _v!.language : b.languages.first,
        sections: [for (final s in b.sections) VariantSectionDraft(s.id, const [])],
      );
      _dirty = true;
    });
  }

  void _setSectionIds(String sectionId, List<String> ids) {
    final sections = [..._v!.sections];
    final i = sections.indexWhere((s) => s.sectionId == sectionId);
    if (i < 0) {
      sections.add(VariantSectionDraft(sectionId, ids));
    } else {
      sections[i] = VariantSectionDraft(sectionId, ids);
    }
    setState(() {
      _v = _v!.copyWith(sections: sections);
      _dirty = true;
    });
    _refreshInfos();
  }

  List<String> _idsOf(String sectionId) =>
      _v!.sections.where((s) => s.sectionId == sectionId).firstOrNull?.questionIds ?? const [];

  Future<void> _addIds(SectionSpec section) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.adminVariantAddIds),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(helperText: l.adminVariantAddIdsHelp),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.adminCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l.adminAdd)),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    final ids = text.split(RegExp(r'[\s,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    final current = _idsOf(section.id);
    _setSectionIds(section.id, [...current, for (final id in ids) if (!current.contains(id)) id]);
  }

  /// Fills missing slots with approved questions not used elsewhere in the
  /// variant (per part when the section has several parts).
  Future<void> _autoFill(SectionSpec section) async {
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final repo = ref.read(examBankRepoProvider);
      final used = _allIds.toSet();
      final ids = [..._idsOf(section.id)];
      if (section.parts.length > 1) {
        for (final p in section.parts) {
          final have = ids.where((id) => _infos[id]?.partId == p.id).length;
          final need = p.questionCount - have;
          if (need <= 0) continue;
          final pool = await repo.approvedIds(sectionId: section.id, language: _v!.language, partId: p.id);
          final fresh = (pool.where((id) => !used.contains(id)).toList()..shuffle()).take(need);
          ids.addAll(fresh);
          used.addAll(fresh);
        }
      } else {
        final need = section.questionCount - ids.length;
        if (need > 0) {
          final pool = await repo.approvedIds(sectionId: section.id, language: _v!.language);
          final fresh = (pool.where((id) => !used.contains(id)).toList()..shuffle()).take(need);
          ids.addAll(fresh);
        }
      }
      if (!mounted) return;
      final added = ids.length - _idsOf(section.id).length;
      _setSectionIds(section.id, ids);
      showAdminSnack(context, l.adminVariantAutoFilled(added));
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Re-targets the variant to the current blueprint version without touching
  /// its sections (CP-09): the server rejects a version mismatch, and the
  /// structural checks already run against the current blueprint.
  void _resync(BlueprintSpec b) {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _v = _v!.resyncedTo(b);
      _dirty = true;
    });
    showAdminSnack(context, l.adminVariantResyncDone(b.version));
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final number = int.tryParse(_number.text.trim());
    if (_v!.blueprintId.isEmpty) {
      showAdminSnack(context, l.adminVariantChooseBlueprint, error: true);
      return;
    }
    if (number == null || number < 1 || number > 1000) {
      showAdminSnack(context, l.adminVariantNumberInvalid, error: true);
      return;
    }
    final v = _v!.copyWith(number: number, title: mergeLocalized(_v!.title, _title));
    setState(() => _busy = true);
    try {
      await ref.read(variantsRepoProvider).save(v, isNew: _isNew, actor: ref.read(adminActorProvider));
      if (!mounted) return;
      setState(() {
        _v = v.copyWith(contentVersion: _isNew ? 1 : v.contentVersion + 1);
        _isNew = false;
        _dirty = false;
        _busy = false;
      });
      showAdminSnack(context, l.adminSaved);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAdminSnack(context, adminErrorMessage(l, e), error: true);
      }
    }
  }

  Future<void> _publish(bool publish) async {
    final l = AppLocalizations.of(context)!;
    final ok = await confirmAdminAction(
      context,
      title: publish ? l.adminVariantPublishTitle : l.adminVariantUnpublishTitle,
      message: publish ? l.adminVariantPublishBody : l.adminVariantUnpublishBody,
      confirmLabel: publish ? l.adminVariantPublish : l.adminVariantUnpublish,
      destructive: !publish,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(adminFunctionsServiceProvider).publishVariant(_v!.id, publish);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (r.status.isNotEmpty) _v = _v!.copyWith(status: r.status);
      });
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.adminVariantServerResult(variantStatusLabel(l, r.status))),
          content: SizedBox(
            width: 520,
            child: r.problems.isEmpty
                ? Text(l.adminVariantNoProblems)
                : ListView(
                    shrinkWrap: true,
                    children: [for (final p in r.problems) Text('• $p')],
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.adminClose))],
        ),
      );
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
    final blueprints = ref.watch(adminBlueprintsProvider);
    final role = ref.watch(adminRoleProvider);
    final canPublish = role?.can(AdminPermission.publishVariants) ?? false;
    // Only publish_variants holders may write exam_variants (rules); everyone
    // else gets a read-only view (AUTH-ADM-05).
    final canWrite = role?.canWriteVariants ?? false;
    return FutureBuilder<VariantDoc?>(
      future: _load,
      builder: (context, snap) {
        Widget body;
        VariantValidationReport? report;
        final err = snap.error ?? blueprints.error;
        if (err != null) {
          body = AdminErrorView(
            error: err,
            onRetry: () {
              ref.invalidate(adminBlueprintsProvider);
              setState(() => _load = _fetch());
            },
          );
        } else if (snap.connectionState != ConnectionState.done || !blueprints.hasValue) {
          body = const AdminLoadingView();
        } else if (snap.data == null) {
          body = AdminEmptyView(message: l.adminErrNotFound);
        } else if (_isNew && !canWrite) {
          body = const AdminForbiddenView();
        } else {
          _init(snap.data!);
          final bp = _bp(blueprints.requireValue);
          if (bp != null) {
            report = validateVariant(blueprint: bp, variant: _v!.toDraft(), questions: _infos);
          }
          body = _form(l, blueprints.requireValue, bp, report, canWrite: canWrite);
        }
        final published = _v?.isPublished ?? false;
        // A per-attempt fresh variant (§10.1) is never edited or published.
        final generated = _v?.isGenerated ?? false;
        final publishReady = !_isNew && !_dirty && !_loadingInfos && _infoError == null &&
            (report?.canPublish ?? false);
        return Scaffold(
          appBar: AppBar(
            title: Text(_isNew ? l.adminVariantsNew : l.adminVariantsEdit),
            actions: [
              if (_v != null && canPublish && !_isNew && !generated)
                published
                    ? TextButton(
                        onPressed: _busy ? null : () => _publish(false),
                        child: Text(l.adminVariantUnpublish),
                      )
                    : TextButton(
                        onPressed: _busy || !publishReady ? null : () => _publish(true),
                        child: Text(l.adminVariantPublish),
                      ),
              if (_v != null && !published && !generated && canWrite)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilledButton(onPressed: _busy ? null : _save, child: Text(l.adminSave)),
                ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  Widget _form(AppLocalizations l, List<BlueprintSpec> blueprints, BlueprintSpec? bp,
      VariantValidationReport? report, {required bool canWrite}) {
    final locale = Localizations.localeOf(context).languageCode;
    final v = _v!;
    final locked = v.isPublished || v.isGenerated || !canWrite;
    final outdated = bp != null && v.blueprintVersion != bp.version;
    return AdminPageBody(
      maxWidth: 1000,
      children: [
        if (v.isGenerated)
          AdminCard(
            key: const ValueKey('variant_generated_notice'),
            child: Text(l.adminVariantGeneratedReadOnly, style: TextStyle(color: context.tokens.textSecondary)),
          )
        else if (!canWrite)
          AdminCard(child: Text(l.adminVariantReadOnly, style: TextStyle(color: context.tokens.textSecondary)))
        else if (v.isPublished)
          AdminCard(child: Text(l.adminVariantsErrPublished, style: TextStyle(color: context.tokens.warning))),
        if (outdated && !locked)
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.adminVpBlueprintVersion(bp.version, v.blueprintVersion),
                    style: TextStyle(color: context.tokens.danger)),
                const SizedBox(height: AppSpacing.xs),
                Text(l.adminVariantResyncHelp, style: TextStyle(color: context.tokens.textSecondary)),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _resync(bp),
                    icon: const Icon(Icons.sync),
                    label: Text(l.adminVariantResync(bp.version)),
                  ),
                ),
              ],
            ),
          ),
        AdminCard(
          title: l.adminVariantBasics,
          trailing: AdminPill(variantStatusLabel(l, v.status), tone: variantStatusTone(v.status)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [
                AdminDropdown<String>(
                  label: l.adminFieldBlueprint,
                  value: v.blueprintId.isEmpty ? null : v.blueprintId,
                  width: 300,
                  items: {for (final b in blueprints) b.id: pickLocalized(b.title, locale)},
                  onChanged: locked || _allIds.isNotEmpty
                      ? (_) {}
                      : (id) {
                          final b = blueprints.where((x) => x.id == id).firstOrNull;
                          if (b != null) _setBlueprint(b);
                        },
                ),
                AdminDropdown<String>(
                  label: l.adminFieldLanguage,
                  value: v.language,
                  width: 160,
                  items: {for (final c in (bp?.languages ?? const ['ru', 'ky'])) c: languageLabel(l, c)},
                  onChanged: locked
                      ? (_) {}
                      : (c) => setState(() {
                            _v = v.copyWith(language: c ?? v.language);
                            _dirty = true;
                          }),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _number,
                    enabled: !locked,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l.adminVariantNumber),
                    onChanged: (_) => _dirty = true,
                  ),
                ),
                AdminDropdown<String>(
                  label: l.adminVariantDifficulty,
                  value: v.difficultyLabel,
                  width: 180,
                  items: {'standard': l.adminVariantStandard, 'advanced': l.adminVariantAdvanced},
                  onChanged: locked
                      ? (_) {}
                      : (d) => setState(() {
                            _v = v.copyWith(difficultyLabel: d ?? v.difficultyLabel);
                            _dirty = true;
                          }),
                ),
                if (!locked)
                  AdminDropdown<String>(
                    label: l.adminFieldStatus,
                    value: v.status,
                    width: 180,
                    items: {
                      'draft': l.adminVariantDraft,
                      'in_review': l.adminVariantInReview,
                      'archived': l.adminVariantArchived,
                    },
                    onChanged: (s) => setState(() {
                      _v = v.copyWith(status: s ?? v.status);
                      _dirty = true;
                    }),
                  ),
              ]),
              if (_allIds.isNotEmpty && !locked)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(l.adminVariantBlueprintLocked,
                      style: TextStyle(color: context.tokens.textSecondary)),
                ),
              const SizedBox(height: AppSpacing.md),
              IgnorePointer(
                ignoring: locked,
                child: LocalizedFields(
                  key: const ValueKey('title'),
                  label: l.adminFieldTitle,
                  initial: _title,
                  onChanged: (t) {
                    _title = t;
                    _dirty = true;
                  },
                ),
              ),
            ],
          ),
        ),
        if (bp == null)
          AdminEmptyView(message: l.adminVariantChooseBlueprint)
        else ...[
          _ReportCard(
            report: report!,
            blueprint: bp,
            loading: _loadingInfos,
            error: _infoError,
            onRecheck: () => _refreshInfos(all: true),
          ),
          for (final s in bp.sections) _sectionCard(l, s, locked),
        ],
      ],
    );
  }

  Widget _sectionCard(AppLocalizations l, SectionSpec section, bool locked) {
    final locale = Localizations.localeOf(context).languageCode;
    final ids = _idsOf(section.id);
    return AdminCard(
      title: '${pickLocalized(section.title, locale)} · ${ids.length}/${section.questionCount}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!locked)
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _addIds(section),
                icon: const Icon(Icons.playlist_add),
                label: Text(l.adminVariantAddIds),
              ),
              OutlinedButton.icon(
                onPressed: _busy || ids.length >= section.questionCount ? null : () => _autoFill(section),
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: Text(l.adminVariantAutoFill),
              ),
              if (ids.isNotEmpty)
                TextButton(
                  onPressed: _busy ? null : () => _setSectionIds(section.id, const []),
                  child: Text(l.adminVariantClear),
                ),
            ]),
          const SizedBox(height: AppSpacing.sm),
          if (ids.isEmpty)
            Text(l.adminListNoItems, style: TextStyle(color: context.tokens.textTertiary)),
          for (var i = 0; i < ids.length; i++)
            _QuestionRow(
              index: i,
              id: ids[i],
              info: _infos[ids[i]],
              locked: locked,
              onOpen: () => context.push('/admin/exam-bank/${ids[i]}'),
              onRemove: () => _setSectionIds(section.id, [...ids]..removeAt(i)),
              onUp: i == 0
                  ? null
                  : () => _setSectionIds(section.id, [...ids]..insert(i - 1, ids[i])..removeAt(i + 1)),
            ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.index,
    required this.id,
    required this.info,
    required this.locked,
    required this.onOpen,
    required this.onRemove,
    required this.onUp,
  });

  final int index;
  final String id;
  final VariantQuestionInfo? info;
  final bool locked;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback? onUp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final i = info;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('${index + 1}.', style: TextStyle(color: context.tokens.textSecondary))),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xxs, children: [
                Text(id, overflow: TextOverflow.ellipsis),
                if (i == null)
                  AdminPill(l.adminVariantUnknownQuestion, tone: AdminTone.danger)
                else ...[
                  AdminPill(reviewStatusLabel(l, i.reviewStatus), tone: reviewStatusTone(i.reviewStatus)),
                  if (i.partId != null) AdminPill(i.partId!),
                  if (!i.hasKey) AdminPill(l.adminVariantNoKey, tone: AdminTone.danger),
                ],
              ]),
            ),
          ),
          if (!locked) ...[
            IconButton(
              tooltip: l.adminMoveUp,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_upward, size: 18),
              onPressed: onUp,
            ),
            IconButton(
              tooltip: l.adminRemove,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.blueprint,
    required this.loading,
    required this.error,
    required this.onRecheck,
  });

  final VariantValidationReport report;
  final BlueprintSpec blueprint;
  final bool loading;
  final Object? error;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final errors = report.errors.toList();
    final warnings = report.warnings.toList();
    return AdminCard(
      title: l.adminVariantCheck,
      trailing: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(tooltip: l.adminVariantRecheck, icon: const Icon(Icons.refresh), onPressed: onRecheck),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in report.counts) ...[
            Row(children: [
              Icon(c.ok ? Icons.check_circle_outline : Icons.error_outline,
                  size: 18, color: c.ok ? t.success : t.danger),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${pickLocalized(blueprint.section(c.sectionId)?.title ?? const {}, locale)}: ${c.actual}/${c.expected}',
                ),
              ),
            ]),
            if (c.parts.length > 1)
              for (final p in c.parts)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xxl),
                  child: Text(
                    '${pickLocalized(blueprint.section(c.sectionId)?.part(p.partId)?.title ?? const {}, locale)}: ${p.actual}/${p.expected}',
                    style: TextStyle(color: p.ok ? t.textSecondary : t.danger),
                  ),
                ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (error != null)
            Text(adminErrorMessage(l, error!), style: TextStyle(color: t.danger))
          else if (errors.isEmpty)
            Text(l.adminVariantReady, style: TextStyle(color: t.success))
          else
            Text(l.adminVariantBlocked(errors.length), style: TextStyle(color: t.danger)),
          for (final p in errors.take(50))
            Text('• ${variantProblemText(l, p)}', style: TextStyle(color: t.danger)),
          if (errors.length > 50) Text('… +${errors.length - 50}', style: TextStyle(color: t.danger)),
          for (final p in warnings.take(20))
            Text('• ${variantProblemText(l, p)}', style: TextStyle(color: t.warning)),
        ],
      ),
    );
  }
}
