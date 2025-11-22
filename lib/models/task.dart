class Task {
  final String id;
  final String title;
  final String description;
  final String category;
  final int difficulty; // 1-5
  final List<Question> questions;
  bool isCompleted;
  DateTime? completedAt;
  int? score;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.questions,
    this.isCompleted = false,
    this.completedAt,
    this.score,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    int? difficulty,
    List<Question>? questions,
    bool? isCompleted,
    DateTime? completedAt,
    int? score,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      questions: questions ?? this.questions,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      score: score ?? this.score,
    );
  }
}

class Question {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });
}
