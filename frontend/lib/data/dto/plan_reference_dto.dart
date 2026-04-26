/// Shared reference shape (QC references, plan references, SSE sources overlap).
class PlanReferenceDto {
  const PlanReferenceDto({
    required this.title,
    this.url,
    this.doi,
    this.whyRelevant,
    this.tier,
    this.verified = false,
    this.verificationUrl,
    this.confidence,
    this.isSimilaritySuggestion = false,
    this.author,
    this.dateOfPublication,
    this.abstractText,
    this.score,
    this.unverifiedSimilaritySuggestion,
  });

  factory PlanReferenceDto.fromJson(Map<String, dynamic> json) {
    return PlanReferenceDto(
      title: json['title'] as String? ?? '',
      url: json['url'] as String?,
      doi: json['doi'] as String?,
      whyRelevant: json['why_relevant'] as String?,
      tier: json['tier'] as String?,
      verified: json['verified'] as bool? ?? false,
      verificationUrl: json['verification_url'] as String?,
      confidence: json['confidence'] as String?,
      isSimilaritySuggestion:
          json['is_similarity_suggestion'] as bool? ?? false,
      author: json['author'] as String?,
      dateOfPublication: json['date_of_publication'] as String?,
      abstractText: json['abstract'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      unverifiedSimilaritySuggestion:
          json['unverified_similarity_suggestion'] as bool?,
    );
  }

  final String title;
  final String? url;
  final String? doi;
  final String? whyRelevant;
  final String? tier;
  final bool verified;
  final String? verificationUrl;
  final String? confidence;
  final bool isSimilaritySuggestion;
  final String? author;
  final String? dateOfPublication;
  final String? abstractText;
  final double? score;
  final bool? unverifiedSimilaritySuggestion;
}
