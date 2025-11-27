import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Model for daily missions - gamified tasks for users
class DailyMissionModel extends Equatable {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final int rewardXP;
  final String type; // 'test_count', 'study_time', 'lesson_complete', 'streak'
  final int targetCount; // e.g., 5 for "Solve 5 questions"
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;

  const DailyMissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardXP,
    required this.type,
    required this.targetCount,
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
  });

  factory DailyMissionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyMissionModel(
      id: doc.id,
      title: Map<String, String>.from(data['title'] ?? {}),
      description: Map<String, String>.from(data['description'] ?? {}),
      rewardXP: data['reward_xp'] ?? 50,
      type: data['type'] ?? 'test_count',
      targetCount: data['target_count'] ?? 1,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expires_at'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 1)),
      isActive: data['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'reward_xp': rewardXP,
      'type': type,
      'target_count': targetCount,
      'created_at': Timestamp.fromDate(createdAt),
      'expires_at': Timestamp.fromDate(expiresAt),
      'is_active': isActive,
    };
  }

  String getTitle(String locale) {
    return title[locale] ?? title['ru'] ?? '';
  }

  String getDescription(String locale) {
    return description[locale] ?? description['ru'] ?? '';
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        rewardXP,
        type,
        targetCount,
        createdAt,
        expiresAt,
        isActive,
      ];
}

/// User's progress on a daily mission
class UserMissionProgress extends Equatable {
  final String id;
  final String userId;
  final String missionId;
  final int currentProgress;
  final int targetCount;
  final bool isCompleted;
  final DateTime? completedAt;
  final int xpEarned;

  const UserMissionProgress({
    required this.id,
    required this.userId,
    required this.missionId,
    this.currentProgress = 0,
    required this.targetCount,
    this.isCompleted = false,
    this.completedAt,
    this.xpEarned = 0,
  });

  factory UserMissionProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserMissionProgress(
      id: doc.id,
      userId: data['user_id'] ?? '',
      missionId: data['mission_id'] ?? '',
      currentProgress: data['current_progress'] ?? 0,
      targetCount: data['target_count'] ?? 1,
      isCompleted: data['is_completed'] ?? false,
      completedAt: data['completed_at'] != null
          ? (data['completed_at'] as Timestamp).toDate()
          : null,
      xpEarned: data['xp_earned'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'mission_id': missionId,
      'current_progress': currentProgress,
      'target_count': targetCount,
      'is_completed': isCompleted,
      'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'xp_earned': xpEarned,
    };
  }

  double get progressPercentage => currentProgress / targetCount;

  UserMissionProgress copyWith({
    String? id,
    String? userId,
    String? missionId,
    int? currentProgress,
    int? targetCount,
    bool? isCompleted,
    DateTime? completedAt,
    int? xpEarned,
  }) {
    return UserMissionProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      missionId: missionId ?? this.missionId,
      currentProgress: currentProgress ?? this.currentProgress,
      targetCount: targetCount ?? this.targetCount,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      xpEarned: xpEarned ?? this.xpEarned,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        missionId,
        currentProgress,
        targetCount,
        isCompleted,
        completedAt,
        xpEarned,
      ];
}
