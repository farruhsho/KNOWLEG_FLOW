import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'ort_guide_page.dart';

class HandbookPage extends StatelessWidget {
  const HandbookPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      {
        'title': '📖 Руководство по ОРТ',
        'subtitle': 'Что такое ОРТ, структура, советы',
        'color': AppColors.primary,
        'icon': Icons.help_outline,
        'page': const OrtGuidePage(),
      },
      {
        'title': '📐 Математика',
        'subtitle': 'Формулы, теоремы, задачи',
        'color': AppColors.mathColor,
        'icon': Icons.calculate,
        'page': null,
      },
      {
        'title': '📝 Грамматика',
        'subtitle': 'Русский, Кыргызский, English',
        'color': AppColors.success,
        'icon': Icons.translate,
        'page': null,
      },
      {
        'title': '🧠 Логика и Чтение',
        'subtitle': 'Анализ текста, логические задачи',
        'color': AppColors.info,
        'icon': Icons.psychology,
        'page': null,
      },
      {
        'title': '⚠️ Типичные ошибки',
        'subtitle': 'Разбор частых ошибок в ОРТ',
        'color': AppColors.error,
        'icon': Icons.warning,
        'page': null,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Справочник'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          final color = section['color'] as Color;
          final page = section['page'] as Widget?;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                if (page != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => page),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Раздел в разработке')),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        section['icon'] as IconData,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section['title'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            section['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: color,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
