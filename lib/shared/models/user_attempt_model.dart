import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserAttemptModel extends Equatable {
  final String id;
  final String uid;
  final String testId;
  final String testType; // 'practice', 'mock'
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<AnswerModel> answers;
  final int? score;
  final Map<String, dynamic>? perSectionStats;
  final bool isCompleted;

  const UserAttemptModel({
    required this.id,
    required this.uid,
    required this.testId,
    required this.testType,
    required this.startedAt,
    this.finishedAt,
    this.answers = const [],
    this.score,
    this.perSectionStats,
    this.isCompleted = false,
  });

  factory UserAttemptModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAttemptModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      testId: data['test_id'] ?? '',
      testType: data['test_type'] ?? 'practice',
      startedAt: (data['started_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      finishedAt: (data['finished_at'] as Timestamp?)?.toDate(),
      answers: (data['answers'] as List<dynamic>?)
              ?.map((e) => AnswerModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      score: data['score'],
      perSectionStats: data['per_section'] as Map<String, dynamic>?,
      isCompleted: data['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'test_id': testId,
      'test_type': testType,
      'started_at': Timestamp.fromDate(startedAt),
      'finished_at': finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      'answers': answers.map((e) => e.toMap()).toList(),
      'score': score,
      'per_section': perSectionStats,
      'is_completed': isCompleted,
    };
  }

  int get correctAnswers {
    return answers.where((a) => a.isCorrect).length;
  }

  int get incorrectAnswers {
    return answers.where((a) => !a.isCorrect && a.selectedOption != null).length;
  }

  int get skippedQuestions {
    return answers.where((a) => a.selectedOption == null).length;
  }

  Duration? get totalTime {
    if (finishedAt == null) return null;
    return finishedAt!.difference(startedAt);
  }

  double get averageTimePerQuestion {
    if (finishedAt == null || answers.isEmpty) return 0;
    final totalSeconds = finishedAt!.difference(startedAt).inSeconds;
    return totalSeconds / answers.length;
  }

  @override
  List<Object?> get props => [
        id,
        uid,
        testId,
        testType,
        startedAt,
        finishedAt,
        answers,
        score,
        perSectionStats,
        isCompleted,
      ];
}

class AnswerModel extends Equatable {
  final String questionId;
  final String? selectedOption; // 'A', 'B', 'C', 'D' or null if skipped
  final String correctOption;
  final int timeSpentSeconds;
  final bool isCorrect;

  const AnswerModel({
    required this.questionId,
    this.selectedOption,
    required this.correctOption,
    this.timeSpentSeconds = 0,
    required this.isCorrect,
  });

  factory AnswerModel.fromMap(Map<String, dynamic> map) {
    return AnswerModel(
      questionId: map['question_id'] ?? '',
      selectedOption: map['selected_option'],
      correctOption: map['correct_option'] ?? '',
      timeSpentSeconds: map['time_spent'] ?? 0,
      isCorrect: map['is_correct'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question_id': questionId,
      'selected_option': selectedOption,
      'correct_option': correctOption,
      'time_spent': timeSpentSeconds,
      'is_correct': isCorrect,
    };
  }

  @override
  List<Object?> get props => [
        questionId,
        selectedOption,
        correctOption,
        timeSpentSeconds,
        isCorrect,
      ];
}
