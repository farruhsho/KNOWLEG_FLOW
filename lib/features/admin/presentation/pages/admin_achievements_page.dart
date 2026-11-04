import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/admin_providers.dart';
import '../../domain/achievements_config.dart';
import '../widgets/admin_widgets.dart';
import 'admin_notifications_page.dart' show LimitedTextField;

/// Icon and built-in (app) texts of each server achievement — the same
/// l10n keys the student achievements screen uses, so the editor shows what
/// students see when nothing is overridden.
class _AchievementDefaults {
  final IconData icon;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) description;
  const _AchievementDefaults(this.icon, this.title, this.description);
}

final Map<String, _AchievementDefaults> _defaults = {
  'first_lesson': _AchievementDefaults(
      Icons.menu_book_outlined, (l) => l.learnAchFirstLessonTitle, (l) => l.learnAchFirstLessonDesc),
  'xp_100': _AchievementDefaults(Icons.bolt_outlined, (l) => l.learnAchXp100Title, (l) => l.learnAchXp100Desc),
  'streak_7': _AchievementDefaults(Icons.local_fire_department_outlined, (l) => l.learnAchStreak7Title,
      (l) => l.learnAchStreak7Desc),
  'days_30': _AchievementDefaults(
      Icons.calendar_month_outlined, (l) => l.learnAchDays30Title, (l) => l.learnAchDays30Desc),
  'accuracy_90': _AchievementDefaults(
      Icons.track_changes_outlined, (l) => l.learnAchAccuracy90Title, (l) => l.learnAchAccuracy90Desc),
  'math_expert': _AchievementDefaults(
      Icons.calculate_outlined, (l) => l.learnAchMathExpertTitle, (l) => l.learnAchMathExpertDesc),
  'analogies_master': _AchievementDefaults(
      Icons.psychology_outlined, (l) => l.learnAchAnalogiesTitle, (l) => l.learnAchAnalogiesDesc),
  'reader': _AchievementDefaults(
      Icons.chrome_reader_mode_outlined, (l) => l.learnAchReaderTitle, (l) => l.learnAchReaderDesc),
  'exam_champion': _AchievementDefaults(
      Icons.emoji_events_outlined, (l) => l.learnAchExamChampionTitle, (l) => l.learnAchExamChampionDesc),
};

/// Built-in texts per locale (ru / ky), independent of the CMS language.
final Map<String, AppLocalizations> _builtIn = {
  for (final code in kAchievementLocales) code: lookupAppLocalizations(Locale(code)),
};

String _defaultText(AchievementField field, String id, String locale) {
  final d = _defaults[id];
  final l = _builtIn[locale];
  if (d == null || l == null) return '';
  return field == AchievementField.title ? d.title(l) : d.description(l);
}

/// `config/achievements` editor (`manage_achievements`, §9.4): ru/ky title
/// and description overrides plus the enabled switch (`disabled` list) for
/// every server achievement, with a live preview. Written directly to
/// Firestore — the rules accept only `titles`, `descriptions`, `disabled`.
class AdminAchievementsPage extends ConsumerWidget {
  const AdminAchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(achievementsConfigProvider);
    return AsyncBody<AchievementsConfig>(
      value: config,
      onRetry: () => ref.invalidate(achievementsConfigProvider),
      data: (c) => AchievementsEditor(initial: c),
    );
  }
}

class AchievementsEditor extends ConsumerStatefulWidget {
  const AchievementsEditor({super.key, required this.initial});
  final AchievementsConfig initial;

  @override
  ConsumerState<AchievementsEditor> createState() => _AchievementsEditorState();
}

typedef _Controllers = Map<AchievementField, Map<String, TextEditingController>>;

class _AchievementsEditorState extends ConsumerState<AchievementsEditor> {
  late final Map<String, _Controllers> _controllers = {
    for (final id in kAchievementIds)
      id: {
        for (final f in AchievementField.values)
          f: {
            for (final l in kAchievementLocales)
              l: TextEditingController(text: widget.initial.text(f, id, l))..addListener(_markDirty),
          },
      },
  };
  late Set<String> _disabled = {...widget.initial.disabled};
  final _dirty = ValueNotifier<bool>(false);
  List<AchievementIssue> _issues = const [];
  bool _saving = false;

  void _markDirty() => _dirty.value = true;

  @override
  void dispose() {
    for (final byField in _controllers.values) {
      for (final byLocale in byField.values) {
        for (final c in byLocale.values) {
          c.dispose();
        }
      }
    }
    _dirty.dispose();
    super.dispose();
  }

  AchievementsConfig get _config {
    Map<String, Map<String, String>> texts(AchievementField f) => {
          for (final id in kAchievementIds)
            id: {for (final l in kAchievementLocales) l: _controllers[id]![f]![l]!.text},
        };
    return AchievementsConfig.fromEditor(
      titles: texts(AchievementField.title),
      descriptions: texts(AchievementField.description),
      disabled: _disabled,
    );
  }

  void _toggle(String id, bool enabled) {
    setState(() {
      _disabled = {..._disabled};
      enabled ? _disabled.remove(id) : _disabled.add(id);
    });
    _markDirty();
  }

  void _reset(String id) {
    for (final byLocale in _controllers[id]!.values) {
      for (final c in byLocale.values) {
        c.clear();
      }
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final config = _config;
    final issues = config.validate();
    setState(() => _issues = issues);
    if (issues.isNotEmpty) {
      showAdminSnack(context, l.adminAchFixErrors, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(achievementsConfigRepoProvider).save(config);
      if (!mounted) return;
      _dirty.value = false;
      showAdminSnack(context, l.adminSaved);
    } catch (e) {
      if (mounted) showAdminSnack(context, adminErrorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _errorFor(AppLocalizations l, String id, AchievementField f, String locale) {
    for (final i in _issues) {
      if (i.id != id || i.field != f || i.locale != locale) continue;
      // Too-long text is already flagged live by the field's counter.
      if (i.kind == AchievementIssueKind.missingTranslation) return l.adminAchMissingTranslation;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AdminPageBody(
      maxWidth: 900,
      children: [
        AdminBanner(message: l.adminAchIntro),
        if (!widget.initial.exists)
          AdminBanner(icon: Icons.info_outline, tone: AdminTone.neutral, message: l.adminAchNoDoc),
        for (final id in kAchievementIds)
          _AchievementCard(
            key: ValueKey('ach_$id'),
            id: id,
            controllers: _controllers[id]!,
            enabled: !_disabled.contains(id),
            busy: _saving,
            onToggle: (v) => _toggle(id, v),
            onReset: () => _reset(id),
            errorFor: (f, locale) => _errorFor(l, id, f, locale),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: _dirty,
          builder: (context, dirty, _) => Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              if (dirty)
                Text(l.adminAchUnsaved, style: TextStyle(color: context.tokens.warning)),
              FilledButton.icon(
                key: const ValueKey('ach_save'),
                onPressed: (_saving || !dirty) ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(l.adminSave),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    super.key,
    required this.id,
    required this.controllers,
    required this.enabled,
    required this.busy,
    required this.onToggle,
    required this.onReset,
    required this.errorFor,
  });

  final String id;
  final _Controllers controllers;
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onReset;
  final String? Function(AchievementField field, String locale) errorFor;

  Widget _field(AppLocalizations l, AchievementField f, String locale) {
    final isTitle = f == AchievementField.title;
    return LimitedTextField(
      key: ValueKey('ach_${id}_${f.name}_$locale'),
      controller: controllers[f]![locale]!,
      label: '${isTitle ? l.adminAchFieldTitle : l.adminAchFieldDescription} (${locale.toUpperCase()})',
      max: isTitle ? kAchievementTitleMax : kAchievementDescriptionMax,
      hint: l.adminAchDefaultHint(_defaultText(f, id, locale)),
      minLines: 1,
      maxLines: isTitle ? 1 : 3,
      enabled: !busy,
      externalError: errorFor(f, locale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = context.tokens;
    final lang = Localizations.localeOf(context).languageCode == 'ky' ? 'ky' : 'ru';
    final icon = _defaults[id]?.icon ?? Icons.emoji_events_outlined;
    final all = [
      for (final byLocale in controllers.values) ...byLocale.values,
    ];
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enabled ? t.xpContainer : t.surfaceMuted,
                  borderRadius: AppRadii.smAll,
                ),
                child: Icon(icon, color: enabled ? t.xp : t.textTertiary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _defaultText(AchievementField.title, id, lang),
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      id,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: t.textTertiary, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: enabled ? l.adminAchEnabled : l.adminAchDisabled,
                child: Switch(
                  key: ValueKey('ach_switch_$id'),
                  value: enabled,
                  onChanged: busy ? null : onToggle,
                ),
              ),
            ],
          ),
          if (!enabled) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l.adminAchDisabledHelp, style: TextStyle(color: t.warning)),
          ],
          const SizedBox(height: AppSpacing.md),
          _ResponsivePair(
            first: _field(l, AchievementField.title, 'ru'),
            second: _field(l, AchievementField.title, 'ky'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ResponsivePair(
            first: _field(l, AchievementField.description, 'ru'),
            second: _field(l, AchievementField.description, 'ky'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: Text(l.adminAchPreview, style: Theme.of(context).textTheme.labelLarge)),
              TextButton(onPressed: busy ? null : onReset, child: Text(l.adminAchReset)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Only the preview listens to typing: no rebuild of the page.
          ListenableBuilder(
            listenable: Listenable.merge(all),
            builder: (context, _) => _ResponsivePair(
              first: _PreviewTile(
                icon: icon,
                locale: 'ru',
                enabled: enabled,
                title: _effective(AchievementField.title, 'ru'),
                description: _effective(AchievementField.description, 'ru'),
              ),
              second: _PreviewTile(
                icon: icon,
                locale: 'ky',
                enabled: enabled,
                title: _effective(AchievementField.title, 'ky'),
                description: _effective(AchievementField.description, 'ky'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l.adminAchPreviewHelp,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }

  String _effective(AchievementField f, String locale) {
    final v = controllers[f]![locale]!.text.trim();
    return v.isEmpty ? _defaultText(f, id, locale) : v;
  }
}

/// Two widgets side by side on wide screens, stacked on phones.
class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 560
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: second),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [first, const SizedBox(height: AppSpacing.sm), second],
              ),
      );
}

/// How the achievement reads for a student in [locale].
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.icon,
    required this.locale,
    required this.enabled,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String locale;
  final bool enabled;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context)!;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: t.surfaceMuted,
          borderRadius: AppRadii.mdAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: enabled ? t.xp : t.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AdminPill(locale.toUpperCase()),
                      if (!enabled) AdminPill(l.adminAchDisabled, tone: AdminTone.warning),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(title, style: text.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(description, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
