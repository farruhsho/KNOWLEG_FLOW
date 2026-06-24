import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/components.dart';
import '../../../../shared/models/gamification_models.dart';
import '../../../../shared/models/user_progress_model.dart';
import '../../../../shared/services/gamification_service.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/widgets/gamification_bar.dart';
import '../../../../shared/widgets/daily_quests_widget.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _DashboardHome(),
          _SubjectsTab(),
          _TestsTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Главная',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Предметы',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Тесты',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  const _DashboardHome();

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  final _gamificationService = GamificationService();
  final _firebaseDataService = FirebaseDataService();
  UserGamification? _userGamification;
  UserProgressModel? _userProgress;
  List<DailyQuest> _dailyQuests = [];
  bool _isLoading = true;
  bool _hasError = false;

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'current_user';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _hasError = false);
    try {
      final userId = _currentUserId;
      final results = await Future.wait([
        _gamificationService.getUserGamification(userId),
        _gamificationService.getDailyQuests(userId),
        _firebaseDataService.getUserProgress(userId),
      ]);
      await _gamificationService.updateStreak(userId);
      if (!mounted) return;
      setState(() {
        _userGamification = results[0] as UserGamification;
        _dailyQuests = results[1] as List<DailyQuest>;
        _userProgress = results[2] as UserProgressModel?;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_isLoading) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.space16),
          children: const [
            AppSkeleton(width: 120, height: 14),
            SizedBox(height: 8),
            AppSkeleton(width: 180, height: 24),
            SizedBox(height: 24),
            AppSkeleton(height: 88, radius: 12),
            SizedBox(height: 16),
            AppSkeleton(height: 140, radius: 12),
            SizedBox(height: 24),
            AppSkeletonCard(),
            SizedBox(height: 12),
            AppSkeletonCard(),
          ],
        ),
      );
    }

    if (_hasError) {
      return SafeArea(child: AppErrorState(onRetry: _loadData));
    }

    return SafeArea(
      child: RefreshIndicator(
        color: t.accent,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(AppTokens.space16),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Студент',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
              ],
            ),

            const SizedBox(height: AppTokens.space24),

            if (_userGamification != null) ...[
              GamificationBar(
                gamification: _userGamification!,
                onTap: () => context.go(AppRouter.achievements),
              ),
              const SizedBox(height: AppTokens.space16),
            ],

            if (_dailyQuests.isNotEmpty) ...[
              CompactDailyQuests(
                quests: _dailyQuests,
                onViewAll: _showDailyQuestsDialog,
              ),
              const SizedBox(height: AppTokens.space24),
            ],

            _buildProgressCard(context),
            const SizedBox(height: AppTokens.space16),

            _buildOrtDateCard(context),
            const SizedBox(height: AppTokens.space24),

            const SectionHeader(title: 'Быстрые действия'),
            const SizedBox(height: AppTokens.space12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: 'Урок дня',
                    icon: Icons.menu_book_outlined,
                    onTap: () => context.go('${AppRouter.lesson}/daily'),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: 'Быстрый тест',
                    icon: Icons.bolt_outlined,
                    onTap: () => context.go('${AppRouter.quiz}/quick'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTokens.space24),

            const SectionHeader(title: 'Мои предметы'),
            const SizedBox(height: AppTokens.space12),
            _buildSubjectsList(context),

            const SizedBox(height: AppTokens.space24),

            _buildMockTestCard(context),
            const SizedBox(height: AppTokens.space16),
          ],
        ),
      ),
    );
  }

  void _showDailyQuestsDialog() {
    final t = context.tokens;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTokens.space20),
                child: Row(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, color: t.accent),
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: Text(
                        'Ежедневные задания',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTokens.space20),
                  child: DailyQuestsWidget(
                    quests: _dailyQuests,
                    onQuestTap: (questId) => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Мой прогресс', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTokens.space16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Пройдено тестов',
                  value: '${_userProgress?.testsCompleted ?? 0}',
                  icon: Icons.check_circle_outline,
                  color: t.success,
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Средний балл',
                  value: '${_userProgress?.averageScore ?? 0}',
                  icon: Icons.trending_up,
                  color: t.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Дней подряд',
                  value: '${_userProgress?.streakDays ?? 0}',
                  icon: Icons.local_fire_department_outlined,
                  color: t.warning,
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: _buildStatItem(
                  context,
                  label: 'Часов обучения',
                  value: '${_userProgress?.totalStudyHours ?? 0}',
                  icon: Icons.schedule_outlined,
                  color: t.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: t.section,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: t.textPrimary),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrtDateCard(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.accentTint,
      borderColor: t.accent.withValues(alpha: 0.25),
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTokens.radiusButton),
            ),
            child: Icon(Icons.calendar_today_outlined, color: t.accent),
          ),
          const SizedBox(width: AppTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Следующая регистрация ОРТ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Июль 2025 • testing.kg',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.textTertiary),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: t.accentTint,
              borderRadius: BorderRadius.circular(AppTokens.radiusButton),
            ),
            child: Icon(icon, color: t.accent, size: 24),
          ),
          const SizedBox(height: AppTokens.space12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList(BuildContext context) {
    final t = context.tokens;
    final subjectIcons = {
      'math': Icons.calculate_outlined,
      'physics': Icons.science_outlined,
      'chemistry': Icons.biotech_outlined,
      'biology': Icons.park_outlined,
      'history': Icons.history_edu_outlined,
    };
    final subjectNames = {
      'math': 'Математика',
      'physics': 'Физика',
      'chemistry': 'Химия',
      'biology': 'Биология',
      'history': 'История',
    };

    if (_userProgress == null || _userProgress!.subjectProgress.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.insights_outlined, color: t.textTertiary),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(
                'Начните проходить тесты, чтобы увидеть прогресс по предметам',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final entries = _userProgress!.subjectProgress.entries.toList();
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: AppTokens.space12),
          Builder(builder: (context) {
            final subjectId = entries[i].key;
            final progress = entries[i].value;
            final color = AppColors.getSubjectColor(subjectId);
            final icon = subjectIcons[subjectId] ?? Icons.menu_book_outlined;
            final name = subjectNames[subjectId] ?? subjectId;
            return AppCard(
              padding: const EdgeInsets.all(AppTokens.space16),
              onTap: () => context.push('/subjects/$subjectId'),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusButton),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: AppTokens.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: t.section,
                            valueColor: AlwaysStoppedAnimation(color),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildMockTestCard(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppTokens.space20),
      decoration: BoxDecoration(
        color: AppColors.grey900,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                ),
                child: const Icon(Icons.assignment_outlined,
                    color: AppColors.white, size: 22),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Text(
                  'Пробный экзамен ОРТ',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          Text(
            'Полная симуляция экзамена ОРТ с реальным форматом и временем',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.75),
                ),
          ),
          const SizedBox(height: AppTokens.space16),
          AppButton(
            label: 'Начать тест',
            icon: Icons.play_arrow_rounded,
            expand: false,
            onPressed: () => context.go('${AppRouter.mockTest}/demo'),
          ),
        ],
      ),
    );
  }
}

// Placeholder tabs
class _SubjectsTab extends StatelessWidget {
  const _SubjectsTab();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: AppEmptyState(
        title: 'Предметы',
        message: 'Раздел предметов скоро появится здесь.',
        icon: Icons.menu_book_outlined,
      ),
    );
  }
}

class _TestsTab extends StatelessWidget {
  const _TestsTab();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: AppEmptyState(
        title: 'Тесты',
        message: 'Раздел тестов скоро появится здесь.',
        icon: Icons.assignment_outlined,
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.space16),
        children: [
          Text('Профиль', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppTokens.space20),

          // User info card
          AppCard(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: t.accentTint,
                  child: Icon(Icons.person_outline, color: t.accent),
                ),
                const SizedBox(width: AppTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Студент',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('student@example.com',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTokens.space24),
          const SectionHeader(title: 'Настройки'),
          const SizedBox(height: AppTokens.space12),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingTile(context, Icons.language_outlined, 'Язык'),
                Divider(height: 1, color: t.border),
                _settingTile(
                    context, Icons.notifications_outlined, 'Уведомления'),
                Divider(height: 1, color: t.border),
                _settingTile(context, Icons.help_outline, 'Помощь'),
              ],
            ),
          ),

          const SizedBox(height: AppTokens.space24),
          const SectionHeader(title: 'Администрирование'),
          const SizedBox(height: AppTokens.space12),

          AppCard(
            padding: EdgeInsets.zero,
            child: _settingTile(
              context,
              Icons.admin_panel_settings_outlined,
              'Админ Панель',
              subtitle: 'Управление контентом',
              onTap: () => context.go(AppRouter.adminLogin),
            ),
          ),

          const SizedBox(height: AppTokens.space24),

          AppButton(
            label: 'Выйти',
            icon: Icons.logout,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.go(AppRouter.login),
          ),
        ],
      ),
    );
  }

  Widget _settingTile(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final t = context.tokens;
    return ListTile(
      leading: Icon(icon, color: t.textSecondary),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: subtitle != null
          ? Text(subtitle, style: Theme.of(context).textTheme.bodySmall)
          : null,
      trailing: Icon(Icons.chevron_right, color: t.textTertiary),
      onTap: onTap ?? () {},
    );
  }
}
