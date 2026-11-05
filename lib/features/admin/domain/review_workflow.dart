import 'admin_role.dart';

/// `exam_questions.review.status` — ARCHITECTURE.md §1.3:
/// `draft` → `ai_verified` → `methodologist_approved` (or `rejected`).
enum ReviewStatus {
  draft('draft'),
  aiVerified('ai_verified'),
  methodologistApproved('methodologist_approved'),
  rejected('rejected');

  const ReviewStatus(this.wire);
  final String wire;

  /// Tolerant parser: unknown / missing values are treated as [draft] so an
  /// unreviewed question can never look approved.
  static ReviewStatus parse(Object? value) {
    if (value is String) {
      final v = value.trim().toLowerCase();
      for (final s in values) {
        if (s.wire == v) return s;
      }
      if (v == 'approved') return ReviewStatus.methodologistApproved;
    }
    return ReviewStatus.draft;
  }
}

abstract final class ReviewWorkflow {
  /// Status changes [role] may apply to a question currently in [from].
  ///
  /// * `review_questions` (super_admin, methodologist): approve, reject or send
  ///   back to draft from any state.
  /// * `edit_questions` without review rights (content_manager): only move
  ///   between `draft` and `ai_verified`, and resubmit a rejected question.
  /// * Everyone else: nothing.
  static List<ReviewStatus> allowedTargets(ReviewStatus from, AdminRole role) {
    if (role.can(AdminPermission.reviewQuestions)) {
      return ReviewStatus.values.where((s) => s != from).toList();
    }
    if (!role.can(AdminPermission.editQuestions)) return const [];
    switch (from) {
      case ReviewStatus.draft:
        return const [ReviewStatus.aiVerified];
      case ReviewStatus.aiVerified:
        return const [ReviewStatus.draft];
      case ReviewStatus.rejected:
        return const [ReviewStatus.draft];
      case ReviewStatus.methodologistApproved:
        return const [];
    }
  }

  static bool canTransition(ReviewStatus from, ReviewStatus to, AdminRole role) =>
      allowedTargets(from, role).contains(to);

  /// Status a question gets after [role] edits its content. Any content edit by
  /// someone who cannot review invalidates a previous verification/approval,
  /// so the question goes back to `draft`; reviewers keep the status.
  static ReviewStatus statusAfterContentEdit(ReviewStatus current, AdminRole role) {
    if (role.can(AdminPermission.reviewQuestions)) return current;
    return ReviewStatus.draft;
  }
}
