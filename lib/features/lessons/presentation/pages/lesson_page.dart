import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/lesson_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/services/gamification_service.dart';
import '../../../../shared/widgets/error_view.dart';

class LessonPage extends StatefulWidget {
  final String lessonId;

  const LessonPage({
    super.key,
    required this.lessonId,
  });

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final _firebaseDataService = FirebaseDataService();
  final _gamificationService = GamificationService();
  LessonModel? _lesson;
  bool _isLoading = true;
  bool _isCompleted = false;
  double _scrollProgress = 0.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollProgress);
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    try {
      final lesson = await _firebaseDataService.getLessonById(widget.lessonId);
      setState(() {
        _lesson = lesson;
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error loading lesson: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollProgress() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      setState(() {
        _scrollProgress = maxScroll > 0 ? currentScroll / maxScroll : 0;
      });
    }
  }

  /// Persist completion and award XP exactly once (one-way: no un-marking).
  Future<void> _markCompleted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Войдите в аккаунт, чтобы сохранить прогресс'),
          ),
        );
      }
      return;
    }
    try {
      final progress = await _firebaseDataService.getUserProgress(uid);
      final alreadyDone =
          progress?.completedLessons.contains(widget.lessonId) ?? false;
      await _firebaseDataService.markLessonCompleted(uid, widget.lessonId);
      if (!alreadyDone) {
        await _gamificationService.awardXP(uid, 50, 'Lesson completed');
      }
      if (!mounted) return;
      setState(() => _isCompleted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alreadyDone ? 'Урок пройден!' : 'Урок пройден! +50 XP'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить прогресс. Попробуйте ещё раз.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Урок')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_lesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Урок')),
        body: const EmptyView(
          message: 'Урок не найден',
          subtitle: 'Этот урок может быть недоступен или был удален',
          icon: Icons.menu_book_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_lesson!.getTitle('ru')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _scrollProgress,
            backgroundColor: AppColors.grey200,
            valueColor: const AlwaysStoppedAnimation(AppColors.success),
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lesson info card
            Card(
              color: AppColors.primary.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Урок ${_lesson!.order}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '⏱ ${_lesson!.estimatedTimeMinutes} минут',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_isCompleted)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 32,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Content
            Text(
              _lesson!.getContent('ru'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
            ),

            const SizedBox(height: 32),

            // Media section (if available)
            if (_lesson!.mediaUrls.isNotEmpty) ...[
              Text(
                'Дополнительные материалы',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ..._lesson!.mediaUrls.map((url) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text('Видео ${_lesson!.mediaUrls.indexOf(url) + 1}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Open video player
                      },
                    ),
                  )),
              const SizedBox(height: 32),
            ],

            // Tags
            if (_lesson!.tags.isNotEmpty) ...[
              Text(
                'Темы',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _lesson!.tags
                    .map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor: AppColors.grey100,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),
            ],

            // Practice section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.quiz, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Практика',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Закрепите изученный материал, пройдя короткий тест',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to practice quiz
                        },
                        icon: const Icon(Icons.quiz),
                        label: const Text('Пройти тест'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mark as completed button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isCompleted ? null : _markCompleted,
                icon: Icon(
                  _isCompleted ? Icons.check_circle : Icons.circle_outlined,
                ),
                label: Text(
                  _isCompleted ? 'Пройдено' : 'Отметить как пройденное',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      _isCompleted ? AppColors.success : AppColors.primary,
                  side: BorderSide(
                    color: _isCompleted ? AppColors.success : AppColors.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
