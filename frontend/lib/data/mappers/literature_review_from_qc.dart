import '../../models/literature_qc.dart';
import '../../models/literature_review.dart';

/// Build the literature UI model from a persisted [LiteratureQcResult] (GET /plans).
class LiteratureReviewFromQc {
  const LiteratureReviewFromQc._();

  static LiteratureReview? fromQc(
    LiteratureQcResult? qc, {
    String? literatureReviewId,
  }) {
    if (qc == null) {
      return null;
    }
    final bool similar =
        qc.novelty == 'similar_work_exists' || qc.novelty == 'exact_match';
    final List<Source> sources = <Source>[
      for (final QcReference r in qc.references)
        Source(
          author: '',
          title: r.title,
          url: r.url,
          dateOfPublication: DateTime.utc(1970, 1, 1),
          abstractText: r.whyRelevant ?? '',
          doi: r.doi ?? '',
          score: _displayScoreForQcRef(r),
          isVerified: r.verified,
          tier: r.tier,
          unverifiedSimilaritySuggestion: r.isSimilaritySuggestion,
        ),
    ];
    if (qc.similaritySuggestion != null) {
      final QcReference r = qc.similaritySuggestion!;
      sources.add(
        Source(
          author: '',
          title: r.title,
          url: r.url,
          dateOfPublication: DateTime.utc(1970, 1, 1),
          abstractText: r.whyRelevant ?? '',
          doi: r.doi ?? '',
          score: _displayScoreForQcRef(
            r,
            fallbackUnverified: 0.4,
          ),
          isVerified: r.verified,
          tier: r.tier,
          unverifiedSimilaritySuggestion: true,
        ),
      );
    }
    return LiteratureReview(
      doesSimilarWorkExist: similar,
      sources: sources,
      totalSources: sources.isEmpty ? 0 : sources.length,
      isFinal: true,
      literatureReviewId: literatureReviewId,
    );
  }

  static double _displayScoreForQcRef(
    QcReference r, {
    double? fallbackUnverified,
  }) {
    if (r.tavilyScore != null) {
      return r.tavilyScore!.clamp(0.0, 1.0);
    }
    if (fallbackUnverified != null) {
      return fallbackUnverified;
    }
    return r.verified ? 0.9 : 0.35;
  }
}
