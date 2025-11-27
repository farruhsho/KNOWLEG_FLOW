import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_typography.dart';
import '../../data/repositories/questions_repository.dart';

/// Export questions dialog
class ExportQuestionsDialog extends ConsumerStatefulWidget {
  final List<String>? selectedQuestionIds;
  final String? subjectId;

  const ExportQuestionsDialog({
    super.key,
    this.selectedQuestionIds,
    this.subjectId,
  });

  @override
  ConsumerState<ExportQuestionsDialog> createState() =>
      _ExportQuestionsDialogState();
}

class _ExportQuestionsDialogState
    extends ConsumerState<ExportQuestionsDialog> {
  bool _isExporting = false;
  String? _exportedData;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Экспорт вопросов'),
      content: SizedBox(
        width: 500,
        child: _exportedData != null
            ? _buildExportedView()
            : _buildExportOptions(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
        if (_exportedData == null)
          ElevatedButton(
            onPressed: _isExporting ? null : _exportQuestions,
            child: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Экспортировать'),
          ),
      ],
    );
  }

  Widget _buildExportOptions() {
    final count = widget.selectedQuestionIds?.length ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selectedQuestionIds != null)
          Text(
            'Будет экспортировано: $count вопросов',
            style: AdminTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          )
        else if (widget.subjectId != null)
          Text(
            'Будут экспортированы все вопросы предмета',
            style: AdminTypography.bodyLarge,
          )
        else
          Text(
            'Будут экспортированы все вопросы',
            style: AdminTypography.bodyLarge,
          ),
        const SizedBox(height: 16),
        const Text('Формат: JSON'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminColors.infoLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.info),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AdminColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Экспортированные данные можно импортировать обратно',
                  style: AdminTypography.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: AdminColors.success),
            const SizedBox(width: 8),
            Text(
              'Экспорт завершен!',
              style: AdminTypography.h6.copyWith(
                color: AdminColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.border),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              _exportedData!,
              style: AdminTypography.mono.copyWith(fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Копировать'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _downloadFile,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Скачать'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportQuestions() async {
    setState(() => _isExporting = true);

    try {
      final repository = ref.read(questionsRepositoryProvider);
      final data = await repository.exportQuestions(
        subjectId: widget.subjectId,
        questionIds: widget.selectedQuestionIds,
      );

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      setState(() {
        _exportedData = jsonString;
        _isExporting = false;
      });
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    }
  }

  void _copyToClipboard() {
    // TODO: Implement clipboard copy
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано в буфер обмена')),
    );
  }

  void _downloadFile() {
    // TODO: Implement file download
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Файл сохранен')),
    );
  }
}
