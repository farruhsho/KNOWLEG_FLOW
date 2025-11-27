import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/language_provider.dart';

/// Language toggle widget for switching between RU/KG/EN
class LanguageToggleWidget extends ConsumerWidget {
  final bool showLabel;
  final bool compact;

  const LanguageToggleWidget({
    super.key,
    this.showLabel = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);

    if (compact) {
      return _buildCompactToggle(context, ref, currentLanguage);
    }

    return _buildFullToggle(context, ref, currentLanguage);
  }

  Widget _buildCompactToggle(BuildContext context, WidgetRef ref, String currentLanguage) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'ru',
          label: Text('РУ'),
        ),
        ButtonSegment(
          value: 'ky',
          label: Text('КЫ'),
        ),
        ButtonSegment(
          value: 'en',
          label: Text('EN'),
        ),
      ],
      selected: {currentLanguage},
      onSelectionChanged: (Set<String> newSelection) {
        ref.read(languageProvider.notifier).setLanguage(newSelection.first);
      },
    );
  }

  Widget _buildFullToggle(BuildContext context, WidgetRef ref, String currentLanguage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Язык приложения',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Русский'),
                  subtitle: const Text('Russian'),
                  value: 'ru',
                  groupValue: currentLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(languageProvider.notifier).setLanguage(value);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Кыргызча'),
                  subtitle: const Text('Kyrgyz'),
                  value: 'ky',
                  groupValue: currentLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(languageProvider.notifier).setLanguage(value);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('English'),
                  subtitle: const Text('English'),
                  value: 'en',
                  groupValue: currentLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(languageProvider.notifier).setLanguage(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
