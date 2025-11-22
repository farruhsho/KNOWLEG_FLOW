import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/gamification_models.dart';
import '../../../../shared/services/gamification_service.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_view.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _gamificationService = GamificationService();
  late Future<List<AchievementProgress>> _achievementsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAchievements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAchievements() {
    _achievementsFuture =
        _gamificationService.getAchievementsProgress('current_user');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Достижения'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Все'),
            Tab(text: 'Открытые'),
            Tab(text: 'Закрытые'),
          ],
        ),
      ),
      body: FutureBuilder<List<AchievementProgress>>(
        future: _achievementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }

          if (snapshot.hasError) {
            return ErrorView(
              message: 'Не удалось загрузить достижения',
              onRetry: () {
                setState(() {
                  _loadAchievements();
                });
              },
            );
          }

          final achievements = snapshot.data!;
          final unlockedCount =
              achievements.where((a) => a.isUnlocked).length;

          return Column(
            children: [
              // Stats header
              Container(
                padding: const EdgeInsets.all(20),
                color: AppColors.primary.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      'Открыто',
                      '$unlockedCount/${achievements.length}',
                      Icons.emoji_events,
                      AppColors.warning,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.grey300,
                    ),
                    _buildStatItem(
                      context,
                      'Прогресс',
                      '${((unlockedCount / achievements.length) * 100).toInt()}%',
                      Icons.show_chart,
                      AppColors.success,
                    ),
                  ],
                ),
              ),

              // Achievements list
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAchievementsList(achievements),
                    _buildAchievementsList(
                      achievements.where((a) => a.isUnlocked).toList(),
                    ),
                    _buildAchievementsList(
                      achievements.where((a) => !a.isUnlocked).toList(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildAchievementsList(List<AchievementProgress> achievements) {
    if (achievements.isEmpty) {
      return const Center(
        child: Text('Нет достижений в этой категории'),
      );
    }

    // Группировка по редкости
    final grouped = <AchievementRarity, List<AchievementProgress>>{};
    for (final achievement in achievements) {
      grouped.putIfAbsent(achievement.achievement.rarity, () => []);
      grouped[achievement.achievement.rarity]!.add(achievement);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: AchievementRarity.values.map((rarity) {
        final items = grouped[rarity] ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _getColorForRarity(rarity),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getRarityName(rarity),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _getColorForRarity(rarity),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            ...items.map((achievement) =>
                _buildAchievementCard(context, achievement)),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAchievementCard(
    BuildContext context,
    AchievementProgress progress,
  ) {
    final achievement = progress.achievement;
    final isUnlocked = progress.isUnlocked;
    final isSecret = achievement.isSecret && !isUnlocked;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _showAchievementDetails(context, progress),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnlocked
                    ? _getColorForRarity(achievement.rarity)
                    : AppColors.grey300,
                width: isUnlocked ? 2 : 1,
              ),
              color: isUnlocked
                  ? _getColorForRarity(achievement.rarity).withOpacity(0.1)
                  : null,
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? _getColorForRarity(achievement.rarity)
                        : AppColors.grey300,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isUnlocked
                        ? [
                            BoxShadow(
                              color: _getColorForRarity(achievement.rarity)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    _getIconData(achievement.iconName),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isSecret ? '???' : achievement.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          if (isUnlocked)
                            Icon(
                              Icons.check_circle,
                              color: _getColorForRarity(achievement.rarity),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSecret
                            ? 'Секретное достижение'
                            : achievement.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Progress
                      if (!isUnlocked && !isSecret) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress.progress,
                                  backgroundColor: AppColors.grey200,
                                  valueColor: AlwaysStoppedAnimation(
                                    _getColorForRarity(achievement.rarity),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${progress.currentValue}/${achievement.targetValue}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ],

                      // Rewards
                      if (isUnlocked) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildRewardBadge(
                              '+${achievement.xpReward} XP',
                              Icons.star,
                              AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            _buildRewardBadge(
                              '+${achievement.coinsReward}',
                              Icons.monetization_on,
                              Colors.amber,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showAchievementDetails(
    BuildContext context,
    AchievementProgress progress,
  ) {
    final achievement = progress.achievement;
    final isSecret = achievement.isSecret && !progress.isUnlocked;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getIconData(achievement.iconName),
              color: _getColorForRarity(achievement.rarity),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSecret ? 'Секретное достижение' : achievement.title,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSecret) ...[
              Text(
                achievement.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Редкость: ${_getRarityName(achievement.rarity)}',
                style: TextStyle(
                  color: _getColorForRarity(achievement.rarity),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Награда: +${achievement.xpReward} XP'),
              Text('Монеты: +${achievement.coinsReward}'),
              if (!progress.isUnlocked) ...[
                const SizedBox(height: 16),
                Text('Прогресс:'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.progress,
                  backgroundColor: AppColors.grey200,
                  valueColor: AlwaysStoppedAnimation(
                    _getColorForRarity(achievement.rarity),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${progress.currentValue}/${achievement.targetValue}'),
              ],
            ] else ...[
              const Text('Это секретное достижение! Откройте его, чтобы узнать детали.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Color _getColorForRarity(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return AppColors.grey400;
      case AchievementRarity.uncommon:
        return Colors.green;
      case AchievementRarity.rare:
        return Colors.blue;
      case AchievementRarity.epic:
        return Colors.purple;
      case AchievementRarity.legendary:
        return Colors.orange;
      case AchievementRarity.secret:
        return Colors.amber;
    }
  }

  String _getRarityName(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return 'Обычное';
      case AchievementRarity.uncommon:
        return 'Необычное';
      case AchievementRarity.rare:
        return 'Редкое';
      case AchievementRarity.epic:
        return 'Эпическое';
      case AchievementRarity.legendary:
        return 'Легендарное';
      case AchievementRarity.secret:
        return 'Секретное';
    }
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'check_circle': Icons.check_circle,
      'star': Icons.star,
      'local_fire_department': Icons.local_fire_department,
      'quiz': Icons.quiz,
      'emoji_events': Icons.emoji_events,
      'military_tech': Icons.military_tech,
      'workspace_premium': Icons.workspace_premium,
      'nights_stay': Icons.nights_stay,
      'wb_sunny': Icons.wb_sunny,
    };

    return iconMap[iconName] ?? Icons.emoji_events;
  }
}
