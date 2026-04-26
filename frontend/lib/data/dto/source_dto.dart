class SourceDto {
  const SourceDto({
    required this.author,
    required this.title,
    this.url,
    required this.dateOfPublication,
    required this.abstractText,
    required this.doi,
    this.score,
    this.isVerified,
    this.verified,
    this.tier,
    this.unverifiedSimilaritySuggestion = false,
  });

  factory SourceDto.fromJson(Map<String, dynamic> json) {
    final bool? legacyVerified = json['is_verified'] as bool?;
    final bool? beVerified = json['verified'] as bool?;
    final double? tavily = (json['tavily_score'] as num?)?.toDouble();
    final double? legacyScore = (json['score'] as num?)?.toDouble();
    return SourceDto(
      author: json['author'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String?,
      dateOfPublication: json['date_of_publication'] as String? ?? '1970-01-01',
      abstractText: json['abstract'] as String? ?? '',
      doi: json['doi'] as String? ?? '',
      score: tavily ?? legacyScore,
      isVerified: legacyVerified,
      verified: beVerified,
      tier: json['tier'] as String?,
      unverifiedSimilaritySuggestion:
          json['unverified_similarity_suggestion'] as bool? ?? false,
    );
  }

  final String author;
  final String title;
  final String? url;
  // ISO 8601 date (YYYY-MM-DD).
  final String dateOfPublication;
  final String abstractText;
  final String doi;
  final double? score;
  final bool? isVerified;
  final bool? verified;
  final String? tier;
  final bool unverifiedSimilaritySuggestion;

  bool get resolvedVerified => verified ?? isVerified ?? false;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'author': author,
      'title': title,
      if (url != null) 'url': url,
      'date_of_publication': dateOfPublication,
      'abstract': abstractText,
      'doi': doi,
      'tavily_score': score,
      'score': score,
      'is_verified': isVerified,
      'verified': verified,
      'tier': tier,
      'unverified_similarity_suggestion': unverifiedSimilaritySuggestion,
    };
  }
}
