import 'scientist_backend_client.dart';

// Real-network implementation against the backend.
//
// This is a stub today. Once the BE exists, the body of each method should:
//
// 1. POST `requestBody` (json-encoded) to `<baseUrl>/literature-review` or
//    `<baseUrl>/experiment-plan`.
// 2. For `streamLiteratureReview`, parse the `text/event-stream` response and
//    yield one map per SSE event of the form
//    `{ "event": <eventName>, "data": <decodedJson> }`.
// 3. For `postExperimentPlan`, decode the JSON response body and return it.
// 4. Translate transport-level failures (timeouts, non-2xx, parse errors) into
//    `ScientistTransportException`.
class HttpScientistBackendClient implements ScientistBackendClient {
  const HttpScientistBackendClient({required this.baseUrl});

  final Uri baseUrl;

  @override
  Stream<Map<String, dynamic>> streamLiteratureReview(
    Map<String, dynamic> requestBody,
  ) {
    throw UnimplementedError(
      'HttpScientistBackendClient.streamLiteratureReview is not wired yet. '
      'Implement once the backend exposes POST /literature-review (SSE).',
    );
  }

  @override
  Future<Map<String, dynamic>> postExperimentPlan(
    Map<String, dynamic> requestBody,
  ) {
    throw UnimplementedError(
      'HttpScientistBackendClient.postExperimentPlan is not wired yet. '
      'Implement once the backend exposes POST /experiment-plan.',
    );
  }
}
