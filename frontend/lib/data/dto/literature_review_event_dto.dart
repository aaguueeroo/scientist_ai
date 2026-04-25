import 'source_dto.dart';

enum LiteratureReviewEventType {
  reviewUpdate,
  error,
  unknown,
}

class LiteratureReviewEventDto {
  const LiteratureReviewEventDto({
    required this.type,
    required this.isFinal,
    required this.doesSimilarWorkExist,
    required this.expectedTotalSources,
    required this.sources,
    this.errorCode,
    this.errorMessage,
  });

  // Parses a raw SSE envelope of the form
  // `{ "event": "review_update" | "error", "data": { ... } }`.
  factory LiteratureReviewEventDto.fromJson(Map<String, dynamic> envelope) {
    final String rawType = envelope['event'] as String? ?? '';
    final Map<String, dynamic> data =
        (envelope['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final LiteratureReviewEventType type = _parseType(rawType);
    if (type == LiteratureReviewEventType.error) {
      return LiteratureReviewEventDto(
        type: type,
        isFinal: true,
        doesSimilarWorkExist: false,
        expectedTotalSources: 0,
        sources: const <SourceDto>[],
        errorCode: data['code'] as String?,
        errorMessage: data['message'] as String?,
      );
    }
    final List<dynamic> rawSources =
        (data['sources'] as List<dynamic>? ?? <dynamic>[]);
    return LiteratureReviewEventDto(
      type: type,
      isFinal: data['is_final'] as bool? ?? false,
      doesSimilarWorkExist: data['does_similar_work_exist'] as bool? ?? false,
      expectedTotalSources:
          (data['expected_total_sources'] as num?)?.toInt() ?? 0,
      sources: rawSources
          .map((dynamic e) => SourceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final LiteratureReviewEventType type;
  final bool isFinal;
  final bool doesSimilarWorkExist;
  final int expectedTotalSources;
  final List<SourceDto> sources;
  final String? errorCode;
  final String? errorMessage;

  bool get isError => type == LiteratureReviewEventType.error;

  Map<String, dynamic> toJson() {
    if (isError) {
      return <String, dynamic>{
        'event': 'error',
        'data': <String, dynamic>{
          'code': errorCode,
          'message': errorMessage,
        },
      };
    }
    return <String, dynamic>{
      'event': 'review_update',
      'data': <String, dynamic>{
        'is_final': isFinal,
        'does_similar_work_exist': doesSimilarWorkExist,
        'expected_total_sources': expectedTotalSources,
        'sources': sources.map((SourceDto s) => s.toJson()).toList(),
      },
    };
  }

  static LiteratureReviewEventType _parseType(String raw) {
    switch (raw) {
      case 'review_update':
        return LiteratureReviewEventType.reviewUpdate;
      case 'error':
        return LiteratureReviewEventType.error;
      default:
        return LiteratureReviewEventType.unknown;
    }
  }
}
