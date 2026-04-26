// Transport-level contract that mirrors what the real BE will return.
//
// The boundary deals strictly in JSON-shaped maps so the future HTTP
// implementation only needs to decode response bodies and yield/return them.
abstract class ScientistBackendClient {
  // POST /literature-review (Server-Sent Events).
  //
  // Each emitted map is a full SSE envelope of the form
  // `{ "event": "review_update" | "error", "data": { ... } }`.
  // The stream completes after the final `review_update` (with `is_final: true`)
  // or yields an `error` envelope and terminates.
  Stream<Map<String, dynamic>> streamLiteratureReview(
    Map<String, dynamic> requestBody,
  );

  // POST /experiment-plan.
  //
  // Returns the decoded JSON body of a successful response.
  // On non-2xx, throws a `ScientistTransportException`.
  Future<Map<String, dynamic>> postExperimentPlan(
    Map<String, dynamic> requestBody,
  );

  // POST /feedback — legacy few-shot correction and/or plan-review (Review) envelope.
  //
  // Returns a JSON object: plan-review path includes a `review` echo; legacy
  // few-shot returns `feedback_id`, `domain_tag`, etc.
  Future<Map<String, dynamic>> postFeedback(Map<String, dynamic> requestBody);

  // GET /feedback — plan reviews list `{ "reviews": [...] }` (not legacy few-shots).
  Future<Map<String, dynamic>> fetchReviews();

  // GET /conversations — recent saved sessions (query + plan_id for sidebar).
  Future<Map<String, dynamic>> fetchConversations();

  // GET /plans/{plan_id} — snapshot from DB (same shape as POST /experiment-plan).
  Future<Map<String, dynamic>> getPlanById(String planId);
}

class ScientistTransportException implements Exception {
  const ScientistTransportException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;

  @override
  String toString() {
    return 'ScientistTransportException(code: $code, statusCode: $statusCode, '
        'requestId: $requestId, message: $message)';
  }
}
