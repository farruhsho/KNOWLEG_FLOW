import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// ⚠️ ЮРИДИЧЕСКИЙ ДИСКЛЕЙМЕР ДЛЯ ВЕБ-СКРАПИНГА
/// 
/// КРИТИЧЕСКИ ВАЖНО: Этот виджет ОБЯЗАТЕЛЕН для отображения
/// при использовании контента из внешних источников.
/// 
/// ТРЕБОВАНИЯ:
/// 1. Письменное разрешение от владельца контента
/// 2. Атрибуция источника
/// 3. Соблюдение лицензии
/// 4. Соблюдение robots.txt
/// 5. Rate limiting
class LegalDisclaimer extends StatelessWidget {
  final String source;
  final String licenseInfo;
  final String? permissionDocument;
  final VoidCallback? onViewLicense;

  const LegalDisclaimer({
    super.key,
    required this.source,
    required this.licenseInfo,
    this.permissionDocument,
    this.onViewLicense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade700, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Источник Контента',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('Источник:', source),
          const SizedBox(height: 8),
          _buildInfoRow('Лицензия:', licenseInfo),
          if (permissionDocument != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Разрешение:', permissionDocument!),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '⚠️ Весь контент используется с письменного разрешения правообладателей. '
              'Несанкционированное копирование или распространение запрещено.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onViewLicense != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onViewLicense,
              icon: const Icon(Icons.description),
              label: const Text('Просмотреть Лицензию'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Диалог подтверждения юридической ответственности
class LegalAcknowledgmentDialog extends StatefulWidget {
  const LegalAcknowledgmentDialog({super.key});

  @override
  State<LegalAcknowledgmentDialog> createState() => _LegalAcknowledgmentDialogState();
}

class _LegalAcknowledgmentDialogState extends State<LegalAcknowledgmentDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.gavel, color: AppColors.error),
          const SizedBox(width: 12),
          const Text('Юридическое Предупреждение'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ВНИМАНИЕ: Использование веб-скрапинга может нарушать:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildWarningItem('Авторские права'),
            _buildWarningItem('Terms of Service сайтов'),
            _buildWarningItem('Законы о защите данных'),
            _buildWarningItem('Законы о компьютерных преступлениях'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Вы ОБЯЗАНЫ получить письменное разрешение от всех владельцев контента перед использованием этой функции.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: (value) {
                setState(() {
                  _acknowledged = value ?? false;
                });
              },
              title: const Text(
                'Я подтверждаю, что имею все необходимые юридические разрешения',
                style: TextStyle(fontSize: 14),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _acknowledged
              ? () => Navigator.of(context).pop(true)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          child: const Text('Я Понимаю Риски'),
        ),
      ],
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.close, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
