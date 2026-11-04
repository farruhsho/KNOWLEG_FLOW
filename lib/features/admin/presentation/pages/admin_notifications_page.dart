import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_contract.dart';
import '../../../../core/design/tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/region_model.dart';
import '../../../onboarding/data/kg_regions_provider.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_functions.dart';
import '../../domain/localized_text.dart' show localizedOf;
import '../../domain/notification_draft.dart';
import '../widgets/admin_widgets.dart';

/// Push broadcasts (`send_notifications`, ARCHITECTURE.md §9.4): a composer
/// that requires a reach check (`adminSendNotification` dry run) before the
/// confirmed send, and the paginated history from `notifications`.
class AdminNotificationsPage extends StatelessWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: [
                Tab(text: l.adminNotifTabCompose),
                Tab(text: l.adminNotifTabHistory),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(children: [NotificationComposer(), _NotificationHistory()]),
          ),
        ],
      ),
    );
  }
}

/// Label of an audience for the admin ("Все пользователи", "Регион: …").
String notificationAudienceLabel(
  AppLocalizations l,
  NotificationAudience? a, {
  List<RegionData> regions = const [],
  String lang = 'ru',
}) {
  if (a == null) return '—';
  final v = (a.value ?? '').trim();
  switch (a.kind) {
    case NotificationAudienceKind.all:
      return l.adminNotifAudienceAllUsers;
    case NotificationAudienceKind.language:
      return l.adminNotifAudienceLanguageIs(languageLabel(l, v));
    case NotificationAudienceKind.region:
      final match = regions.where((r) => r.oblast == v);
      return l.adminNotifAudienceRegionIs(match.isEmpty ? v : match.first.label(lang));
    case NotificationAudienceKind.group:
      return l.adminNotifAudienceGroupIs(v);
  }
}

String _audienceKindLabel(AppLocalizations l, NotificationAudienceKind k) => switch (k) {
      NotificationAudienceKind.all => l.adminNotifAudienceAll,
      NotificationAudienceKind.language => l.adminNotifAudienceLanguage,
      NotificationAudienceKind.region => l.adminNotifAudienceRegion,
      NotificationAudienceKind.group => l.adminNotifAudienceGroup,
    };

/// Composer: ru + ky title and body, audience, reach check, confirmed send.
class NotificationComposer extends ConsumerStatefulWidget {
  const NotificationComposer({super.key});

  @override
  ConsumerState<NotificationComposer> createState() => _NotificationComposerState();
}

class _NotificationComposerState extends ConsumerState<NotificationComposer>
    with AutomaticKeepAliveClientMixin {
  /// The draft survives switching to the history tab and back.
  @override
  bool get wantKeepAlive => true;

  final _titleRu = TextEditingController();
  final _titleKy = TextEditingController();
  final _bodyRu = TextEditingController();
  final _bodyKy = TextEditingController();
  final _groupId = TextEditingController();
  late final Listenable _textChanges = Listenable.merge([_titleRu, _titleKy, _bodyRu, _bodyKy, _groupId]);

  NotificationAudienceKind _kind = NotificationAudienceKind.all;
  String _language = 'ru';
  String? _region;

  /// Errors are shown only after the first check / send attempt.
  bool _showErrors = false;
  bool _busy = false;

  /// The server refused because of the daily limit (LIMIT_REACHED /
  /// RATE_LIMITED).
  bool _limitHit = false;

  /// Last reach check and the exact draft it was made for.
  ({String signature, NotificationSendResult result})? _check;
  NotificationSendResult? _lastSent;

  @override
  void dispose() {
    for (final c in [_titleRu, _titleKy, _bodyRu, _bodyKy, _groupId]) {
      c.dispose();
    }
    super.dispose();
  }

  NotificationAudience get _audience => switch (_kind) {
        NotificationAudienceKind.all => NotificationAudience.everyone,
        NotificationAudienceKind.language => NotificationAudience(_kind, _language),
        NotificationAudienceKind.region => NotificationAudience(_kind, _region),
        NotificationAudienceKind.group => NotificationAudience(_kind, _groupId.text),
      };

  NotificationDraft get _draft => NotificationDraft(
        title: {'ru': _titleRu.text, 'ky': _titleKy.text},
        body: {'ru': _bodyRu.text, 'ky': _bodyKy.text},
        audience: _audience,
      );

  Set<String>? get _knownRegions {
    final regions = ref.read(kgRegionsProvider).valueOrNull;
    return regions == null ? null : {for (final r in regions) r.oblast};
  }

  /// Validates the draft; shows the errors and returns `null` when invalid.
  NotificationDraft? _validDraft() {
    final draft = _draft;
    final issues = draft.validate(knownRegions: _knownRegions);
    if (issues.isEmpty) return draft;
    setState(() => _showErrors = true);
    showAdminSnack(context, AppLocalizations.of(context)!.adminNotifFixErrors, error: true);
    return null;
  }

  void _handleError(Object e) {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    final reason = BackendReasons.of(e);
    if (reason == BackendReasons.limitReached || reason == BackendReasons.rateLimited) {
      setState(() => _limitHit = true);
      showAdminSnack(context, l.adminNotifLimitReached(kNotificationsPerDay), error: true);
    } else {
      showAdminSnack(context, adminErrorMessage(l, e), error: true);
    }
  }

  Future<void> _checkReach() async {
    final draft = _validDraft();
    if (draft == null) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(adminFunctionsServiceProvider).sendNotification(draft, dryRun: true);
      if (!mounted) return;
      setState(() => _check = (signature: draft.signature, result: r));
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context)!;
    final draft = _validDraft();
    final check = _check;
    if (draft == null || check == null || check.signature != draft.signature) return;
    final regions = ref.read(kgRegionsProvider).valueOrNull ?? const <RegionData>[];
    final ok = await confirmAdminAction(
      context,
      title: l.adminNotifConfirmTitle,
      message: l.adminNotifConfirmBody(
        check.result.recipients,
        notificationAudienceLabel(l, draft.audience,
            regions: regions, lang: Localizations.localeOf(context).languageCode),
      ),
      confirmLabel: l.adminNotifSend,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(adminFunctionsServiceProvider).sendNotification(draft, dryRun: false);
      if (!mounted) return;
      setState(() {
        _lastSent = r;
        // A finished broadcast can never be re-sent by a second tap.
        _check = null;
      });
      ref.read(notificationsPageProvider.notifier).refresh();
      showAdminSnack(context, l.adminNotifSentSnack(r.sent));
    } catch (e) {
      // A timeout may still have sent the broadcast: never allow a blind
      // second send — require a new reach check and show the fresh history.
      if (mounted) setState(() => _check = null);
      ref.read(notificationsPageProvider.notifier).refresh();
      _handleError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setKind(NotificationAudienceKind k) => setState(() => _kind = k);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final sentToday = ref.watch(notificationsPageProvider
        .select((s) => notificationsSentToday(s.items, DateTime.now())));
    return AdminPageBody(
      maxWidth: 760,
      children: [
        AdminBanner(
          icon: Icons.campaign_outlined,
          message: l.adminNotifIntro(kNotificationsPerDay),
        ),
        if (_limitHit || sentToday >= kNotificationsPerDay)
          AdminBanner(
            icon: Icons.hourglass_bottom,
            tone: AdminTone.warning,
            message: _limitHit
                ? l.adminNotifLimitReached(kNotificationsPerDay)
                : l.adminNotifTodayCount(sentToday, kNotificationsPerDay),
          ),
        AdminCard(
          title: l.adminNotifTextTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (code, title, body) in [
                ('ru', _titleRu, _bodyRu),
                ('ky', _titleKy, _bodyKy),
              ]) ...[
                Text(languageLabel(l, code), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                LimitedTextField(
                  key: ValueKey('notif_title_$code'),
                  controller: title,
                  label: l.adminNotifFieldTitle,
                  max: kNotificationTitleMax,
                  showRequired: _showErrors,
                  enabled: !_busy,
                ),
                const SizedBox(height: AppSpacing.sm),
                LimitedTextField(
                  key: ValueKey('notif_body_$code'),
                  controller: body,
                  label: l.adminNotifFieldBody,
                  max: kNotificationBodyMax,
                  showRequired: _showErrors,
                  minLines: 2,
                  maxLines: 5,
                  enabled: !_busy,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
        AdminCard(
          title: l.adminNotifAudienceTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final k in NotificationAudienceKind.values)
                    ChoiceChip(
                      label: Text(_audienceKindLabel(l, k)),
                      selected: _kind == k,
                      onSelected: _busy ? null : (_) => _setKind(k),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _audienceValue(l, lang),
            ],
          ),
        ),
        AdminCard(
          title: l.adminNotifSendTitle,
          child: ListenableBuilder(
            listenable: _textChanges,
            builder: (context, _) => _actions(l),
          ),
        ),
        if (_lastSent != null)
          AdminBanner(
            icon: Icons.check_circle_outline,
            tone: _lastSent!.failed > 0 ? AdminTone.warning : AdminTone.success,
            message: l.adminNotifResult(_lastSent!.recipients, _lastSent!.sent, _lastSent!.failed),
          ),
      ],
    );
  }

  Widget _audienceValue(AppLocalizations l, String lang) {
    switch (_kind) {
      case NotificationAudienceKind.all:
        return Text(l.adminNotifAudienceAllHint,
            style: TextStyle(color: context.tokens.textSecondary));
      case NotificationAudienceKind.language:
        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final code in kNotificationLanguages)
              ChoiceChip(
                label: Text(languageLabel(l, code)),
                selected: _language == code,
                onSelected: _busy ? null : (_) => setState(() => _language = code),
              ),
          ],
        );
      case NotificationAudienceKind.region:
        final regions = ref.watch(kgRegionsProvider);
        return regions.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(adminErrorMessage(l, e), style: TextStyle(color: context.tokens.danger)),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDropdown<String>(
                label: l.adminNotifAudienceRegion,
                value: _region,
                width: double.infinity,
                items: {for (final r in list) r.oblast: r.label(lang)},
                onChanged: (v) {
                  if (!_busy) setState(() => _region = v);
                },
              ),
              if (_showErrors && _region == null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(l.adminNotifAudienceValueRequired,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        );
      case NotificationAudienceKind.group:
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _groupId,
          builder: (context, v, _) {
            final issues = _showErrors ? NotificationAudience(_kind, v.text).validate() : const [];
            return TextField(
              key: const ValueKey('notif_group_id'),
              controller: _groupId,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l.adminNotifGroupId,
                helperText: l.adminNotifGroupIdHelp,
                errorText: issues.isEmpty
                    ? null
                    : (issues.first == NotificationIssue.audienceValueRequired
                        ? l.adminNotifAudienceValueRequired
                        : l.adminNotifGroupIdInvalid),
              ),
            );
          },
        );
    }
  }

  Widget _actions(AppLocalizations l) {
    final draft = _draft;
    final check = _check;
    final fresh = check != null && check.signature == draft.signature;
    final recipients = fresh ? check.result.recipients : 0;
    final scheme = Theme.of(context).colorScheme;
    final String status;
    Color? statusColor;
    if (check == null) {
      status = l.adminNotifCheckFirst;
    } else if (!fresh) {
      status = l.adminNotifCheckStale;
      statusColor = context.tokens.warning;
    } else if (recipients == 0) {
      status = l.adminNotifNoRecipients;
      statusColor = scheme.error;
    } else {
      status = l.adminNotifRecipients(recipients);
      statusColor = context.tokens.success;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          status,
          key: const ValueKey('notif_status'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: statusColor ?? context.tokens.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('notif_check'),
              onPressed: _busy ? null : _checkReach,
              icon: _busy
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.groups_outlined),
              label: Text(l.adminNotifCheckReach),
            ),
            FilledButton.icon(
              key: const ValueKey('notif_send'),
              onPressed: (_busy || !fresh || recipients == 0) ? null : _send,
              icon: const Icon(Icons.send_outlined),
              label: Text(l.adminNotifSend),
            ),
          ],
        ),
      ],
    );
  }
}

/// Text field with a code-point counter and an error past [max] (and when
/// empty, once [showRequired] is set). Rebuilds only itself while typing.
class LimitedTextField extends StatelessWidget {
  const LimitedTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.max,
    this.showRequired = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.hint,
    this.enabled = true,
    this.externalError,
  });

  final TextEditingController controller;
  final String label;
  final int max;
  final bool showRequired;
  final int minLines;
  final int maxLines;
  final String? hint;
  final bool enabled;

  /// Error from a whole-form validation, shown while the field is empty
  /// (a missing translation clears as soon as it is typed).
  final String? externalError;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final n = notificationTextLength(value.text);
        final String? error = n > max
            ? l.adminTextTooLong(max)
            : (n == 0 ? (showRequired ? l.adminFieldRequired : externalError) : null);
        return TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintMaxLines: 2,
            counterText: '$n / $max',
            errorText: error,
          ),
        );
      },
    );
  }
}

class _NotificationHistory extends ConsumerWidget {
  const _NotificationHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final state = ref.watch(notificationsPageProvider);
    final notifier = ref.read(notificationsPageProvider.notifier);
    final regions = ref.watch(kgRegionsProvider).valueOrNull ?? const <RegionData>[];
    return PagedListBody<NotificationRecord>(
      state: state,
      onLoadMore: notifier.loadMore,
      onRetry: notifier.retry,
      onRefresh: notifier.refresh,
      emptyMessage: l.adminNotifHistoryEmpty,
      itemBuilder: (context, n) {
        final title = localizedOf(n.title, lang == 'ky' ? 'ky' : 'ru');
        return AdminListTile(
          title: title.isEmpty ? n.id : title,
          subtitle: [
            formatAdminDate(n.createdAt),
            notificationAudienceLabel(l, n.audience, regions: regions, lang: lang),
            if (n.createdBy != null) l.adminLogsActor(n.createdBy!),
          ].join(' · '),
          chips: [
            AdminPill(l.adminNotifRecipientsShort(n.recipients)),
            AdminPill(l.adminNotifSentShort(n.sent), tone: AdminTone.success),
            if (n.failed > 0) AdminPill(l.adminNotifFailedShort(n.failed), tone: AdminTone.danger),
          ],
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(title.isEmpty ? n.id : title),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final code in kNotificationLanguages) ...[
                        Text(languageLabel(l, code), style: Theme.of(ctx).textTheme.labelLarge),
                        const SizedBox(height: AppSpacing.xxs),
                        SelectableText(n.title[code] ?? '—', style: Theme.of(ctx).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.xxs),
                        SelectableText(n.body[code] ?? '—'),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AdminKeyValue(l.adminNotifAudienceTitle,
                          notificationAudienceLabel(l, n.audience, regions: regions, lang: lang)),
                      AdminKeyValue(l.adminNotifResultLabel,
                          l.adminNotifResult(n.recipients, n.sent, n.failed)),
                      AdminKeyValue('ID', n.id),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.adminClose)),
              ],
            ),
          ),
        );
      },
    );
  }
}
