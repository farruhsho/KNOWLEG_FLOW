import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Answers from the onboarding questionnaire (ONB-01).
///
/// Collected before or after sign-in; stored locally until a user is signed
/// in and then merged into `users/{uid}` using the existing snake_case fields
/// (`preferred_language`, `grade`, `target_universities`, `region`) plus
/// `daily_goal_minutes`, `goal_band` and `onboarding_completed_at`.
@immutable
class OnboardingAnswers {
  const OnboardingAnswers({
    this.language,
    this.grade,
    this.goalBand,
    this.targetUniversity,
    this.oblast,
    this.district,
    this.dailyGoalMinutes,
  });

  /// 'ru' | 'ky' — UI language and the language of the exams.
  final String? language;

  /// 9, 10, 11 or [gradeGraduate].
  final int? grade;

  /// One of [goalBands].
  final String? goalBand;

  final String? targetUniversity;
  final String? oblast;
  final String? district;

  /// One of [dailyGoalOptions].
  final int? dailyGoalMinutes;

  static const int gradeGraduate = 0;
  static const List<int> gradeOptions = [9, 10, 11, gradeGraduate];
  static const List<String> goalBands = ['110+', '150+', '190+'];
  static const List<int> dailyGoalOptions = [10, 20, 30];

  bool get isEmpty =>
      language == null &&
      grade == null &&
      goalBand == null &&
      (targetUniversity == null || targetUniversity!.trim().isEmpty) &&
      oblast == null &&
      dailyGoalMinutes == null;

  OnboardingAnswers copyWith({
    String? language,
    int? grade,
    String? goalBand,
    bool clearGoalBand = false,
    String? targetUniversity,
    String? oblast,
    String? district,
    bool clearDistrict = false,
    int? dailyGoalMinutes,
  }) {
    return OnboardingAnswers(
      language: language ?? this.language,
      grade: grade ?? this.grade,
      goalBand: clearGoalBand ? null : (goalBand ?? this.goalBand),
      targetUniversity: targetUniversity ?? this.targetUniversity,
      oblast: oblast ?? this.oblast,
      district: clearDistrict ? null : (district ?? this.district),
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        if (language != null) 'language': language,
        if (grade != null) 'grade': grade,
        if (goalBand != null) 'goal_band': goalBand,
        if (targetUniversity != null) 'target_university': targetUniversity,
        if (oblast != null) 'oblast': oblast,
        if (district != null) 'district': district,
        if (dailyGoalMinutes != null) 'daily_goal_minutes': dailyGoalMinutes,
      };

  factory OnboardingAnswers.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    String? asString(Object? v) => v is String && v.isNotEmpty ? v : null;
    final language = asString(json['language']);
    final grade = asInt(json['grade']);
    final band = asString(json['goal_band']);
    final minutes = asInt(json['daily_goal_minutes']);
    return OnboardingAnswers(
      language: language == 'ru' || language == 'ky' ? language : null,
      grade: gradeOptions.contains(grade) ? grade : null,
      goalBand: goalBands.contains(band) ? band : null,
      targetUniversity: asString(json['target_university']),
      oblast: asString(json['oblast']),
      district: asString(json['district']),
      dailyGoalMinutes: dailyGoalOptions.contains(minutes) ? minutes : null,
    );
  }

  /// Fields to merge into `users/{uid}`. Only answered questions are written,
  /// so skipping never overwrites existing profile data.
  Map<String, dynamic> toUserFields({Object? completedAt}) {
    final university = targetUniversity?.trim();
    return {
      if (language != null) 'preferred_language': language,
      if (grade != null) 'grade': grade,
      if (goalBand != null) 'goal_band': goalBand,
      if (university != null && university.isNotEmpty)
        'target_universities': [university],
      if (oblast != null)
        'region': {
          'oblast': oblast,
          'district': district ?? '',
          'settlement': '',
        },
      if (dailyGoalMinutes != null) 'daily_goal_minutes': dailyGoalMinutes,
      'onboarding_completed_at': completedAt ?? FieldValue.serverTimestamp(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is OnboardingAnswers &&
      other.language == language &&
      other.grade == grade &&
      other.goalBand == goalBand &&
      other.targetUniversity == targetUniversity &&
      other.oblast == oblast &&
      other.district == district &&
      other.dailyGoalMinutes == dailyGoalMinutes;

  @override
  int get hashCode => Object.hash(language, grade, goalBand, targetUniversity,
      oblast, district, dailyGoalMinutes);
}
