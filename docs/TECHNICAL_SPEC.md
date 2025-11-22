# 🔧 ORT Master KG — Technical Specification

## Архитектура приоритетных модулей

---

## 1. AI-Учитель 2.0: Техническая реализация

### 1.1 Data Models

```dart
// lib/shared/models/knowledge_graph.dart
class KnowledgeGraph {
  final String userId;
  final Map<String, TopicMastery> topicMasteries;
  final List<WeakPoint> weakPoints;
  final List<StrengthPoint> strengths;
  final double overallMastery;
  final DateTime lastUpdated;

  KnowledgeGraph({
    required this.userId,
    required this.topicMasteries,
    required this.weakPoints,
    required this.strengths,
    required this.overallMastery,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson();
  factory KnowledgeGraph.fromJson(Map<String, dynamic> json);
}

class TopicMastery {
  final String topicId;
  final String topicName;
  final double masteryLevel; // 0.0 - 1.0
  final int questionsAttempted;
  final int questionsCorrect;
  final double averageTimeSeconds;
  final List<MasteryTrend> trends;

  double get accuracy => questionsAttempted > 0
    ? questionsCorrect / questionsAttempted
    : 0.0;
}

class WeakPoint {
  final String topicId;
  final String description;
  final Severity severity; // critical, high, medium, low
  final List<String> relatedQuestionIds;
  final List<Recommendation> recommendations;
}

class Recommendation {
  final String type; // lesson, practice, video, drill
  final String contentId;
  final String title;
  final String description;
  final int estimatedMinutes;
  final double relevanceScore;
}

class DailyPlan {
  final DateTime date;
  final String userId;
  final List<PlannedActivity> activities;
  final int estimatedTotalMinutes;
  final double expectedProgressIncrease;

  Map<String, dynamic> toJson();
}

class PlannedActivity {
  final String type; // lesson, quiz, practice, review
  final String contentId;
  final String title;
  final String description;
  final int durationMinutes;
  final String topicId;
  final Difficulty difficulty;
  final bool isCompleted;
}
```

### 1.2 AI Service Layer

```dart
// lib/features/ai_teacher/data/services/ai_teacher_service.dart
class AITeacherService {
  final FirebaseFirestore _firestore;
  final CloudFunctionsService _functions;

  /// Анализирует ответы пользователя и обновляет Knowledge Graph
  Future<KnowledgeGraph> analyzeUserProgress(String userId) async {
    // 1. Получить все попытки пользователя
    final attempts = await _getUserAttempts(userId);

    // 2. Отправить на Cloud Function для ML анализа
    final analysisResult = await _functions.call(
      'analyzeKnowledge',
      parameters: {
        'userId': userId,
        'attempts': attempts.map((a) => a.toJson()).toList(),
      },
    );

    // 3. Построить Knowledge Graph
    final knowledgeGraph = KnowledgeGraph.fromJson(analysisResult.data);

    // 4. Сохранить в Firestore
    await _saveKnowledgeGraph(knowledgeGraph);

    return knowledgeGraph;
  }

  /// Генерирует персональный план на день
  Future<DailyPlan> generateDailyPlan(String userId) async {
    // 1. Получить Knowledge Graph
    final knowledgeGraph = await _getKnowledgeGraph(userId);

    // 2. Получить профиль пользователя (доступное время, цели)
    final userProfile = await _getUserProfile(userId);

    // 3. Вызвать Cloud Function для генерации плана
    final planResult = await _functions.call(
      'generateDailyPlan',
      parameters: {
        'userId': userId,
        'knowledgeGraph': knowledgeGraph.toJson(),
        'userProfile': userProfile.toJson(),
        'availableMinutes': userProfile.dailyStudyMinutes,
      },
    );

    final plan = DailyPlan.fromJson(planResult.data);

    // 4. Сохранить план
    await _saveDailyPlan(plan);

    return plan;
  }

  /// Генерирует адаптивные вопросы
  Future<List<Question>> getAdaptiveQuestions({
    required String userId,
    required String topicId,
    required int count,
  }) async {
    final knowledgeGraph = await _getKnowledgeGraph(userId);
    final topicMastery = knowledgeGraph.topicMasteries[topicId];

    // Определить оптимальную сложность
    final targetDifficulty = _calculateOptimalDifficulty(topicMastery);

    // Получить вопросы
    final questions = await _firestore
        .collection('questions')
        .where('topicId', isEqualTo: topicId)
        .where('difficulty', isGreaterThanOrEqualTo: targetDifficulty - 0.1)
        .where('difficulty', isLessThanOrEqualTo: targetDifficulty + 0.1)
        .limit(count)
        .get();

    return questions.docs.map((doc) => Question.fromJson(doc.data())).toList();
  }

  /// Анализирует ответ и дает обратную связь
  Future<AnswerFeedback> analyzeAnswer({
    required String userId,
    required String questionId,
    required String userAnswer,
  }) async {
    // 1. Получить вопрос и правильный ответ
    final question = await _getQuestion(questionId);
    final isCorrect = question.correctAnswer == userAnswer;

    // 2. Генерация объяснения через AI
    final explanation = await _functions.call(
      'generateExplanation',
      parameters: {
        'questionId': questionId,
        'userAnswer': userAnswer,
        'isCorrect': isCorrect,
      },
    );

    // 3. Обновить Knowledge Graph
    await _updateKnowledgeGraphFromAnswer(
      userId: userId,
      questionId: questionId,
      isCorrect: isCorrect,
    );

    return AnswerFeedback(
      isCorrect: isCorrect,
      correctAnswer: question.correctAnswer,
      explanation: explanation.data['explanation'],
      recommendedTopics: explanation.data['recommendedTopics'],
    );
  }

  double _calculateOptimalDifficulty(TopicMastery? mastery) {
    if (mastery == null) return 0.3; // Начальный уровень

    // Используем зону ближайшего развития (Zone of Proximal Development)
    // Оптимальная сложность = текущий уровень + 10-20%
    return (mastery.masteryLevel + 0.15).clamp(0.0, 1.0);
  }
}
```

### 1.3 Cloud Functions (Firebase)

```javascript
// functions/src/aiTeacher.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { Configuration, OpenAIApi } from 'openai';

const openai = new OpenAIApi(new Configuration({
  apiKey: functions.config().openai.key,
}));

/**
 * Анализирует знания пользователя и строит Knowledge Graph
 */
export const analyzeKnowledge = functions.https.onCall(async (data, context) => {
  const { userId, attempts } = data;

  // Группировка попыток по темам
  const topicStats = groupByTopic(attempts);

  // Построение mastery levels
  const topicMasteries = {};
  for (const [topicId, stats] of Object.entries(topicStats)) {
    topicMasteries[topicId] = {
      topicId,
      topicName: stats.topicName,
      masteryLevel: calculateMasteryLevel(stats),
      questionsAttempted: stats.total,
      questionsCorrect: stats.correct,
      averageTimeSeconds: stats.avgTime,
      trends: calculateTrends(stats.history),
    };
  }

  // Выявление слабых мест
  const weakPoints = identifyWeakPoints(topicMasteries);

  // Выявление сильных сторон
  const strengths = identifyStrengths(topicMasteries);

  // Общий уровень мастерства
  const overallMastery = calculateOverallMastery(topicMasteries);

  return {
    userId,
    topicMasteries,
    weakPoints,
    strengths,
    overallMastery,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  };
});

/**
 * Генерирует персональный план на день
 */
export const generateDailyPlan = functions.https.onCall(async (data, context) => {
  const { userId, knowledgeGraph, userProfile, availableMinutes } = data;

  const activities = [];
  let totalMinutes = 0;

  // 1. Приоритет слабым темам (60% времени)
  const weakTopicMinutes = Math.floor(availableMinutes * 0.6);
  for (const weakPoint of knowledgeGraph.weakPoints.slice(0, 3)) {
    const activity = await createActivityForWeakPoint(
      weakPoint,
      weakTopicMinutes / 3
    );
    activities.push(activity);
    totalMinutes += activity.durationMinutes;
  }

  // 2. Практика сильных тем (20% времени)
  const strengthMinutes = Math.floor(availableMinutes * 0.2);
  const strengthActivity = await createPracticeActivity(
    knowledgeGraph.strengths[0],
    strengthMinutes
  );
  activities.push(strengthActivity);
  totalMinutes += strengthMinutes;

  // 3. Новый материал (20% времени)
  const newMaterialMinutes = availableMinutes - totalMinutes;
  const newActivity = await createNewMaterialActivity(
    knowledgeGraph,
    newMaterialMinutes
  );
  activities.push(newActivity);

  // Расчет ожидаемого прогресса
  const expectedProgress = calculateExpectedProgress(activities, knowledgeGraph);

  return {
    date: new Date().toISOString(),
    userId,
    activities,
    estimatedTotalMinutes: availableMinutes,
    expectedProgressIncrease: expectedProgress,
  };
});

/**
 * Генерирует объяснение к ответу используя GPT-4
 */
export const generateExplanation = functions.https.onCall(async (data, context) => {
  const { questionId, userAnswer, isCorrect } = data;

  // Получить вопрос из БД
  const questionDoc = await admin.firestore()
    .collection('questions')
    .doc(questionId)
    .get();

  const question = questionDoc.data();

  // Создать prompt для GPT-4
  const prompt = `
Вопрос: ${question.text}
Варианты ответа: ${question.options.join(', ')}
Правильный ответ: ${question.correctAnswer}
Ответ ученика: ${userAnswer}

Задача: Объясни, почему ${isCorrect ? 'это правильный ответ' : 'ответ неправильный и почему правильный ответ ' + question.correctAnswer}.
Используй простой язык, как объяснял бы хороший учитель.
Дай пошаговое объяснение.
`;

  const completion = await openai.createChatCompletion({
    model: 'gpt-4',
    messages: [
      {
        role: 'system',
        content: 'Ты опытный преподаватель, который готовит школьников к ОРТ в Кыргызстане. Объясняй понятно и терпеливо.',
      },
      {
        role: 'user',
        content: prompt,
      },
    ],
    temperature: 0.7,
    max_tokens: 500,
  });

  const explanation = completion.data.choices[0].message.content;

  // Определить связанные темы
  const recommendedTopics = await findRelatedTopics(question.topicId);

  return {
    explanation,
    recommendedTopics,
  };
});

// Вспомогательные функции
function calculateMasteryLevel(stats: any): number {
  // Используем комбинацию точности, скорости и консистентности
  const accuracy = stats.correct / stats.total;
  const speedFactor = Math.min(stats.avgTime / stats.targetTime, 1.0);
  const consistencyFactor = 1 - stats.variance;

  return (accuracy * 0.6 + speedFactor * 0.2 + consistencyFactor * 0.2);
}

function identifyWeakPoints(topicMasteries: any): any[] {
  return Object.values(topicMasteries)
    .filter((tm: any) => tm.masteryLevel < 0.6)
    .sort((a: any, b: any) => a.masteryLevel - b.masteryLevel)
    .slice(0, 5)
    .map((tm: any) => ({
      topicId: tm.topicId,
      description: `Низкий уровень владения: ${Math.round(tm.masteryLevel * 100)}%`,
      severity: tm.masteryLevel < 0.3 ? 'critical' :
                tm.masteryLevel < 0.5 ? 'high' : 'medium',
      recommendations: generateRecommendations(tm),
    }));
}

function generateRecommendations(topicMastery: any): any[] {
  const recommendations = [];

  // Рекомендовать урок если совсем слабо
  if (topicMastery.masteryLevel < 0.4) {
    recommendations.push({
      type: 'lesson',
      title: `Урок: ${topicMastery.topicName}`,
      estimatedMinutes: 15,
      relevanceScore: 0.95,
    });
  }

  // Всегда рекомендовать практику
  recommendations.push({
    type: 'practice',
    title: `Практика: ${topicMastery.topicName}`,
    estimatedMinutes: 20,
    relevanceScore: 0.90,
  });

  // Если средний уровень - дриллы
  if (topicMastery.masteryLevel >= 0.4 && topicMastery.masteryLevel < 0.7) {
    recommendations.push({
      type: 'drill',
      title: `Интенсивная тренировка: ${topicMastery.topicName}`,
      estimatedMinutes: 10,
      relevanceScore: 0.85,
    });
  }

  return recommendations;
}
```

### 1.4 UI Components

```dart
// lib/features/ai_teacher/presentation/pages/ai_teacher_page.dart
class AITeacherPage extends StatefulWidget {
  const AITeacherPage({super.key});

  @override
  State<AITeacherPage> createState() => _AITeacherPageState();
}

class _AITeacherPageState extends State<AITeacherPage> {
  late Future<DailyPlan> _dailyPlanFuture;
  late Future<KnowledgeGraph> _knowledgeGraphFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final aiService = AITeacherService();

    _dailyPlanFuture = aiService.generateDailyPlan(userId);
    _knowledgeGraphFuture = aiService.analyzeUserProgress(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Ваш AI-Учитель'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadData();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadData();
          });
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Plan Section
              _buildDailyPlanSection(),

              const SizedBox(height: 24),

              // Knowledge Graph Section
              _buildKnowledgeGraphSection(),

              const SizedBox(height: 24),

              // Weak Points Section
              _buildWeakPointsSection(),

              const SizedBox(height: 24),

              // Strengths Section
              _buildStrengthsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyPlanSection() {
    return FutureBuilder<DailyPlan>(
      future: _dailyPlanFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ErrorView(
            message: 'Не удалось загрузить план',
            onRetry: _loadData,
          );
        }

        final plan = snapshot.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.today, size: 24, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Сегодняшний план',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                ...plan.activities.map((activity) => _buildActivityTile(activity)),

                const Divider(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Общее время:',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      '${plan.estimatedTotalMinutes} минут',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ожидаемый прогресс:',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      '+${plan.expectedProgressIncrease.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityTile(PlannedActivity activity) {
    IconData icon;
    Color color;

    switch (activity.type) {
      case 'lesson':
        icon = Icons.menu_book;
        color = AppColors.info;
        break;
      case 'practice':
        icon = Icons.fitness_center;
        color = AppColors.warning;
        break;
      case 'quiz':
        icon = Icons.quiz;
        color = AppColors.primary;
        break;
      default:
        icon = Icons.check_circle;
        color = AppColors.success;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _startActivity(activity),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.grey300),
            borderRadius: BorderRadius.circular(12),
            color: activity.isCompleted
              ? AppColors.success.withOpacity(0.1)
              : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
                      activity.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${activity.durationMinutes} минут',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (activity.isCompleted)
                const Icon(Icons.check_circle, color: AppColors.success)
              else
                const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKnowledgeGraphSection() {
    return FutureBuilder<KnowledgeGraph>(
      future: _knowledgeGraphFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final graph = snapshot.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ваш уровень знаний',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),

                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      children: [
                        CircularProgressIndicator(
                          value: graph.overallMastery,
                          strokeWidth: 12,
                          backgroundColor: AppColors.grey200,
                          valueColor: AlwaysStoppedAnimation(
                            _getColorForMastery(graph.overallMastery),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(graph.overallMastery * 100).round()}%',
                                style: Theme.of(context).textTheme.headlineLarge,
                              ),
                              Text(
                                'Общий уровень',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                ...graph.topicMasteries.entries.take(5).map(
                  (entry) => _buildTopicMasteryBar(entry.value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopicMasteryBar(TopicMastery mastery) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mastery.topicName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '${(mastery.masteryLevel * 100).round()}%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _getColorForMastery(mastery.masteryLevel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: mastery.masteryLevel,
            backgroundColor: AppColors.grey200,
            valueColor: AlwaysStoppedAnimation(
              _getColorForMastery(mastery.masteryLevel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakPointsSection() {
    return FutureBuilder<KnowledgeGraph>(
      future: _knowledgeGraphFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.weakPoints.isEmpty) {
          return const SizedBox.shrink();
        }

        final weakPoints = snapshot.data!.weakPoints;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Text(
                      'Слабые темы',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                ...weakPoints.take(3).map((wp) => _buildWeakPointTile(wp)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeakPointTile(WeakPoint weakPoint) {
    Color severityColor;
    switch (weakPoint.severity) {
      case Severity.critical:
        severityColor = AppColors.error;
        break;
      case Severity.high:
        severityColor = AppColors.warning;
        break;
      default:
        severityColor = AppColors.info;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: severityColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: severityColor.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    weakPoint.severity.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    weakPoint.description,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (weakPoint.recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Рекомендации:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...weakPoint.recommendations.take(2).map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec.title,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getColorForMastery(double mastery) {
    if (mastery >= 0.8) return AppColors.success;
    if (mastery >= 0.6) return AppColors.info;
    if (mastery >= 0.4) return AppColors.warning;
    return AppColors.error;
  }

  void _startActivity(PlannedActivity activity) {
    // Navigate to appropriate screen based on activity type
    switch (activity.type) {
      case 'lesson':
        context.go('${AppRouter.lesson}/${activity.contentId}');
        break;
      case 'practice':
      case 'quiz':
        context.go('${AppRouter.quiz}/${activity.contentId}');
        break;
    }
  }
}
```

---

## 2. Геймификация 2.0: Техническая реализация

### 2.1 Data Models

```dart
// lib/shared/models/gamification.dart
class UserGamification {
  final String userId;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int coins;
  final List<Achievement> achievements;
  final List<DailyQuest> dailyQuests;
  final int streakDays;
  final DateTime? lastActivity;
  final Map<String, int> statistics;

  int get completedAchievements =>
    achievements.where((a) => a.isUnlocked).length;

  double get levelProgress => xp / xpToNextLevel;
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final AchievementRarity rarity;
  final int xpReward;
  final int coinsReward;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final AchievementRequirement requirement;
}

enum AchievementRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  secret,
}

class AchievementRequirement {
  final AchievementType type;
  final int targetValue;
  final int currentValue;

  bool get isCompleted => currentValue >= targetValue;
  double get progress => currentValue / targetValue;
}

enum AchievementType {
  testsCompleted,
  questionsAnswered,
  perfectScore,
  streakDays,
  topicMastery,
  speedRun,
  nightOwl,
  earlyBird,
  marathonCompleted,
  olympicsWinner,
}

class DailyQuest {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final int targetValue;
  final int currentValue;
  final int xpReward;
  final int coinsReward;
  final DateTime expiresAt;

  bool get isCompleted => currentValue >= targetValue;
  double get progress => currentValue / targetValue;
}

enum QuestType {
  answerQuestions,
  completeTest,
  studyMinutes,
  perfectAnswers,
  specificTopic,
}
```

### 2.2 Gamification Service

```dart
// lib/features/gamification/data/services/gamification_service.dart
class GamificationService {
  final FirebaseFirestore _firestore;

  /// Награждает пользователя XP
  Future<XPReward> awardXP(String userId, int amount, String reason) async {
    final userGamRef = _firestore.collection('user_gamification').doc(userId);

    return _firestore.runTransaction((transaction) async {
      final userGam = await transaction.get(userGamRef);
      final data = userGam.data()!;

      int currentXP = data['xp'];
      int currentLevel = data['level'];
      int currentCoins = data['coins'];

      int newXP = currentXP + amount;
      int newLevel = currentLevel;
      int bonusCoins = 0;

      // Проверка level up
      while (newXP >= _xpForLevel(newLevel + 1)) {
        newXP -= _xpForLevel(newLevel + 1);
        newLevel++;
        bonusCoins += 100; // Бонус за level up
      }

      transaction.update(userGamRef, {
        'xp': newXP,
        'level': newLevel,
        'coins': currentCoins + bonusCoins,
      });

      // Записать историю
      await _logXPGain(userId, amount, reason, levelUp: newLevel > currentLevel);

      return XPReward(
        xpGained: amount,
        newXP: newXP,
        levelUp: newLevel > currentLevel,
        newLevel: newLevel,
        coinsGained: bonusCoins,
      );
    });
  }

  /// Проверяет и разблокирует достижения
  Future<List<Achievement>> checkAchievements(String userId) async {
    final userGam = await _getUserGamification(userId);
    final stats = await _getUserStatistics(userId);

    final newlyUnlocked = <Achievement>[];

    // Проверка всех возможных достижений
    for (final achievement in _allAchievements) {
      if (achievement.isUnlocked) continue;

      if (_checkAchievementRequirement(achievement, stats)) {
        await _unlockAchievement(userId, achievement);
        newlyUnlocked.add(achievement);
      }
    }

    return newlyUnlocked;
  }

  /// Генерирует ежедневные квесты
  Future<List<DailyQuest>> generateDailyQuests(String userId) async {
    final userGam = await _getUserGamification(userId);
    final knowledgeGraph = await _getKnowledgeGraph(userId);

    final quests = <DailyQuest>[];

    // Квест 1: Ответить на вопросы
    quests.add(DailyQuest(
      id: _generateQuestId(),
      title: 'Ответь на 20 вопросов',
      description: 'Решай задачи, чтобы улучшить свои знания',
      type: QuestType.answerQuestions,
      targetValue: 20,
      currentValue: 0,
      xpReward: 100,
      coinsReward: 50,
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    ));

    // Квест 2: Пройти тест
    quests.add(DailyQuest(
      id: _generateQuestId(),
      title: 'Пройди 1 полный тест',
      description: 'Проверь свои знания в реальных условиях',
      type: QuestType.completeTest,
      targetValue: 1,
      currentValue: 0,
      xpReward: 150,
      coinsReward: 75,
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    ));

    // Квест 3: Слабая тема (персонализированный)
    if (knowledgeGraph.weakPoints.isNotEmpty) {
      final weakTopic = knowledgeGraph.weakPoints.first;
      quests.add(DailyQuest(
        id: _generateQuestId(),
        title: 'Практика: ${weakTopic.topicId}',
        description: 'Поработай над своей слабой темой',
        type: QuestType.specificTopic,
        targetValue: 10,
        currentValue: 0,
        xpReward: 200,
        coinsReward: 100,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      ));
    }

    await _saveDailyQuests(userId, quests);
    return quests;
  }

  /// Обновляет streak
  Future<StreakUpdate> updateStreak(String userId) async {
    final userGamRef = _firestore.collection('user_gamification').doc(userId);

    return _firestore.runTransaction((transaction) async {
      final userGam = await transaction.get(userGamRef);
      final data = userGam.data()!;

      final lastActivity = (data['lastActivity'] as Timestamp?)?.toDate();
      final currentStreak = data['streakDays'] as int;

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      int newStreak = currentStreak;
      bool streakIncreased = false;
      bool streakLost = false;

      if (lastActivity == null) {
        newStreak = 1;
        streakIncreased = true;
      } else {
        final daysSinceLastActivity = now.difference(lastActivity).inDays;

        if (daysSinceLastActivity == 0) {
          // Сегодня уже был актив
          newStreak = currentStreak;
        } else if (daysSinceLastActivity == 1) {
          // Вчера был актив - продолжаем streak
          newStreak = currentStreak + 1;
          streakIncreased = true;
        } else {
          // Streak потерян
          newStreak = 1;
          streakLost = true;
        }
      }

      transaction.update(userGamRef, {
        'streakDays': newStreak,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      return StreakUpdate(
        newStreak: newStreak,
        streakIncreased: streakIncreased,
        streakLost: streakLost,
        previousStreak: currentStreak,
      );
    });
  }

  int _xpForLevel(int level) {
    // Экспоненциальная формула
    return (100 * pow(1.5, level - 1)).round();
  }
}
```

---

## 3. Прогнозирование балла: ML модель

### 3.1 Data Preparation

```python
# ml/score_prediction/data_preparation.py
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

def prepare_features(user_attempts):
    """
    Подготовка features для ML модели
    """
    features = {
        # Accuracy metrics
        'overall_accuracy': calculate_accuracy(user_attempts),
        'math_accuracy': calculate_topic_accuracy(user_attempts, 'math'),
        'logic_accuracy': calculate_topic_accuracy(user_attempts, 'logic'),
        'reading_accuracy': calculate_topic_accuracy(user_attempts, 'reading'),

        # Speed metrics
        'average_time_per_question': calculate_avg_time(user_attempts),
        'math_avg_time': calculate_topic_avg_time(user_attempts, 'math'),
        'logic_avg_time': calculate_topic_avg_time(user_attempts, 'logic'),

        # Consistency metrics
        'accuracy_variance': calculate_accuracy_variance(user_attempts),
        'time_variance': calculate_time_variance(user_attempts),

        # Progress metrics
        'total_questions_attempted': len(user_attempts),
        'total_tests_completed': count_completed_tests(user_attempts),
        'days_of_practice': calculate_practice_days(user_attempts),
        'streak_days': get_streak_days(user_attempts),

        # Mastery levels
        'math_mastery': calculate_mastery_level(user_attempts, 'math'),
        'logic_mastery': calculate_mastery_level(user_attempts, 'logic'),
        'reading_mastery': calculate_mastery_level(user_attempts, 'reading'),

        # Difficulty progression
        'avg_difficulty_attempted': calculate_avg_difficulty(user_attempts),
        'difficulty_trend': calculate_difficulty_trend(user_attempts),

        # Time management
        'questions_skipped_ratio': calculate_skip_ratio(user_attempts),
        'late_answers_ratio': calculate_late_answers_ratio(user_attempts),
    }

    return pd.DataFrame([features])

def train_model():
    """
    Обучение модели на исторических данных
    """
    # Загрузить исторические данные реальных результатов ОРТ
    historical_data = load_historical_ort_data()

    X = prepare_features_batch(historical_data)
    y = historical_data['actual_ort_score']

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    # Нормализация
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # Ensemble of models
    from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
    from sklearn.linear_model import Ridge

    models = {
        'gb': GradientBoostingRegressor(n_estimators=200, max_depth=5),
        'rf': RandomForestRegressor(n_estimators=200, max_depth=10),
        'ridge': Ridge(alpha=1.0),
    }

    for name, model in models.items():
        model.fit(X_train_scaled, y_train)
        score = model.score(X_test_scaled, y_test)
        print(f'{name} R² score: {score}')

    # Сохранить модели
    import joblib
    for name, model in models.items():
        joblib.dump(model, f'models/{name}_score_predictor.pkl')
    joblib.dump(scaler, 'models/scaler.pkl')
```

### 3.2 Prediction Service

```dart
// lib/features/score_prediction/data/services/score_prediction_service.dart
class ScorePredictionService {
  final CloudFunctionsService _functions;

  Future<ScorePrediction> predictScore(String userId) async {
    // Получить все попытки пользователя
    final attempts = await _getUserAttempts(userId);

    // Вызвать Cloud Function с ML моделью
    final result = await _functions.call(
      'predictOrtScore',
      parameters: {
        'userId': userId,
        'attempts': attempts.map((a) => a.toJson()).toList(),
      },
    );

    return ScorePrediction.fromJson(result.data);
  }
}

class ScorePrediction {
  final double expectedScore;
  final double confidenceLow;
  final double confidenceHigh;
  final Map<String, double> topicScores;
  final List<TopicImpact> weakTopicsImpact;
  final List<Recommendation> recommendations;
  final DateTime generatedAt;
}
```

---

Это первая часть технической спецификации. Продолжить с другими модулями?
