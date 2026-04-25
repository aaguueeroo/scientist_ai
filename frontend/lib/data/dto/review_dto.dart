import 'experiment_plan_dto.dart';

class ReviewDto {
  const ReviewDto({
    required this.id,
    required this.createdAt,
    required this.conversationId,
    required this.query,
    required this.originalPlan,
    required this.kind,
    required this.payload,
  });

  factory ReviewDto.fromJson(Map<String, dynamic> json) {
    return ReviewDto(
      id: json['id'] as String,
      createdAt: json['created_at'] as String,
      conversationId: json['conversation_id'] as String,
      query: json['query'] as String,
      originalPlan: ExperimentPlanDto.fromJson(
        json['original_plan'] as Map<String, dynamic>,
      ),
      kind: json['kind'] as String,
      payload: Map<String, dynamic>.from(
        json['payload'] as Map<String, dynamic>,
      ),
    );
  }

  final String id;
  final String createdAt;
  final String conversationId;
  final String query;
  final ExperimentPlanDto originalPlan;

  /// One of `"correction"`, `"comment"`, `"feedback"`.
  final String kind;

  /// Kind-specific fields, see API contract section 4.8.
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'created_at': createdAt,
      'conversation_id': conversationId,
      'query': query,
      'original_plan': originalPlan.toJson(),
      'kind': kind,
      'payload': payload,
    };
  }
}
