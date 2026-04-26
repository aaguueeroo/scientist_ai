class LiteratureReview {
  const LiteratureReview({
    required this.doesSimilarWorkExist,
    required this.sources,
    required this.totalSources,
  });

  final bool doesSimilarWorkExist;
  final List<Source> sources;
  final int totalSources;
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
  });

  final String author;
  final String title;
  final DateTime dateOfPublication;
  final String abstractText;
  final String doi;
  /// Trust level for this source, from 0.0 (lowest) to 1.0 (highest).
  final double score;
  /// Whether this is an official, verified source.
  final bool isVerified;
}
