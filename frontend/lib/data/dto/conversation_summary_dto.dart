class ConversationSummaryDto {
  const ConversationSummaryDto({
    required this.query,
    required this.planId,
    this.literatureReviewId = '',
  });

  factory ConversationSummaryDto.fromJson(Map<String, dynamic> json) {
    return ConversationSummaryDto(
      query: (json['query'] as String? ?? '').trim(),
      planId: (json['plan_id'] as String? ?? '').trim(),
      literatureReviewId: (json['literature_review_id'] as String? ?? '').trim(),
    );
  }

  final String query;
  final String planId;
  final String literatureReviewId;
}
