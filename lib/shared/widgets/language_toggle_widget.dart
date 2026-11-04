import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/network/firebase_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

/// Changes the live app language (LANG-01 / UI-02) and, for a signed-in
/// user, mirrors ru/ky into `users.preferred_language` (best-effort).
Future<void> changeAppLanguage(WidgetRef ref, String languageCode) async {
  await ref.read(localeProvider.notifier).setLanguageCode(languageCode);
  if (!FirebaseService.isInitialized) return;
  if (!kContentLanguageCodes.contains(languageCode)) return;
  if (ref.read(currentUidProvider) == null) return;
  unawaited(ref.read(authServiceProvider).updatePreferredLanguage(languageCode));
}

/// Language picker for Русский / Кыргызча / English.
class LanguageToggleWidget extends ConsumerWidget {
  final bool showLabel;
  final bool compact;

  /// Pops the enclosing route (dialog / sheet) after a choice.
  final bool closeOnSelect;

  const LanguageToggleWidget({
    super.key,
    this.showLabel = true,
    this.compact = false,
    this.closeOnSelect = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider.select((l) => l.languageCode));
    final l = AppLocalizations.of(context)!;

    Future<void> select(String code) async {
      await changeAppLanguage(ref, code);
      if (closeOnSelect && context.mounted) Navigator.of(context).maybePop();
    }

    if (compact) {
      return SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'ru', label: Text('РУ')),
          ButtonSegment(value: 'ky', label: Text('КЫ')),
          ButtonSegment(value: 'en', label: Text('EN')),
        ],
        selected: {current},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => select(selection.first),
      );
    }

    final options = <(String, String, String)>[
      ('ru', l.shellLangRu, l.shellLangRuNative),
      ('ky', l.shellLangKy, l.shellLangKyNative),
      ('en', l.shellLangEn, l.shellLangEnNative),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l.shellSettingsLanguage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        for (final (code, title, native) in options)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            title: Text(native),
            subtitle: native == title ? null : Text(title),
            selected: current == code,
            trailing: current == code
                ? Icon(
                    Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () => select(code),
          ),
      ],
    );
  }
}
