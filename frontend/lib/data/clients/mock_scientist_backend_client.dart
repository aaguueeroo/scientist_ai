import 'dart:async';

import 'mock_payloads.dart';
import 'mock_review_payloads.dart';
import 'scientist_backend_client.dart';

const List<String> kMockPastConversationSeeds = <String>[
  'mRNA vaccine stability under freeze-thaw cycles',
  'CRISPR Cas9 delivery optimization in liver cells',
  'Protein folding assay with fluorescence readout',
  'Cell culture contamination prevention protocol',
];

const Duration _kStreamStepInterval = Duration(milliseconds: 600);
const Duration _kErrorPreEmitDelay = Duration(milliseconds: 900);
const Duration _kReviewLatency = Duration(milliseconds: 200);

class MockScientistBackendClient implements ScientistBackendClient {
  MockScientistBackendClient({bool seedReviews = false})
      : _reviews = seedReviews
            ? List<Map<String, dynamic>>.from(kMockSeedReviews)
            : <Map<String, dynamic>>[];

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
          'literature_review_id': 'mock_lit_empty_${query.hashCode}',
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
          if (isFinal) 'literature_review_id': 'mock_lit_${query.hashCode}',
        },
      };
    }
  }

  @override
  Future<Map<String, dynamic>> postExperimentPlan(
    Map<String, dynamic> requestBody,
  ) async {
    final String query = (requestBody['query'] as String? ?? '').trim();
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
  Future<Map<String, dynamic>> postFeedback(
    Map<String, dynamic> requestBody,
  ) async {
    await Future<void>.delayed(_kReviewLatency);
    final String feedbackId =
        'fb-mock-${DateTime.now().microsecondsSinceEpoch}';
    final Map<String, dynamic> echo = Map<String, dynamic>.from(requestBody);
    echo['id'] = feedbackId;
    _reviews.insert(0, Map<String, dynamic>.from(echo));
    return <String, dynamic>{
      'feedback_id': feedbackId,
      'request_id': 'req_mock',
      'accepted': true,
      'domain_tag': null,
      'review': echo,
    };
  }

  @override
  Future<Map<String, dynamic>> fetchReviews() async {
    await Future<void>.delayed(_kReviewLatency);
    return <String, dynamic>{
      'reviews': List<Map<String, dynamic>>.from(_reviews),
    };
  }

  @override
  Future<Map<String, dynamic>> fetchConversations() async {
    await Future<void>.delayed(_kReviewLatency);
    return <String, dynamic>{
      'conversations': <Map<String, dynamic>>[
        for (int i = 0; i < kMockPastConversationSeeds.length; i++)
          <String, dynamic>{
            'query': kMockPastConversationSeeds[i],
            'plan_id': 'mock_past_conv_$i',
            'literature_review_id': 'mock_lr_$i',
          },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getPlanById(String planId) async {
    await Future<void>.delayed(_kReviewLatency);
    if (planId.isEmpty) {
      throw const ScientistTransportException(
        code: 'validation_error',
        message: 'plan id is empty',
        statusCode: 400,
      );
    }
    return Map<String, dynamic>.from(kMockExperimentPlanJson);
  }

  bool _isUnknownQuery(String query) {
    return query.toLowerCase().contains('unknown');
  }

  bool _isErrorQuery(String query) {
    return query.toLowerCase().contains('error');
  }
}
