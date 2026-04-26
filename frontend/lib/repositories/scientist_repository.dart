import '../data/dto/conversation_summary_dto.dart';
import '../features/review/models/review.dart';
import '../models/generate_plan_result.dart';
import '../models/literature_review.dart';

abstract class ScientistRepository {
  // Streams literature review snapshots as the BE produces them.
  // Emits `ScientistApiException` on backend errors and on parse failures.
  Stream<LiteratureReview> streamLiteratureReview(String query);

  /// Generates an experiment plan (full [GeneratePlanResponse] envelope).
  // Throws `ScientistApiException` on backend errors and on parse failures.
  Future<GeneratePlanResult> fetchGeneratePlan(
    String query,
    String literatureReviewId,
  );

  // Persists a single review event (correction, comment, or feedback).
  // Throws `ScientistApiException` on backend errors and on parse failures.
  Future<Review> submitReview(Review review);

  // Loads every persisted review for the current user, ordered most
  // recent first.
  // Throws `ScientistApiException` on backend errors and on parse failures.
  Future<List<Review>> fetchReviews();

  // GET /conversations — recent saved plan sessions (for sidebar + restore).
  Future<List<ConversationSummaryDto>> fetchConversationsList();

  // GET /plans/{plan_id} — full snapshot; does not re-run the pipeline.
  Future<GeneratePlanResult> fetchSavedPlanById(String planId);
}

class ScientistApiException implements Exception {
  const ScientistApiException({
    required this.code,
    required this.message,
    this.cause,
    this.requestId,
  });

  final String code;
  final String message;
  final Object? cause;
  final String? requestId;

  @override
  String toString() {
    return 'ScientistApiException(code: $code, message: $message, '
        'requestId: $requestId, cause: $cause)';
  }
}
