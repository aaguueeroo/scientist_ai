import 'package:flutter/foundation.dart';

import '../data/clients/scientist_backend_client.dart';
import '../data/dto/experiment_plan_dto.dart';
import '../data/dto/experiment_plan_request_dto.dart';
import '../data/dto/literature_review_event_dto.dart';
import '../data/dto/literature_review_request_dto.dart';
import '../data/mappers/experiment_plan_mapper.dart';
import '../data/mappers/literature_review_mapper.dart';
import '../models/experiment_plan.dart';
import '../models/literature_review.dart';
import 'scientist_repository.dart';

class ScientistRepositoryImpl implements ScientistRepository {
  ScientistRepositoryImpl({required ScientistBackendClient client})
      : _client = client;

  final ScientistBackendClient _client;

  @override
  Stream<LiteratureReview> streamLiteratureReview(String query) async* {
    final LiteratureReviewRequestDto request = LiteratureReviewRequestDto(
      query: query,
      requestId: _newRequestId(),
    );
    final Stream<Map<String, dynamic>> rawStream = _client
        .streamLiteratureReview(request.toJson())
        .handleError((Object err, StackTrace stackTrace) {
      debugPrint('Literature transport error: $err\n$stackTrace');
      throw _translateTransportError(err);
    });
    await for (final Map<String, dynamic> envelope in rawStream) {
      LiteratureReviewEventDto event;
      try {
        event = LiteratureReviewEventDto.fromJson(envelope);
      } catch (err, stackTrace) {
        debugPrint('Literature parse error: $err\n$stackTrace');
        throw ScientistApiException(
          code: 'parse_error',
          message: 'Received an unexpected literature review payload.',
          cause: err,
        );
      }
      if (event.isError) {
        throw ScientistApiException(
          code: event.errorCode ?? 'internal_error',
          message: event.errorMessage ??
              'The literature review service reported an error.',
        );
      }
      yield LiteratureReviewMapper.toDomain(event);
    }
  }

  @override
  Future<ExperimentPlan> fetchExperimentPlan(String query) async {
    final ExperimentPlanRequestDto request = ExperimentPlanRequestDto(
      query: query,
    );
    Map<String, dynamic> rawResponse;
    try {
      rawResponse = await _client.postExperimentPlan(request.toJson());
    } catch (err, stackTrace) {
      debugPrint('Experiment plan transport error: $err\n$stackTrace');
      throw _translateTransportError(err);
    }
    try {
      final ExperimentPlanDto dto = ExperimentPlanDto.fromJson(rawResponse);
      return ExperimentPlanMapper.toDomain(dto);
    } catch (err, stackTrace) {
      debugPrint('Experiment plan parse error: $err\n$stackTrace');
      throw ScientistApiException(
        code: 'parse_error',
        message: 'Received an unexpected experiment plan payload.',
        cause: err,
      );
    }
  }

  ScientistApiException _translateTransportError(Object err) {
    if (err is ScientistApiException) {
      return err;
    }
    if (err is ScientistTransportException) {
      return ScientistApiException(
        code: err.code,
        message: err.message,
        cause: err,
      );
    }
    return ScientistApiException(
      code: 'transport_error',
      message: 'Could not reach the scientist service.',
      cause: err,
    );
  }

  String _newRequestId() {
    return 'req_${DateTime.now().microsecondsSinceEpoch}';
  }
}
