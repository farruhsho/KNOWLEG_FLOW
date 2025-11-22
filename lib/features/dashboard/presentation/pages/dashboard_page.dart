import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/gamification_models.dart';
import '../../../../shared/services/gamification_service.dart';
import '../../../../shared/widgets/gamification_bar.dart';
import '../../../../shared/widgets/daily_quests_widget.dart';
import '../../../../providers/task_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Предметы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Тесты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

class _DashboardHome extends ConsumerStatefulWidget {
  const _DashboardHome();

  @override
  ConsumerState<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends ConsumerState<_DashboardHome> {
  final _gamificationService = GamificationService();
  UserGamification? _userGamification;
  List<DailyQuest> _dailyQuests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGamificationData();
  }

  Future<void> _loadGamificationData() async {
    try {
      final gamification = await _gamificationService.getUserGamification('current_user');
      final quests = await _gamificationService.getDailyQuests('current_user');

      // Update streak
      await _gamificationService.updateStreak('current_user');

      setState(() {
        _userGamification = gamification;
        _dailyQuests = quests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadGamificationData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добрый день!',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        'Студент',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {},
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Gamification Bar
              if (_userGamification != null && !_isLoading) ...[
                GamificationBar(
                  gamification: _userGamification!,
                  onTap: () {
                    // Navigate to achievements page
                    context.push(AppRouter.achievements);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Daily Quests
              if (_dailyQuests.isNotEmpty && !_isLoading) ...[
                CompactDailyQuests(
                  quests: _dailyQuests,
                  onViewAll: () {
                    // Show full quests page
                    _showDailyQuestsDialog();
                  },
                ),
                const SizedBox(height: 24),
              ],

            // Progress card
            _buildProgressCard(context),

            const SizedBox(height: 24),

            // ORT Date reminder
            _buildOrtDateCard(context),

            const SizedBox(height: 24),

            // Quick actions
            Text(
              'Быстрые действия',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: 'Задания',
                    icon: Icons.assignment_turned_in,
                    color: AppColors.primary,
                    onTap: () {
                      context.push(AppRouter.tasks);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    title: 'Быстрый тест',
                    icon: Icons.quiz,
                    color: AppColors.secondary,
                    onTap: () {
                      context.go('${AppRouter.quiz}/quick');
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Subjects overview
            Text(
              'Мои предметы',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildSubjectsList(context),

            const SizedBox(height: 24),

            // Mock test CTA
            _buildMockTestCard(context),
          ],
        ),
      ),
      ),
    );
  }

  void _showDailyQuestsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_turned_in, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Ежедневные задания',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: DailyQuestsWidget(
                    quests: _dailyQuests,
                    onQuestTap: (questId) {
                      // Navigate to relevant content based on quest type
                      Navigator.of(context).pop();
                    },
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Мой прогресс',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Пройдено тестов',
                    value: '12',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Средний балл',
                    value: '145',
                    icon: Icons.trending_up,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Дней подряд',
                    value: '7',
                    icon: Icons.local_fire_department,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Часов обучения',
                    value: '24',
                    icon: Icons.access_time,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
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
    return Card(
      color: AppColors.accent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Следующая регистрация ОРТ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.white,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Июль 2025 • testing.kg',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.white.withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectsList(BuildContext context) {
    final subjects = [
      {'name': 'Математика', 'progress': 0.65, 'icon': Icons.calculate},
      {'name': 'Физика', 'progress': 0.42, 'icon': Icons.science},
      {'name': 'Химия', 'progress': 0.58, 'icon': Icons.biotech},
      {'name': 'Биология', 'progress': 0.73, 'icon': Icons.park},
    ];

    return Column(
      children: subjects.map((subject) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Icon(
                subject['icon'] as IconData,
                color: AppColors.primary,
              ),
            ),
            title: Text(subject['name'] as String),
            subtitle: LinearProgressIndicator(
              value: subject['progress'] as double,
              backgroundColor: AppColors.grey200,
            ),
            trailing: Text(
              '${((subject['progress'] as double) * 100).toInt()}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                  ),
            ),
            onTap: () {},
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMockTestCard(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: AppColors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Пробный экзамен ОРТ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.white,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Полная симуляция экзамена ОРТ с реальным форматом и временем',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withOpacity(0.9),
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.push(AppRouter.mockTest.replaceAll(':id', 'demo'));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Начать тест'),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder tabs
class _SubjectsTab extends StatelessWidget {
  const _SubjectsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Предметы'));
  }
}

class _TestsTab extends StatelessWidget {
  const _TestsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Тесты'));
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Профиль',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // User info card
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: const Text('Студент'),
                subtitle: const Text('student@example.com'),
              ),
            ),

            const SizedBox(height: 24),

            // Settings section
            Text(
              'Настройки',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Язык'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('Уведомления'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('Помощь'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Admin section
            Text(
              'Администрирование',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            Card(
              color: Colors.amber[50],
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                title: const Text(
                  'Админ Панель',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Управление контентом'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.go(AppRouter.adminLogin);
                },
              ),
            ),

            const SizedBox(height: 24),

            // Logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go(AppRouter.login);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
