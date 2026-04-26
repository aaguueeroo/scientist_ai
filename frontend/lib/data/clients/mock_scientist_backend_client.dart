import 'dart:async';

import 'mock_payloads.dart';
import 'mock_review_payloads.dart';
import 'scientist_backend_client.dart';

const Duration _kStreamStepInterval = Duration(milliseconds: 600);
const Duration _kErrorPreEmitDelay = Duration(milliseconds: 900);
const Duration _kPlanLatency = Duration(milliseconds: 2500);
const Duration _kReviewLatency = Duration(milliseconds: 200);

class MockScientistBackendClient implements ScientistBackendClient {
  MockScientistBackendClient()
      : _reviews = List<Map<String, dynamic>>.from(kMockSeedReviews);

  final List<Map<String, dynamic>> _reviews;

  @override
  Stream<Map<String, dynamic>> streamLiteratureReview(
    Map<String, dynamic> requestBody,
  ) async* {
    final String query = (requestBody['query'] as String? ?? '').trim();
    if (_isErrorQuery(query)) {
      await Future<void>.delayed(_kErrorPreEmitDelay);
      yield <String, dynamic>{
        'event': 'error',
        'data': <String, dynamic>{
          'code': 'internal_error',
          'message': 'Progressive literature lookup failed.',
        },
      };
      return;
    }
    if (_isUnknownQuery(query)) {
      await Future<void>.delayed(_kStreamStepInterval);
      yield <String, dynamic>{
        'event': 'review_update',
        'data': <String, dynamic>{
          'is_final': true,
          'does_similar_work_exist': false,
          'expected_total_sources': 0,
          'sources': <Map<String, dynamic>>[],
        },
      };
      return;
    }
    for (int index = 1; index <= kMockSources.length; index++) {
      await Future<void>.delayed(_kStreamStepInterval);
      final bool isFinal = index == kMockSources.length;
      yield <String, dynamic>{
        'event': 'review_update',
        'data': <String, dynamic>{
          'is_final': isFinal,
          'does_similar_work_exist': true,
          'expected_total_sources': kMockExpectedTotalSources,
          'sources': kMockSources.sublist(0, index),
        },
      };
    }
  }

  @override
  Future<Map<String, dynamic>> postExperimentPlan(
    Map<String, dynamic> requestBody,
  ) async {
    final String query = (requestBody['query'] as String? ?? '').trim();
    await Future<void>.delayed(_kPlanLatency);
    if (_isErrorQuery(query)) {
      throw const ScientistTransportException(
        code: 'internal_error',
        message: 'Unable to generate experiment plan.',
        statusCode: 500,
      );
    }
    return kMockExperimentPlanJson;
  }

  @override
  Future<Map<String, dynamic>> postReview(
    Map<String, dynamic> requestBody,
  ) async {
    await Future<void>.delayed(_kReviewLatency);
    final Map<String, dynamic> stored =
        Map<String, dynamic>.from(requestBody);
    _reviews.insert(0, stored);
    return stored;
  }

  @override
  Future<Map<String, dynamic>> fetchReviews() async {
    await Future<void>.delayed(_kReviewLatency);
    return <String, dynamic>{
      'reviews': List<Map<String, dynamic>>.from(_reviews),
    };
  }

  bool _isUnknownQuery(String query) {
    return query.toLowerCase().contains('unknown');
  }

  bool _isErrorQuery(String query) {
    return query.toLowerCase().contains('error');
  }
}
