import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../models/user_settings_model.dart';

/// Settings section widget for profile
class SettingsSection extends StatefulWidget {
  final UserSettingsModel? settings;
  final Function(UserSettingsModel) onSettingsChanged;

  const SettingsSection({
    super.key,
    this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    if (settings == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Настройки',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              // Language selector
              ListTile(
                leading: const Icon(Icons.language, color: AppColors.primary),
                title: const Text('Язык'),
                subtitle: Text(settings.getLanguageName()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageSelector(context, settings),
              ),
              const Divider(height: 1),

              // Region selector
              ListTile(
                leading: const Icon(Icons.location_on, color: AppColors.accent),
                title: const Text('Регион'),
                subtitle: Text(settings.region ?? 'Не указан'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!settings.canUpdateRegion())
                      Icon(Icons.lock, size: 16, color: AppColors.grey400),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _showRegionSelector(context, settings),
              ),
              const Divider(height: 1),

              // Notifications toggle
              SwitchListTile(
                secondary: const Icon(Icons.notifications, color: AppColors.info),
                title: const Text('Уведомления'),
                subtitle: const Text('Получать напоминания'),
                value: settings.notificationsEnabled,
                onChanged: (value) {
                  final updated = settings.copyWith(notificationsEnabled: value);
                  widget.onSettingsChanged(updated);
                },
              ),
              const Divider(height: 1),

              // Sound toggle
              SwitchListTile(
                secondary: const Icon(Icons.volume_up, color: AppColors.warning),
                title: const Text('Звук'),
                subtitle: const Text('Звуковые эффекты'),
                value: settings.soundEnabled,
                onChanged: (value) {
                  final updated = settings.copyWith(soundEnabled: value);
                  widget.onSettingsChanged(updated);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLanguageSelector(BuildContext context, UserSettingsModel settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите язык'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, settings, 'ru', 'Русский'),
            _buildLanguageOption(context, settings, 'ky', 'Кыргызча'),
            _buildLanguageOption(context, settings, 'en', 'English'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    UserSettingsModel settings,
    String code,
    String name,
  ) {
    return RadioListTile<String>(
      title: Text(name),
      value: code,
      groupValue: settings.language,
      onChanged: (value) {
        if (value != null) {
          final updated = settings.copyWith(language: value);
          widget.onSettingsChanged(updated);
          Navigator.pop(context);
        }
      },
    );
  }

  void _showRegionSelector(BuildContext context, UserSettingsModel settings) {
    if (!settings.canUpdateRegion()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Регион можно менять раз в год. Последнее изменение: ${_formatDate(settings.regionLastUpdated)}',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите регион'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: UserSettingsModel.getAvailableRegions()
                .map((region) => RadioListTile<String>(
                      title: Text(region),
                      value: region,
                      groupValue: settings.region,
                      onChanged: (value) {
                        if (value != null) {
                          final updated = settings.copyWith(
                            region: value,
                            regionLastUpdated: DateTime.now(),
                          );
                          widget.onSettingsChanged(updated);
                          Navigator.pop(context);
                        }
                      },
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Никогда';
    return '${date.day}.${date.month}.${date.year}';
  }
}
