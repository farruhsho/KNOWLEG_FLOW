import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/lesson_model.dart';
import '../../../../shared/services/firebase_data_service.dart';

/// Daily Lesson - randomized lesson from admin pool, no repeats until cycle ends
class DailyLessonPage extends StatefulWidget {
  const DailyLessonPage({super.key});

  @override
  State<DailyLessonPage> createState() => _DailyLessonPageState();
}

class _DailyLessonPageState extends State<DailyLessonPage> {
  final _dataService = FirebaseDataService();
  LessonModel? _lesson;
  bool _isLoading = true;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadDailyLesson();
  }

  Future<void> _loadDailyLesson() async {
    try {
      // TODO: Implement daily lesson rotation logic
      // For now, load a random lesson
      final lessons = await _dataService.getLessonsBySubject('math');
      if (lessons.isNotEmpty && mounted) {
        setState(() {
          _lesson = lessons.first;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _markAsCompleted() {
    setState(() {
      _isCompleted = true;
    });
    // TODO: Award XP and save completion to Firebase
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Урок завершён! +50 XP'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isCompleted,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop || _isCompleted) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Выйти из урока?'),
            content: const Text('Вы не завершили урок. Прогресс не будет сохранён.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Остаться'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Выйти', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        
        if (shouldExit == true && context.mounted) {
          context.go('/dashboard');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Урок дня'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _lesson == null
                ? const Center(child: Text('Нет доступных уроков'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lesson header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_stories, color: Colors.white, size: 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _lesson!.getTitle('ru'),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, color: Colors.white70, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_lesson!.estimatedTimeMinutes} минут',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Lesson content
                        Text(
                          _lesson!.getContent('ru'),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                              ),
                        ),

                        const SizedBox(height: 24),

                        // Media (if any)
                        if (_lesson!.mediaUrls.isNotEmpty) ...[
                          Text(
                            'Дополнительные материалы',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          ..._lesson!.mediaUrls.map((url) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.play_circle_outline),
                                title: Text(url),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  // TODO: Open media
                                },
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 24),
                        ],

                        // Complete button
                        if (!_isCompleted)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _markAsCompleted,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Завершить урок'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          )
                        else
                          Card(
                            color: AppColors.success.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppColors.success),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Урок завершён! Возвращайтесь завтра за новым уроком.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppColors.success,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
