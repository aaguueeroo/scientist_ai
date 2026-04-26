class LiteratureReview {
  const LiteratureReview({
    required this.doesSimilarWorkExist,
    required this.sources,
    required this.totalSources,
    this.isFinal = false,
    this.literatureReviewId,
  });

  final bool doesSimilarWorkExist;
  final List<Source> sources;
  final int totalSources;
  final bool isFinal;
  final String? literatureReviewId;
}

class Source {
  const Source({
    required this.author,
    required this.title,
    required this.dateOfPublication,
    required this.abstractText,
    required this.doi,
    required this.score,
    required this.isVerified,
    this.tier,
    this.unverifiedSimilaritySuggestion = false,
  });

  final String author;
  final String title;
  final DateTime dateOfPublication;
  final String abstractText;
  final String doi;
  /// When false, the UI should not show a DOI line (missing or placeholder).
  bool get hasDisplayableDoi {
    final String t = doi.trim();
    if (t.isEmpty) {
      return false;
    }
    if (t == '10.0000/unspecified') {
      return false;
    }
    return true;
  }
  /// Trust level for this source, from 0.0 (lowest) to 1.0 (highest).
  final double score;
  /// Whether this is an official, verified source.
  final bool isVerified;
  final String? tier;
  final bool unverifiedSimilaritySuggestion;
}
