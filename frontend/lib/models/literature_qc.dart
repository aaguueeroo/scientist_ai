/// Quality-control result from experiment-plan (or analogous literature QC).
class LiteratureQcResult {
  const LiteratureQcResult({
    required this.novelty,
    required this.confidence,
    required this.references,
    this.similaritySuggestion,
    this.tier0Drops = 0,
  });

  final String novelty;
  final String confidence;
  final List<QcReference> references;
  final QcReference? similaritySuggestion;
  final int tier0Drops;
}

class QcReference {
  const QcReference({
    required this.title,
    this.url,
    this.doi,
    this.whyRelevant,
    this.tier,
    this.verified = false,
    this.verificationUrl,
    this.confidence,
    this.isSimilaritySuggestion = false,
    this.tavilyScore,
  });

  final String title;
  final String? url;
  final String? doi;
  final String? whyRelevant;
  final String? tier;
  final bool verified;
  final String? verificationUrl;
  final String? confidence;
  final bool isSimilaritySuggestion;
  /// Tavily relevance in ``[0,1]`` when present on the server reference.
  final double? tavilyScore;
}

class GroundingSummary {
  const GroundingSummary({
    required this.verifiedCount,
    required this.unverifiedCount,
    this.tier0Drops = 0,
    this.groundingCaveat,
  });

  final int verifiedCount;
  final int unverifiedCount;
  final int tier0Drops;
  /// Set when the server could not auto-verify any citation or catalog link.
  final String? groundingCaveat;
}
