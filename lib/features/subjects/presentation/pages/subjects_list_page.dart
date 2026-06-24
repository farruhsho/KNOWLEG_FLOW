import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/components.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../../shared/services/firebase_data_service.dart';

class SubjectsListPage extends StatefulWidget {
  const SubjectsListPage({super.key});

  @override
  State<SubjectsListPage> createState() => _SubjectsListPageState();
}

class _SubjectsListPageState extends State<SubjectsListPage> {
  final _firebaseDataService = FirebaseDataService();
  List<SubjectModel> _subjects = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final subjects = await _firebaseDataService.getSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading subjects: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppTokens.space16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space12),
        itemBuilder: (_, __) => const AppSkeletonCard(),
      );
    }

    if (_hasError) {
      return AppErrorState(onRetry: _loadSubjects);
    }

    if (_subjects.isEmpty) {
      return const AppEmptyState(
        title: 'Предметы не найдены',
        message: 'Скоро здесь появятся учебные предметы',
        icon: Icons.school_outlined,
      );
    }

    return RefreshIndicator(
      color: context.tokens.accent,
      onRefresh: _loadSubjects,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTokens.space16),
        itemCount: _subjects.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.space12),
        itemBuilder: (context, index) {
          final subject = _subjects[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 250 + (index * 60)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, 16 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            ),
            child: _buildSubjectCard(context, subject),
          );
        },
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, SubjectModel subject) {
    final t = context.tokens;
    Color color;
    try {
      color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      color = t.accent;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      onTap: () => context
          .go(AppRouter.subjectDetail.replaceAll(':id', subject.id)),
      child: Row(
        children: [
          Hero(
            tag: 'subject_${subject.id}',
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTokens.radiusButton),
              ),
              child: Center(
                child: Text(
                  subject.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.getTitle('ru'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  subject.getDescription('ru'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTokens.space12),
                Row(
                  children: [
                    AppChip(
                      label: '${subject.totalLessons} уроков',
                      icon: Icons.menu_book_outlined,
                    ),
                    const SizedBox(width: AppTokens.space8),
                    AppChip(
                      label: '${subject.totalQuestions} вопросов',
                      icon: Icons.help_outline,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          Icon(Icons.chevron_right, color: t.textTertiary),
        ],
      ),
    );
  }
}
