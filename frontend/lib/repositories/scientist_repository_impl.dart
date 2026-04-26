import 'package:flutter/foundation.dart';

import '../data/clients/scientist_backend_client.dart';
import '../data/dto/experiment_plan_dto.dart';
import '../data/dto/experiment_plan_request_dto.dart';
import '../data/dto/generate_plan_response_dto.dart';
import '../data/dto/literature_review_event_dto.dart';
import '../data/dto/literature_review_request_dto.dart';
import '../data/dto/review_dto.dart';
import '../data/mappers/backend_plan_mapper.dart';
import '../data/mappers/experiment_plan_mapper.dart';
import '../data/mappers/literature_review_mapper.dart';
import '../data/mappers/review_mapper.dart';
import '../features/review/models/review.dart';
import '../models/experiment_plan.dart';
import '../models/generate_plan_result.dart';
import '../models/literature_qc.dart';
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
  Future<GeneratePlanResult> fetchGeneratePlan(
    String query,
    String literatureReviewId,
  ) async {
    final ExperimentPlanRequestDto request = ExperimentPlanRequestDto(
      query: query,
      literatureReviewId: literatureReviewId,
    );
    Map<String, dynamic> rawResponse;
    try {
      rawResponse = await _client.postExperimentPlan(request.toJson());
    } catch (err, stackTrace) {
      debugPrint('Experiment plan transport error: $err\n$stackTrace');
      throw _translateTransportError(err);
    }
    try {
      if (rawResponse.containsKey('plan') || rawResponse.containsKey('qc')) {
        final GeneratePlanResponseDto dto =
            GeneratePlanResponseDto.fromJson(rawResponse);
        return BackendPlanMapper.toGeneratePlanResult(dto);
      }
      final ExperimentPlanDto legacy = ExperimentPlanDto.fromJson(rawResponse);
      final ExperimentPlan plan = ExperimentPlanMapper.toDomain(legacy);
      return GeneratePlanResult(
        requestId: '',
        qc: const LiteratureQcResult(
          novelty: '',
          confidence: '',
          references: <QcReference>[],
        ),
        plan: plan,
      );
    } catch (err, stackTrace) {
      debugPrint('Experiment plan parse error: $err\n$stackTrace');
      throw ScientistApiException(
        code: 'parse_error',
        message: 'Received an unexpected experiment plan payload.',
        cause: err,
      );
    }
  }

  @override
  Future<Review> submitReview(Review review) async {
    final ReviewDto requestDto = ReviewMapper.fromDomain(review);
    Map<String, dynamic> rawResponse;
    try {
      rawResponse = await _client.postReview(requestDto.toJson());
    } catch (err, stackTrace) {
      debugPrint('Submit review transport error: $err\n$stackTrace');
      throw _translateTransportError(err);
    }
    try {
      final ReviewDto responseDto = ReviewDto.fromJson(rawResponse);
      return ReviewMapper.toDomain(responseDto);
    } catch (err, stackTrace) {
      debugPrint('Submit review parse error: $err\n$stackTrace');
      throw ScientistApiException(
        code: 'parse_error',
        message: 'Received an unexpected review payload.',
        cause: err,
      );
    }
  }

  @override
  Future<List<Review>> fetchReviews() async {
    Map<String, dynamic> rawResponse;
    try {
      rawResponse = await _client.fetchReviews();
    } catch (err, stackTrace) {
      debugPrint('Fetch reviews transport error: $err\n$stackTrace');
      throw _translateTransportError(err);
    }
    try {
      final List<dynamic> rawReviews =
          (rawResponse['reviews'] as List<dynamic>? ?? <dynamic>[]);
      return rawReviews
          .map(
            (dynamic raw) =>
                ReviewMapper.toDomain(
                  ReviewDto.fromJson(raw as Map<String, dynamic>),
                ),
          )
          .toList(growable: false);
    } catch (err, stackTrace) {
      debugPrint('Fetch reviews parse error: $err\n$stackTrace');
      throw ScientistApiException(
        code: 'parse_error',
        message: 'Received an unexpected reviews payload.',
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
        requestId: err.requestId,
      );
    }
    return ScientistApiException(
      code: 'transport_error',
      message: 'Could not reach Marie. Please check your connection and try again.',
      cause: err,
    );
  }

  String _newRequestId() {
    return 'req_${DateTime.now().microsecondsSinceEpoch}';
  }
}
