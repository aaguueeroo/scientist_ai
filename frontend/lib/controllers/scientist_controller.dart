import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/id_generator.dart';
import '../models/experiment_plan.dart';
import '../models/literature_qc.dart';
import '../models/literature_review.dart';
import '../repositories/scientist_repository.dart';
import 'plan_review_session_snapshot.dart';

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
  final Map<String, PlanReviewSessionSnapshot> _planReviewSessions =
      <String, PlanReviewSessionSnapshot>{};
  final Map<String, String> _conversationIdByPastQuery =
      <String, String>{};

  String? currentQuery;
  String? currentConversationId;
  LiteratureReview? literatureReview;
  String? literatureReviewId;
  bool isLoadingLiterature = false;
  String? literatureError;
  String? literatureErrorRequestId;
  ExperimentPlan? experimentPlan;
  LiteratureQcResult? planFetchQc;
  String? planId;
  String? lastPlanRequestId;
  bool isLoadingPlan = false;
  String? planError;
  String? planErrorRequestId;

  Future<void> submitQuestion(String query) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return;
    }
    currentQuery = normalizedQuery;
    currentConversationId = generateLocalId('conv');
    if (!pastConversations.contains(normalizedQuery)) {
      pastConversations.insert(0, normalizedQuery);
    }
    experimentPlan = null;
    planFetchQc = null;
    planId = null;
    lastPlanRequestId = null;
    planError = null;
    planErrorRequestId = null;
    literatureReviewId = null;
    isLoadingPlan = false;
    unawaited(loadLiteratureReview());
  }

  Future<void> loadLiteratureReview() async {
    final String? query = currentQuery;
    if (query == null || query.isEmpty) {
      return;
    }
    await _literatureSubscription?.cancel();
    isLoadingLiterature = true;
    literatureError = null;
    literatureErrorRequestId = null;
    literatureReview = null;
    literatureReviewId = null;
    notifyListeners();
    final Completer<void> streamDone = Completer<void>();
    _literatureSubscription = _repository.streamLiteratureReview(query).listen(
      (LiteratureReview nextReview) {
        literatureReview = nextReview;
        isLoadingLiterature = false;
        if (nextReview.isFinal) {
          literatureReviewId = nextReview.literatureReviewId;
        }
        notifyListeners();
        if (nextReview.isFinal && !streamDone.isCompleted) {
          streamDone.complete();
        }
      },
      onError: (Object err) {
        debugPrint('Literature stream error: $err');
        literatureError = 'Marie couldn\'t load the literature review. Please retry.';
        literatureErrorRequestId = err is ScientistApiException
            ? err.requestId
            : null;
        isLoadingLiterature = false;
        notifyListeners();
        if (!streamDone.isCompleted) {
          streamDone.completeError(err);
        }
      },
      onDone: () {
        if (!streamDone.isCompleted) {
          streamDone.complete();
        }
      },
    );
    try {
      await streamDone.future;
    } catch (_) {
      // Error state already surfaced in onError.
    }
  }

  Future<void> openPastConversationReplay(String title) async {
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      return;
    }
    await _literatureSubscription?.cancel();
    _literatureSubscription = null;
    currentQuery = normalizedTitle;
    currentConversationId = _conversationIdByPastQuery.putIfAbsent(
      normalizedTitle,
      () => generateLocalId('conv'),
    );
    if (!pastConversations.contains(normalizedTitle)) {
      pastConversations.insert(0, normalizedTitle);
    }
    literatureReview = null;
    literatureError = null;
    literatureReviewId = null;
    experimentPlan = null;
    planFetchQc = null;
    planId = null;
    lastPlanRequestId = null;
    planError = null;
    planErrorRequestId = null;
    notifyListeners();
    await loadLiteratureReview();
    await loadExperimentPlan();
  }

  Future<void> loadExperimentPlan() async {
    final String? query = currentQuery;
    final String? litId = literatureReviewId;
    if (query == null || query.isEmpty || litId == null || litId.isEmpty) {
      return;
    }
    isLoadingPlan = true;
    planError = null;
    planErrorRequestId = null;
    notifyListeners();
    try {
      final result = await _repository.fetchGeneratePlan(query, litId);
      experimentPlan = result.plan;
      planFetchQc = result.qc;
      planId = result.planId;
      lastPlanRequestId = result.requestId.isNotEmpty ? result.requestId : null;
    } catch (err) {
      debugPrint('Experiment plan error: $err');
      planError = 'Marie couldn\'t generate the experiment plan. Please retry.';
      planErrorRequestId =
          err is ScientistApiException ? err.requestId : null;
      experimentPlan = null;
      planFetchQc = null;
      planId = null;
      lastPlanRequestId = null;
    } finally {
      isLoadingPlan = false;
      notifyListeners();
    }
  }

  void applyCorrectedPlan(ExperimentPlan plan) {
    experimentPlan = plan;
    notifyListeners();
  }

  /// Cached plan-review UI state (version history, comments, feedback) for
  /// the lifetime of the app. Keyed by [currentConversationId].
  PlanReviewSessionSnapshot? planReviewSessionFor(String conversationId) {
    if (conversationId.isEmpty) {
      return null;
    }
    return _planReviewSessions[conversationId];
  }

  void savePlanReviewSession(
    String conversationId,
    PlanReviewSessionSnapshot snapshot,
  ) {
    if (conversationId.isEmpty) {
      return;
    }
    _planReviewSessions[conversationId] = snapshot;
  }

  void reset() {
    currentQuery = null;
    currentConversationId = null;
    literatureReview = null;
    literatureReviewId = null;
    isLoadingLiterature = false;
    literatureError = null;
    literatureErrorRequestId = null;
    experimentPlan = null;
    planFetchQc = null;
    planId = null;
    lastPlanRequestId = null;
    isLoadingPlan = false;
    planError = null;
    planErrorRequestId = null;
    _literatureSubscription?.cancel();
    _literatureSubscription = null;
    _planReviewSessions.clear();
    _conversationIdByPastQuery.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _literatureSubscription?.cancel();
    super.dispose();
  }
}
