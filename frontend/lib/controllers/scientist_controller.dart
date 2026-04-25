import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/experiment_plan.dart';
import '../models/literature_review.dart';
import '../services/mock_data.dart';
import '../services/scientist_api.dart';

class ScientistController extends ChangeNotifier {
  ScientistController({
    required ScientistApi api,
  }) : _api = api,
       pastConversations = List<String>.from(mockPastConversations);

  final ScientistApi _api;
  StreamSubscription<LiteratureReview>? _literatureSubscription;
  final List<String> pastConversations;

  String? currentQuery;
  LiteratureReview? literatureReview;
  bool isLoadingLiterature = false;
  String? literatureError;
  ExperimentPlan? experimentPlan;
  bool isLoadingPlan = false;
  String? planError;

  Future<void> submitQuestion(String query) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return;
    }
    currentQuery = normalizedQuery;
    if (!pastConversations.contains(normalizedQuery)) {
      pastConversations.insert(0, normalizedQuery);
    }
    experimentPlan = null;
    planError = null;
    await loadLiteratureReview();
  }

  Future<void> loadLiteratureReview() async {
    final String? query = currentQuery;
    if (query == null || query.isEmpty) {
      return;
    }
    await _literatureSubscription?.cancel();
    isLoadingLiterature = true;
    literatureError = null;
    literatureReview = null;
    notifyListeners();
    _literatureSubscription = _api.streamLiteratureReview(query).listen(
      (LiteratureReview nextReview) {
        literatureReview = nextReview;
        isLoadingLiterature = false;
        notifyListeners();
      },
      onError: (Object err) {
        debugPrint('Literature stream error: $err');
        literatureError = 'Unable to load literature review. Please retry.';
        isLoadingLiterature = false;
        notifyListeners();
      },
    );
  }

  void openPastConversationReplay(String title) {
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      return;
    }
    _literatureSubscription?.cancel();
    _literatureSubscription = null;
    currentQuery = normalizedTitle;
    if (!pastConversations.contains(normalizedTitle)) {
      pastConversations.insert(0, normalizedTitle);
    }
    literatureReview = mockLiteratureReviewTemplate;
    isLoadingLiterature = false;
    literatureError = null;
    experimentPlan = mockExperimentPlan;
    isLoadingPlan = false;
    planError = null;
    notifyListeners();
  }

  Future<void> loadExperimentPlan() async {
    final String? query = currentQuery;
    if (query == null || query.isEmpty) {
      return;
    }
    isLoadingPlan = true;
    planError = null;
    notifyListeners();
    try {
      experimentPlan = await _api.fetchExperimentPlan(query);
    } catch (err) {
      debugPrint('Experiment plan error: $err');
      planError = 'Unable to generate experiment plan. Please retry.';
    } finally {
      isLoadingPlan = false;
      notifyListeners();
    }
  }

  void reset() {
    currentQuery = null;
    literatureReview = null;
    isLoadingLiterature = false;
    literatureError = null;
    experimentPlan = null;
    isLoadingPlan = false;
    planError = null;
    _literatureSubscription?.cancel();
    _literatureSubscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _literatureSubscription?.cancel();
    super.dispose();
  }
}
