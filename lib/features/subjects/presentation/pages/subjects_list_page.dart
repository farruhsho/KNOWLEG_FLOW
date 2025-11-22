import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/services/mock_data_service.dart';
import '../../../../shared/widgets/error_view.dart';

class SubjectsListPage extends StatefulWidget {
  const SubjectsListPage({super.key});

  @override
  State<SubjectsListPage> createState() => _SubjectsListPageState();
}

class _SubjectsListPageState extends State<SubjectsListPage> {
  @override
  Widget build(BuildContext context) {
    final subjects = MockDataService.getSubjects();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Предметы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: subjects.isEmpty
          ? const EmptyView(
              message: 'Предметы не найдены',
              subtitle: 'Скоро здесь появятся учебные предметы',
              icon: Icons.school_outlined,
            )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subject = subjects[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (index * 100)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: _buildSubjectCard(context, subject),
          );
        },
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, SubjectModel subject) {
    final color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          context.go('${AppRouter.subjectDetail.replaceAll(':id', subject.id)}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Hero(
          tag: 'subject_${subject.id}',
          child: Material(
            color: Colors.transparent,
            child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    subject.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.getTitle('ru'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject.getDescription('ru'),
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.book, size: 16, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '${subject.totalLessons} уроков',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.quiz, size: 16, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '${subject.totalQuestions} вопросов',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(Icons.arrow_forward_ios, size: 20),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}
