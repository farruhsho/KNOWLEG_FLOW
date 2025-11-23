import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/models/lesson_model.dart';
import '../../../../shared/services/mock_data_service.dart';
import '../../../../shared/widgets/error_view.dart';

class SubjectDetailPage extends StatelessWidget {
  final String subjectId;

  const SubjectDetailPage({
    super.key,
    required this.subjectId,
  });

  @override
  Widget build(BuildContext context) {
    final subject = MockDataService.getSubjectById(subjectId);
    final lessons = MockDataService.getLessonsBySubject(subjectId);

    if (subject == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Предмет')),
        body: ErrorView(
          message: 'Предмет не найден',
          icon: Icons.search_off,
          onRetry: () => context.pop(),
        ),
      );
    }

    if (lessons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(subject.getTitle('ru'))),
        body: EmptyView(
          message: 'Уроки пока не добавлены',
          subtitle: 'Скоро здесь появятся учебные материалы',
          icon: Icons.library_books_outlined,
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with subject info
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(subject.getTitle('ru')),
              background: Hero(
                tag: 'subject_${subject.id}',
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(int.parse(subject.color.replaceFirst('#', '0xFF'))),
                        Color(int.parse(subject.color.replaceFirst('#', '0xFF')))
                            .withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      subject.icon,
                      style: const TextStyle(fontSize: 80),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Subject stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.getDescription('ru'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          icon: Icons.book,
                          label: 'Уроков',
                          value: subject.totalLessons.toString(),
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          icon: Icons.quiz,
                          label: 'Вопросов',
                          value: subject.totalQuestions.toString(),
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Уроки',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton.icon(
                        onPressed: () {
                          context.go('/quiz/$subjectId');
                        },
                        icon: const Icon(Icons.quiz),
                        label: const Text('Пройти тест'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Lessons list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final lesson = lessons[index];
                return _buildLessonTile(context, lesson, index);
              },
              childCount: lessons.length,
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonTile(BuildContext context, LessonModel lesson, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(lesson.getTitle('ru')),
        subtitle: Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: AppColors.grey500),
            const SizedBox(width: 4),
            Text('${lesson.estimatedTimeMinutes} мин'),
            const SizedBox(width: 16),
            ...lesson.tags.take(2).map((tag) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Chip(
                    label: Text(
                      tag,
                      style: const TextStyle(fontSize: 10),
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          context.go('/lessons/${lesson.id}');
        },
      ),
    );
  }
}
