import 'plan_reference_dto.dart';

class LiteratureQcDto {
  const LiteratureQcDto({
    required this.novelty,
    required this.references,
    this.similaritySuggestion,
    this.confidence,
    this.tier0Drops = 0,
  });

  factory LiteratureQcDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawRefs =
        json['references'] as List<dynamic>? ?? <dynamic>[];
    return LiteratureQcDto(
      novelty: json['novelty'] as String? ?? '',
      references: rawRefs
          .map(
            (dynamic e) =>
                PlanReferenceDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      similaritySuggestion: json['similarity_suggestion'] == null
          ? null
          : PlanReferenceDto.fromJson(
              json['similarity_suggestion'] as Map<String, dynamic>,
            ),
      confidence: json['confidence'] as String?,
      tier0Drops: (json['tier_0_drops'] as num?)?.toInt() ?? 0,
    );
  }

  final String novelty;
  final List<PlanReferenceDto> references;
  final PlanReferenceDto? similaritySuggestion;
  final String? confidence;
  final int tier0Drops;
}
