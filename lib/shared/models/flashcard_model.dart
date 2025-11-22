import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class FlashcardModel extends Equatable {
  final String id;
  final String subjectId;
  final Map<String, String> front;
  final Map<String, String> back;
  final List<String> tags;
  final String? imageUrl;
  final DateTime createdAt;

  const FlashcardModel({
    required this.id,
    required this.subjectId,
    required this.front,
    required this.back,
    this.tags = const [],
    this.imageUrl,
    required this.createdAt,
  });

  factory FlashcardModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlashcardModel(
      id: doc.id,
      subjectId: data['subject_id'] ?? '',
      front: Map<String, String>.from(data['front'] ?? {}),
      back: Map<String, String>.from(data['back'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      imageUrl: data['image_url'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subject_id': subjectId,
      'front': front,
      'back': back,
      'tags': tags,
      'image_url': imageUrl,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  String getFront(String locale) {
    return front[locale] ?? front['en'] ?? front['ru'] ?? '';
  }

  String getBack(String locale) {
    return back[locale] ?? back['en'] ?? back['ru'] ?? '';
  }

  @override
  List<Object?> get props => [
        id,
        subjectId,
        front,
        back,
        tags,
        imageUrl,
        createdAt,
      ];
}

// User's progress with a specific flashcard (SRS algorithm)
class UserFlashcardProgress extends Equatable {
  final String flashcardId;
  final String uid;
  final int interval; // Days until next review
  final int repetitions;
  final double easeFactor;
  final DateTime? nextReviewDate;
  final DateTime lastReviewedAt;

  const UserFlashcardProgress({
    required this.flashcardId,
    required this.uid,
    this.interval = 1,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.nextReviewDate,
    required this.lastReviewedAt,
  });

  factory UserFlashcardProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserFlashcardProgress(
      flashcardId: data['flashcard_id'] ?? '',
      uid: data['uid'] ?? '',
      interval: data['interval'] ?? 1,
      repetitions: data['repetitions'] ?? 0,
      easeFactor: (data['ease_factor'] ?? 2.5).toDouble(),
      nextReviewDate: (data['next_review_date'] as Timestamp?)?.toDate(),
      lastReviewedAt:
          (data['last_reviewed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'flashcard_id': flashcardId,
      'uid': uid,
      'interval': interval,
      'repetitions': repetitions,
      'ease_factor': easeFactor,
      'next_review_date':
          nextReviewDate != null ? Timestamp.fromDate(nextReviewDate!) : null,
      'last_reviewed_at': Timestamp.fromDate(lastReviewedAt),
    };
  }

  bool get isDueForReview {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }

  // SRS Algorithm (SuperMemo SM-2 simplified)
  UserFlashcardProgress updateAfterReview(int quality) {
    // quality: 0-5
    // 0-1: Complete blackout, incorrect
    // 2-3: Correct but difficult
    // 4-5: Perfect recall

    if (quality < 3) {
      // Failed - reset to beginning
      return UserFlashcardProgress(
        flashcardId: flashcardId,
        uid: uid,
        interval: 1,
        repetitions: 0,
        easeFactor: easeFactor,
        nextReviewDate: DateTime.now().add(const Duration(days: 1)),
        lastReviewedAt: DateTime.now(),
      );
    }

    // Passed - increase interval
    final newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    final clampedEaseFactor = newEaseFactor < 1.3 ? 1.3 : newEaseFactor;

    int newInterval;
    final newRepetitions = repetitions + 1;

    if (newRepetitions == 1) {
      newInterval = 1;
    } else if (newRepetitions == 2) {
      newInterval = 6;
    } else {
      newInterval = (interval * clampedEaseFactor).round();
    }

    return UserFlashcardProgress(
      flashcardId: flashcardId,
      uid: uid,
      interval: newInterval,
      repetitions: newRepetitions,
      easeFactor: clampedEaseFactor,
      nextReviewDate: DateTime.now().add(Duration(days: newInterval)),
      lastReviewedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        flashcardId,
        uid,
        interval,
        repetitions,
        easeFactor,
        nextReviewDate,
        lastReviewedAt,
      ];
}
