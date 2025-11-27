import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';

/// Admin panel main page
class AdminPanelPage extends ConsumerWidget {
  const AdminPanelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final currentUser = authService.currentUser;

    // Check if user is admin
    // TODO: Implement proper admin role check from Firestore
    final isAdmin = currentUser?.email?.contains('admin') ?? false;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Админ панель')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: AppColors.error),
              SizedBox(height: 16),
              Text(
                'Доступ запрещен',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('У вас нет прав администратора'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ панель'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Statistics cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Пользователи',
                  value: '1,234',
                  icon: Icons.people,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Тесты',
                  value: '156',
                  icon: Icons.assignment,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Вопросы',
                  value: '4,521',
                  icon: Icons.quiz,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Уроки',
                  value: '89',
                  icon: Icons.school,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Management sections
          Text(
            'Управление контентом',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          _buildManagementCard(
            context,
            title: 'Управление тестами',
            subtitle: 'Создание, редактирование и удаление тестов',
            icon: Icons.assignment,
            color: AppColors.primary,
            onTap: () {
              context.push('/admin/tests');
            },
          ),
          const SizedBox(height: 12),
          
          _buildManagementCard(
            context,
            title: 'Управление вопросами',
            subtitle: 'Добавление и редактирование вопросов',
            icon: Icons.quiz,
            color: AppColors.secondary,
            onTap: () {
              context.push('/admin/questions');
            },
          ),
          const SizedBox(height: 12),
          
          _buildManagementCard(
            context,
            title: 'AI генератор тестов',
            subtitle: 'Автоматическая генерация вопросов',
            icon: Icons.auto_awesome,
            color: AppColors.success,
            onTap: () {
              context.push('/admin/ai-generator');
            },
          ),
          const SizedBox(height: 12),
          
          _buildManagementCard(
            context,
            title: 'Управление уроками',
            subtitle: 'Создание и редактирование уроков',
            icon: Icons.school,
            color: AppColors.info,
            onTap: () {
              context.push('/admin/lessons');
            },
          ),
          const SizedBox(height: 12),
          
          _buildManagementCard(
            context,
            title: 'Управление миссиями',
            subtitle: 'Настройка ежедневных заданий',
            icon: Icons.stars,
            color: AppColors.warning,
            onTap: () {
              context.push('/admin/missions');
            },
          ),
          const SizedBox(height: 12),
          
          _buildManagementCard(
            context,
            title: 'Управление пользователями',
            subtitle: 'Просмотр и модерация пользователей',
            icon: Icons.people,
            color: AppColors.accent,
            onTap: () {
              context.push('/admin/users');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementCard(
    BuildContext context, {
    required String title,
    required String subtitle,
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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
