import '../models/experiment_plan.dart';
import '../models/literature_review.dart';
import 'mock_data.dart';

abstract class ScientistApi {
  Future<LiteratureReview> fetchLiteratureReview(String query);
  Future<ExperimentPlan> fetchExperimentPlan(String query);
  Stream<LiteratureReview> streamLiteratureReview(String query);
}

class MockScientistApi implements ScientistApi {
  @override
  Future<LiteratureReview> fetchLiteratureReview(String query) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (_isErrorQuery(query)) {
      throw Exception('Unable to retrieve literature review.');
    }
    if (_isUnknownQuery(query)) {
      return const LiteratureReview(
        doesSimilarWorkExist: false,
        sources: <Source>[],
        totalSources: 0,
      );
    }
    return mockLiteratureReviewTemplate;
  }

  @override
  Future<ExperimentPlan> fetchExperimentPlan(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (_isErrorQuery(query)) {
      throw Exception('Unable to generate experiment plan.');
    }
    return mockExperimentPlan;
  }

  @override
  Stream<LiteratureReview> streamLiteratureReview(String query) async* {
    if (_isErrorQuery(query)) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      throw Exception('Progressive literature lookup failed.');
    }
    if (_isUnknownQuery(query)) {
      yield const LiteratureReview(
        doesSimilarWorkExist: false,
        sources: <Source>[],
        totalSources: 0,
      );
      return;
    }
    final List<Source> allSources = mockLiteratureReviewTemplate.sources;
    for (int index = 1; index <= allSources.length; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      yield LiteratureReview(
        doesSimilarWorkExist: true,
        sources: allSources.sublist(0, index),
        totalSources: mockLiteratureReviewTemplate.totalSources,
      );
    }
  }

  bool _isUnknownQuery(String query) {
    return query.toLowerCase().contains('unknown');
  }

  bool _isErrorQuery(String query) {
    return query.toLowerCase().contains('error');
  }
}
