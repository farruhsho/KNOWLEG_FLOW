import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_typography.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/stat_card.dart';

/// Main admin dashboard page
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() =>
      _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _isSidebarCollapsed = false;
  String _currentRoute = '/admin/dashboard';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AdminSidebar(
            isCollapsed: _isSidebarCollapsed,
            currentRoute: _currentRoute,
            onNavigate: (route) {
              setState(() {
                _currentRoute = route;
              });
              // TODO: Navigate to route
            },
            onToggle: () {
              setState(() {
                _isSidebarCollapsed = !_isSidebarCollapsed;
              });
            },
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(
          bottom: BorderSide(color: AdminColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
      child: Row(
        children: [
          Text(
            'ORT Master Admin',
            style: AdminTypography.h5.copyWith(
              color: AdminColors.textPrimary,
            ),
          ),
          const Spacer(),
          // Notifications
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AdminColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
          const SizedBox(width: AdminSpacing.sm),
          // User menu
          PopupMenuButton(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AdminColors.primary,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: AdminColors.textOnPrimary,
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Админ Админов',
                      style: AdminTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Администратор',
                      style: AdminTypography.bodySmall.copyWith(
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AdminSpacing.xs),
                const Icon(Icons.keyboard_arrow_down, size: 16),
              ],
            ),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Профиль'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Настройки'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: AdminColors.error),
                    SizedBox(width: 8),
                    Text('Выход', style: TextStyle(color: AdminColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      color: AdminColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: AdminSpacing.xl),
            _buildStatsGrid(),
            const SizedBox(height: AdminSpacing.xl),
            _buildChartsSection(),
            const SizedBox(height: AdminSpacing.xl),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Добро пожаловать, Админ!',
          style: AdminTypography.h3,
        ),
        const SizedBox(height: AdminSpacing.xs),
        Row(
          children: [
            const Icon(
              Icons.access_time,
              size: 16,
              color: AdminColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              'Последний вход: сегодня, 09:45',
              style: AdminTypography.bodyMedium.copyWith(
                color: AdminColors.textSecondary,
              ),
            ),
            const SizedBox(width: AdminSpacing.md),
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: AdminColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '27 ноября 2024',
              style: AdminTypography.bodyMedium.copyWith(
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
                ? 3
                : constraints.maxWidth > 600
                    ? 2
                    : 1;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AdminSpacing.md,
          crossAxisSpacing: AdminSpacing.md,
          childAspectRatio: 1.5,
          children: const [
            StatCard(
              title: 'Студентов',
              value: 12847,
              icon: Icons.people,
              iconColor: AdminColors.primary,
              trendPercentage: 12,
              trendPeriod: 'мес',
            ),
            StatCard(
              title: 'Вопросов',
              value: 4521,
              icon: Icons.quiz,
              iconColor: AdminColors.secondary,
              subtitle: '↑45 сегодня',
              trendPercentage: 8,
              trendPeriod: 'нед',
            ),
            StatCard(
              title: 'Тестов',
              value: 156,
              icon: Icons.assignment,
              iconColor: AdminColors.accent,
              subtitle: '↑8 новых',
              trendPercentage: 5,
              trendPeriod: 'мес',
            ),
            StatCard(
              title: 'Рейтинг',
              value: 89,
              icon: Icons.star,
              iconColor: AdminColors.warning,
              subtitle: '89%',
              trendPercentage: 2,
              trendPeriod: 'мес',
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildActivityChart(),
        ),
        const SizedBox(width: AdminSpacing.md),
        Expanded(
          child: _buildTopUsers(),
        ),
      ],
    );
  }

  Widget _buildActivityChart() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusLg),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📈 АКТИВНОСТЬ СТУДЕНТОВ',
            style: AdminTypography.h6,
          ),
          const SizedBox(height: AdminSpacing.lg),
          // TODO: Add fl_chart here
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Text(
              'График активности (fl_chart)',
              style: AdminTypography.bodyMedium.copyWith(
                color: AdminColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopUsers() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusLg),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏆 ТОП СТУДЕНТОВ',
            style: AdminTypography.h6,
          ),
          const SizedBox(height: AdminSpacing.lg),
          ...List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: AdminSpacing.sm),
              child: Row(
                children: [
                  Text(
                    '${index + 1}.',
                    style: AdminTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  if (index < 3)
                    Icon(
                      index == 0
                          ? Icons.emoji_events
                          : index == 1
                              ? Icons.emoji_events_outlined
                              : Icons.emoji_events_outlined,
                      size: 16,
                      color: index == 0
                          ? AdminColors.warning
                          : index == 1
                              ? AdminColors.textSecondary
                              : AdminColors.accent,
                    ),
                  const SizedBox(width: AdminSpacing.xs),
                  Expanded(
                    child: Text(
                      ['Айдай', 'Бекзат', 'Гулиза', 'Данияр', 'Елена'][index],
                      style: AdminTypography.bodyMedium,
                    ),
                  ),
                  Text(
                    '${[98, 96, 94, 93, 91][index]}%',
                    style: AdminTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AdminColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusLg),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📋 ПОСЛЕДНИЕ ДЕЙСТВИЯ',
                style: AdminTypography.h6,
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Все →'),
              ),
            ],
          ),
          const Divider(),
          ...List.generate(
            5,
            (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
              child: Row(
                children: [
                  Text(
                    '09:${45 - index * 13}',
                    style: AdminTypography.bodySmall.copyWith(
                      color: AdminColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  Icon(
                    [
                      Icons.check_circle,
                      Icons.edit,
                      Icons.person_add,
                      Icons.warning,
                      Icons.psychology
                    ][index],
                    size: 16,
                    color: [
                      AdminColors.success,
                      AdminColors.info,
                      AdminColors.primary,
                      AdminColors.warning,
                      AdminColors.secondary
                    ][index],
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Text(
                      [
                        'Админ добавил 25 вопросов в "Математика"',
                        'Модератор отредактировал тест #156',
                        'Новый пользователь: user@example.com',
                        'Жалоба на вопрос #Q-4521',
                        'AI сгенерировал 50 вопросов'
                      ][index],
                      style: AdminTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
