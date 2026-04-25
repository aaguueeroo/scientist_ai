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

  // POST /reviews.
  //
  // Persists a single review event (correction, comment, or feedback).
  // Returns the decoded JSON body of a successful response.
  // On non-2xx, throws a `ScientistTransportException`.
  Future<Map<String, dynamic>> postReview(Map<String, dynamic> requestBody);

  // GET /reviews.
  //
  // Returns the decoded JSON body `{ "reviews": [...] }`.
  // On non-2xx, throws a `ScientistTransportException`.
  Future<Map<String, dynamic>> fetchReviews();
}

class ScientistTransportException implements Exception {
  const ScientistTransportException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    return 'ScientistTransportException(code: $code, statusCode: $statusCode, '
        'message: $message)';
  }
}
