import '../features/review/models/review.dart';
import '../models/experiment_plan.dart';
import '../models/literature_review.dart';

abstract class ScientistRepository {
  // Streams literature review snapshots as the BE produces them.
  // Emits `ScientistApiException` on backend errors and on parse failures.
  Stream<LiteratureReview> streamLiteratureReview(String query);

  // Generates an experiment plan for the given query.
  // Throws `ScientistApiException` on backend errors and on parse failures.
  Future<ExperimentPlan> fetchExperimentPlan(String query);

  // Persists a single review event (correction, comment, or feedback).
  // Throws `ScientistApiException` on backend errors and on parse failures.
  Future<Review> submitReview(Review review);

  // Loads every persisted review for the current user, ordered most
  // recent first.
  // Throws `ScientistApiException` on backend errors and on parse failures.
  Future<List<Review>> fetchReviews();
}

class ScientistApiException implements Exception {
  const ScientistApiException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() {
    return 'ScientistApiException(code: $code, message: $message, '
        'cause: $cause)';
  }
}
