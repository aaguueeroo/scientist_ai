import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/experiment_plan.dart';
import '../models/literature_review.dart';
import '../repositories/scientist_repository.dart';

// Seed list shown in the sidebar before any past-conversations endpoint exists.
// Replace with `GET /conversations` once the BE provides one.
const List<String> _kSeedPastConversations = <String>[
  'mRNA vaccine stability under freeze-thaw cycles',
  'CRISPR Cas9 delivery optimization in liver cells',
  'Protein folding assay with fluorescence readout',
  'Cell culture contamination prevention protocol',
];

class ScientistController extends ChangeNotifier {
  ScientistController({
    required ScientistRepository repository,
  })  : _repository = repository,
        pastConversations = List<String>.from(_kSeedPastConversations);

  final ScientistRepository _repository;
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
    _literatureSubscription = _repository.streamLiteratureReview(query).listen(
      (LiteratureReview nextReview) {
        literatureReview = nextReview;
        isLoadingLiterature = false;
        notifyListeners();
      },
      onError: (Object err) {
        debugPrint('Literature stream error: $err');
        literatureError = 'Marie couldn\'t load the literature review. Please retry.';
        isLoadingLiterature = false;
        notifyListeners();
      },
    );
  }

  Future<void> openPastConversationReplay(String title) async {
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      return;
    }
    await _literatureSubscription?.cancel();
    _literatureSubscription = null;
    currentQuery = normalizedTitle;
    if (!pastConversations.contains(normalizedTitle)) {
      pastConversations.insert(0, normalizedTitle);
    }
    literatureReview = null;
    literatureError = null;
    experimentPlan = null;
    planError = null;
    notifyListeners();
    await loadLiteratureReview();
    await loadExperimentPlan();
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
      experimentPlan = await _repository.fetchExperimentPlan(query);
    } catch (err) {
      debugPrint('Experiment plan error: $err');
      planError = 'Marie couldn\'t generate the experiment plan. Please retry.';
    } finally {
      isLoadingPlan = false;
      notifyListeners();
    }
  }

  void applyCorrectedPlan(ExperimentPlan plan) {
    experimentPlan = plan;
    notifyListeners();
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
