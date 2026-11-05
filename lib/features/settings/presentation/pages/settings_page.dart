import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/navigation/nav_helpers.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../shared/widgets/language_toggle_widget.dart';
import '../../../billing/application/billing_providers.dart' show billingModeProvider;
import '../../../dashboard/presentation/widgets/dashboard_cards.dart'
    show reminderResultText;
import '../../data/reminder_settings.dart';
import '../../domain/app_info.dart';

/// Settings: language, theme, daily reminder, legal links, app version.
/// Reached from the profile tab (NAV-06).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final gutter = AppSpacing.gutter(context);
    // Payment terms are shown only where the build takes payments on the
    // site (BILLING_MODE=web): never in the consumption-only Android build.
    final webPayments = ref.watch(billingModeProvider.select((m) => m.sellsOnWeb));

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallback: RoutePaths.profile),
        title: Text(l.shellSettingsTitle),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.xxxl),
        children: [
          _SectionHeader(l.shellSettingsAppearance),
          const Card(
            child: Column(
              children: [
                _LanguageTile(),
                Divider(height: 1),
                _ThemeTile(),
              ],
            ),
          ),
          _SectionHeader(l.shellSettingsNotifications),
          const Card(child: _ReminderTile()),
          _SectionHeader(l.shellSettingsAbout),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l.shellSettingsPrivacy),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                  onTap: () => _openUrl(context, LegalLinks.privacyPolicy),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l.shellSettingsTerms),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                  onTap: () => _openUrl(context, LegalLinks.termsOfService),
                ),
                if (webPayments) ...[
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('settings_legal_offer'),
                    leading: const Icon(Icons.gavel_outlined),
                    title: Text(l.billingLegalOffer),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(RoutePaths.legalOffer),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('settings_legal_refund'),
                    leading: const Icon(Icons.assignment_return_outlined),
                    title: Text(l.billingLegalRefund),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(RoutePaths.legalRefund),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(l.shellSettingsVersion),
                  subtitle: const Text(AppBuildInfo.version),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l.shellSettingsDisclaimer,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static Future<void> _openUrl(BuildContext context, String url) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l.shellLinkOpenFailed)));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, AppSpacing.xl, AppSpacing.xs, AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

String languageDisplayName(AppLocalizations l, String code) {
  switch (code) {
    case 'ky':
      return l.shellLangKyNative;
    case 'en':
      return l.shellLangEnNative;
    default:
      return l.shellLangRuNative;
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final code = ref.watch(localeProvider.select((x) => x.languageCode));
    return ListTile(
      leading: const Icon(Icons.translate_rounded),
      title: Text(l.shellSettingsLanguage),
      subtitle: Text(languageDisplayName(l, code)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (_) => const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: LanguageToggleWidget(closeOnSelect: true),
          ),
        ),
      ),
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final mode = ref.watch(themeProvider);
    String name(ThemeMode m) => switch (m) {
          ThemeMode.light => l.shellThemeLight,
          ThemeMode.dark => l.shellThemeDark,
          ThemeMode.system => l.shellThemeSystem,
        };
    return ListTile(
      leading: const Icon(Icons.contrast_rounded),
      title: Text(l.shellSettingsTheme),
      subtitle: Text(name(mode)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.shellSettingsTheme,
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                for (final m in const [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    title: Text(name(m)),
                    selected: m == mode,
                    trailing: m == mode
                        ? Icon(Icons.check_rounded,
                            color: Theme.of(sheetContext).colorScheme.primary)
                        : null,
                    onTap: () {
                      ref.read(themeProvider.notifier).setTheme(m);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderTile extends ConsumerStatefulWidget {
  const _ReminderTile();

  @override
  ConsumerState<_ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends ConsumerState<_ReminderTile> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(reminderSettingsProvider);
    setState(() => _busy = true);
    if (value) {
      final result = await settings.enable();
      if (result != ReminderEnableResult.enabled) {
        messenger.showSnackBar(SnackBar(content: Text(reminderResultText(l, result))));
      }
    } else {
      await settings.disable();
    }
    if (!mounted) return;
    ref.invalidate(reminderEnabledProvider);
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final enabled = ref.watch(reminderEnabledProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: Text(l.shellSettingsReminder),
      subtitle: Text(l.shellSettingsReminderHint),
      value: enabled,
      onChanged: _busy ? null : _toggle,
    );
  }
}
