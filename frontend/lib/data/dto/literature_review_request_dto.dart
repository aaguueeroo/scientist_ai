class LiteratureReviewRequestDto {
  const LiteratureReviewRequestDto({
    required this.query,
    required this.requestId,
  });

  final String query;
  final String requestId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'query': query,
      'request_id': requestId,
    };
  }
}
