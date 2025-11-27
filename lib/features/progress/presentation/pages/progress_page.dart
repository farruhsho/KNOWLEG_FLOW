import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_progress_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../providers/auth_provider.dart';

/// Progress page with detailed analytics and charts
class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage>
    with SingleTickerProviderStateMixin {
  final _dataService = FirebaseDataService();
  UserProgressModel? _progress;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _loadProgress();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    try {
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;

      if (currentUser != null) {
        final progress = await _dataService.getUserProgress(currentUser.uid);
        if (mounted) {
          setState(() {
            _progress = progress;
            _isLoading = false;
          });
          _animationController.forward();
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой прогресс'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadProgress();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загрузка прогресса...')
          : _progress == null
              ? ErrorView(
                  message: 'Нет данных о прогрессе',
                  onRetry: _loadProgress,
                )
              : RefreshIndicator(
                  onRefresh: _loadProgress,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats overview
                        _buildAnimatedWidget(_buildStatsOverview(), 0),
                        const SizedBox(height: 24),

                        // AI Forecast
                        _buildAnimatedWidget(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Прогноз ОРТ',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              _buildAIForecast(),
                            ],
                          ),
                          1,
                        ),
                        const SizedBox(height: 24),

                        // Score chart
                        _buildAnimatedWidget(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Динамика баллов',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              _buildScoreChart(),
                            ],
                          ),
                          2,
                        ),
                        const SizedBox(height: 24),

                        // Multi-line subject chart
                        _buildAnimatedWidget(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Прогресс по предметам',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              _buildMultiLineSubjectChart(),
                            ],
                          ),
                          3,
                        ),
                        const SizedBox(height: 24),

                        // Subject progress bars
                        _buildAnimatedWidget(
                          _buildSubjectProgress(),
                          4,
                        ),
                        const SizedBox(height: 24),

                        // Error heatmap
                        _buildAnimatedWidget(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Типичные ошибки',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              _buildErrorHeatmap(),
                            ],
                          ),
                          5,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatsOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Тестов пройдено',
                    value: '${_progress!.testsCompleted}',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Средний балл',
                    value: '${_progress!.averageScore.toInt()}',
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
                    value: '${_progress!.streakDays}',
                    icon: Icons.local_fire_department,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Часов обучения',
                    value: '${_progress!.totalStudyHours}',
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
        color: color.withValues(alpha: 0.1),
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

  Widget _buildScoreChart() {
    // Use real weekly trends data
    final weeklyTrends = _progress?.weeklyTrends ?? {};
    
    List<FlSpot> spots;
    if (weeklyTrends.isNotEmpty) {
      final sortedWeeks = weeklyTrends.keys.toList()..sort();
      spots = sortedWeeks.asMap().entries.map((entry) {
        final index = entry.key.toDouble();
        final week = entry.value;
        final score = weeklyTrends[week]?.toDouble() ?? 0;
        return FlSpot(index, score);
      }).toList();
    } else {
      // Fallback to single point
      final avgScore = _progress?.averageScore ?? 0;
      spots = [FlSpot(0, avgScore.toDouble())];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 20,
                verticalInterval: 1,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (weeklyTrends.isEmpty) return const Text('');
                      final sortedWeeks = weeklyTrends.keys.toList()..sort();
                      final index = value.toInt();
                      if (index >= 0 && index < sortedWeeks.length) {
                        return Text(
                          'Н${index + 1}',
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectProgress() {
    if (_progress!.subjectProgress.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Начните проходить тесты, чтобы увидеть прогресс',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: _progress!.subjectProgress.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${(entry.value * 100).toInt()}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: entry.value,
                    backgroundColor: AppColors.grey200,
                    minHeight: 8,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildErrorHeatmap() {
    // Use real errors by topic data
    final errorsByTopic = _progress?.errorsByTopic ?? {};
    
    List<BarChartGroupData> barGroups;
    List<String> topics;
    
    if (errorsByTopic.isNotEmpty) {
      topics = errorsByTopic.keys.toList();
      barGroups = topics.asMap().entries.map((entry) {
        final index = entry.key;
        final topic = entry.value;
        final errors = errorsByTopic[topic]?.toDouble() ?? 0;
        
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: errors,
              color: _getErrorColor(errors.toInt()),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }).toList();
    } else {
      // Fallback to empty state
      topics = ['Нет данных'];
      barGroups = [
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(
              toY: 0,
              color: AppColors.grey200,
              width: 16,
            ),
          ],
        ),
      ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorsByTopic.isNotEmpty)
              Text(
                'Топ ошибок по темам',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: errorsByTopic.values.isEmpty 
                      ? 10 
                      : (errorsByTopic.values.reduce((a, b) => a > b ? a : b) + 5).toDouble(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex < topics.length) {
                          return BarTooltipItem(
                            '${topics[groupIndex]}\n${rod.toY.toInt()} ошибок',
                            const TextStyle(color: Colors.white),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < topics.length) {
                            final topic = topics[index];
                            final displayText = topic.length > 8 
                                ? '${topic.substring(0, 6)}...' 
                                : topic;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                displayText,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  gridData: const FlGridData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getErrorColor(int errorCount) {
    if (errorCount >= 10) return AppColors.error;
    if (errorCount >= 5) return AppColors.warning;
    if (errorCount >= 2) return AppColors.info;
    return AppColors.success;
  }

  /// Wrap widget with fade and slide animation
  Widget _buildAnimatedWidget(Widget child, int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.1;
        final adjustedValue = (_animationController.value - delay).clamp(0.0, 1.0);
        
        return Opacity(
          opacity: Tween<double>(begin: 0.0, end: 1.0)
              .transform(adjustedValue),
          child: Transform.translate(
            offset: Offset(
              0,
              Tween<double>(begin: 30.0, end: 0.0).transform(adjustedValue),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Build AI forecast card with predicted ORT score
  Widget _buildAIForecast() {
    final predictedScore = _progress?.aiPredictedScore ?? 0;
    final currentScore = _progress?.averageScore ?? 0;
    final confidence = _calculateConfidence(currentScore, predictedScore);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Прогнозируемый балл ОРТ',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'На основе вашего прогресса',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreIndicator(
                  context,
                  label: 'Текущий',
                  score: currentScore,
                  color: AppColors.info,
                ),
                Container(
                  height: 60,
                  width: 1,
                  color: Colors.grey[300],
                ),
                _buildScoreIndicator(
                  context,
                  label: 'Прогноз',
                  score: predictedScore,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: confidence,
              backgroundColor: Colors.grey[200],
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              'Уверенность прогноза: ${(confidence * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(
    BuildContext context, {
    required String label,
    required int score,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          '$score',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          'из 200',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  double _calculateConfidence(int currentScore, int predictedScore) {
    final testsCompleted = _progress?.testsCompleted ?? 0;
    if (testsCompleted < 5) return 0.3;
    if (testsCompleted < 10) return 0.5;
    if (testsCompleted < 20) return 0.7;
    return 0.85;
  }

  /// Build multi-line chart showing progress per subject over time
  Widget _buildMultiLineSubjectChart() {
    final subjectProgress = _progress?.subjectProgress ?? {};
    
    if (subjectProgress.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Начните проходить тесты по разным предметам',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    // Generate mock historical data for demonstration
    // In production, this should come from Firestore
    final subjects = subjectProgress.keys.take(5).toList();
    final colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: true,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'Н${value.toInt() + 1}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: subjects.asMap().entries.map((entry) {
                    final index = entry.key;
                    final subject = entry.value;
                    final progress = subjectProgress[subject] ?? 0.0;
                    
                    // Generate mock trend data
                    final spots = List.generate(6, (i) {
                      final baseProgress = progress * 100;
                      final variation = (i - 2.5) * 5;
                      final value = (baseProgress + variation).clamp(0.0, 100.0);
                      return FlSpot(i.toDouble(), value);
                    });

                    return LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: colors[index % colors.length],
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colors[index % colors.length].withValues(alpha: 0.1),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: subjects.asMap().entries.map((entry) {
                final index = entry.key;
                final subject = entry.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      subject,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
