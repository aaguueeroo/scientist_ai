class ExperimentPlanRequestDto {
  const ExperimentPlanRequestDto({
    required this.query,
    required this.literatureReviewId,
  });

  final String query;
  final String literatureReviewId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'query': query,
      'literature_review_id': literatureReviewId,
    };
  }
}
