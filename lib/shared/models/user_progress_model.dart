import 'package:cloud_firestore/cloud_firestore.dart';

/// Модель прогресса пользователя
class UserProgressModel {
  final String userId;
  final int testsCompleted;
  final int averageScore;
  final int streakDays;
  final int totalStudyHours;
  final Map<String, double> subjectProgress; // subjectId -> progress (0.0 - 1.0)
  final List<String> completedLessons;
  final DateTime? lastActivityDate;

  UserProgressModel({
    required this.userId,
    required this.testsCompleted,
    required this.averageScore,
    required this.streakDays,
    required this.totalStudyHours,
    required this.subjectProgress,
    required this.completedLessons,
    this.lastActivityDate,
  });

  /// Создать из Firestore
  factory UserProgressModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserProgressModel(
      userId: id,
      testsCompleted: data['testsCompleted'] ?? 0,
      averageScore: data['averageScore'] ?? 0,
      streakDays: data['streakDays'] ?? 0,
      totalStudyHours: data['totalStudyHours'] ?? 0,
      subjectProgress: Map<String, double>.from(data['subjectProgress'] ?? {}),
      completedLessons: List<String>.from(data['completedLessons'] ?? []),
      lastActivityDate: data['lastActivityDate'] != null
          ? (data['lastActivityDate'] as Timestamp).toDate()
          : null,
    );
  }

  /// Конвертировать в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'testsCompleted': testsCompleted,
      'averageScore': averageScore,
      'streakDays': streakDays,
      'totalStudyHours': totalStudyHours,
      'subjectProgress': subjectProgress,
      'completedLessons': completedLessons,
      'lastActivityDate': lastActivityDate != null
          ? Timestamp.fromDate(lastActivityDate!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Копировать с изменениями
  UserProgressModel copyWith({
    String? userId,
    int? testsCompleted,
    int? averageScore,
    int? streakDays,
    int? totalStudyHours,
    Map<String, double>? subjectProgress,
    List<String>? completedLessons,
    DateTime? lastActivityDate,
  }) {
    return UserProgressModel(
      userId: userId ?? this.userId,
      testsCompleted: testsCompleted ?? this.testsCompleted,
      averageScore: averageScore ?? this.averageScore,
      streakDays: streakDays ?? this.streakDays,
      totalStudyHours: totalStudyHours ?? this.totalStudyHours,
      subjectProgress: subjectProgress ?? this.subjectProgress,
      completedLessons: completedLessons ?? this.completedLessons,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
    );
  }
}
