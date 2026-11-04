import '../../../l10n/app_localizations.dart';

/// Formatting of practice results (EXAM-03).
///
/// A practice set of ~10 questions says nothing about an ORT score: there is
/// no section weighting and the official conversion is unpublished. Practice
/// is therefore only ever shown as "N of M correct" and a percentage, and
/// every label here is worded as *practice*, never as an ORT/ЖРТ score.
class PracticeScore {
  final int correct;
  final int total;

  const PracticeScore({required this.correct, required this.total});

  /// Rounded percentage 0..100; 0 for an empty set (no NaN — EXAM-15).
  int get percent {
    if (total <= 0) return 0;
    final p = (correct.clamp(0, total) * 100 / total).round();
    return p.clamp(0, 100);
  }

  /// Accuracy band used for wording and colour.
  PracticeBand get band {
    final p = percent;
    if (total == 0) return PracticeBand.none;
    if (p >= 85) return PracticeBand.excellent;
    if (p >= 65) return PracticeBand.good;
    if (p >= 40) return PracticeBand.fair;
    return PracticeBand.low;
  }

  /// "Практика: 70%".
  String headline(AppLocalizations l) => l.learnPracticePercentLabel(percent);

  /// "7 из 10 верно".
  String summary(AppLocalizations l) => l.learnPracticeCorrectOfTotal(correct, total);

  /// Short encouragement for the band.
  String verdict(AppLocalizations l) {
    switch (band) {
      case PracticeBand.excellent:
        return l.learnPracticeVerdictExcellent;
      case PracticeBand.good:
        return l.learnPracticeVerdictGood;
      case PracticeBand.fair:
        return l.learnPracticeVerdictFair;
      case PracticeBand.low:
      case PracticeBand.none:
        return l.learnPracticeVerdictLow;
    }
  }

  /// Every label the results screen prints *about the score* (the separate
  /// "this is not an ORT score" disclaimer is [AppLocalizations.learnPracticeNotOrtNote]).
  List<String> scoreLabels(AppLocalizations l) => [headline(l), summary(l), verdict(l)];
}

enum PracticeBand { none, low, fair, good, excellent }
