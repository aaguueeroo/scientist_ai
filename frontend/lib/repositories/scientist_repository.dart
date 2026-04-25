import '../models/experiment_plan.dart';
import '../models/literature_review.dart';

abstract class ScientistRepository {
  // Streams literature review snapshots as the BE produces them.
  // Emits `ScientistApiException` on backend errors and on parse failures.
  Stream<LiteratureReview> streamLiteratureReview(String query);

  // Generates an experiment plan for the given query.
  // Throws `ScientistApiException` on backend errors and on parse failures.
  Future<ExperimentPlan> fetchExperimentPlan(String query);
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
