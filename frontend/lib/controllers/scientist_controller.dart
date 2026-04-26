import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/conversation_query_key.dart';
import '../core/id_generator.dart';
import '../data/dto/conversation_summary_dto.dart';
import '../data/mappers/literature_review_from_qc.dart';
import '../models/experiment_plan.dart';
import '../models/literature_qc.dart';
import '../models/literature_review.dart';
import '../models/generate_plan_result.dart';
import '../repositories/scientist_repository.dart';
import 'plan_review_session_snapshot.dart';

class ScientistController extends ChangeNotifier {
  ScientistController({
    required ScientistRepository repository,
  })  : _repository = repository,
        pastConversations = <String>[] {
    Future<void>.microtask(() => loadPastConversationsList());
  }

  final ScientistRepository _repository;
  StreamSubscription<LiteratureReview>? _literatureSubscription;
  final List<String> pastConversations;
  final Map<String, PlanReviewSessionSnapshot> _planReviewSessions =
      <String, PlanReviewSessionSnapshot>{};
  final Map<String, String> _conversationIdByPastQuery =
      <String, String>{};
  final Map<String, String> _planIdByQueryKey = <String, String>{};
  final Map<String, String> _litReviewIdByQueryKey = <String, String>{};
  bool _loadedPastConversations = false;

  /// Invalidates in-flight plan loads when the user switches conversation or
  /// starts a new plan request so stale [Future]s cannot apply the wrong plan.
  int _planWorkGeneration = 0;

  void _bumpPlanWorkGeneration() {
    _planWorkGeneration++;
  }

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

  /// Shown in the plan UI when the backend used prior few-shot corrections.
  bool usedPriorFeedback = false;

  /// Server text when no citation or catalog line auto-verified (still 200 + plan).
  String? planGroundingCaveat;

  Future<void> submitQuestion(String query) async {
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return;
    }
    _bumpPlanWorkGeneration();
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
    usedPriorFeedback = false;
    planGroundingCaveat = null;
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
          final String k = conversationQueryKey(query);
          final String? lid = nextReview.literatureReviewId;
          if (lid != null && lid.isNotEmpty) {
            _litReviewIdByQueryKey[k] = lid;
          }
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

  /// Fills the sidebar and id maps from `GET /conversations` (read-only; no search).
  Future<void> loadPastConversationsList({bool force = false}) async {
    if (_loadedPastConversations && !force) {
      return;
    }
    try {
      final List<ConversationSummaryDto> list =
          await _repository.fetchConversationsList();
      if (force) {
        _planIdByQueryKey.clear();
        _litReviewIdByQueryKey.clear();
      }
      for (final ConversationSummaryDto c in list) {
        final String k = conversationQueryKey(c.query);
        if (k.isEmpty) {
          continue;
        }
        _planIdByQueryKey[k] = c.planId;
        if (c.literatureReviewId.isNotEmpty) {
          _litReviewIdByQueryKey[k] = c.literatureReviewId;
        }
      }
      pastConversations
        ..clear()
        ..addAll(list.map((ConversationSummaryDto c) => c.query));
      _loadedPastConversations = true;
      notifyListeners();
    } catch (e) {
      _loadedPastConversations = false;
      debugPrint('loadPastConversationsList: $e');
    }
  }

  /// Restore a past session with `GET /plans/{id}` only — no literature POST / plan POST.
  Future<void> openPastConversationReplay(String title) async {
    final String normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      return;
    }
    await _literatureSubscription?.cancel();
    _literatureSubscription = null;
    _bumpPlanWorkGeneration();
    final int workId = _planWorkGeneration;
    currentQuery = normalizedTitle;
    currentConversationId = _conversationIdByPastQuery.putIfAbsent(
      normalizedTitle,
      () => generateLocalId('conv'),
    );
    if (!pastConversations.contains(normalizedTitle)) {
      pastConversations.insert(0, normalizedTitle);
    }
    isLoadingLiterature = false;
    literatureError = null;
    literatureErrorRequestId = null;
    planError = null;
    planErrorRequestId = null;
    isLoadingPlan = false;
    experimentPlan = null;
    planFetchQc = null;
    planId = null;
    lastPlanRequestId = null;
    usedPriorFeedback = false;
    planGroundingCaveat = null;
    notifyListeners();

    final String qk = conversationQueryKey(normalizedTitle);
    var planIdForLoad = _planIdByQueryKey[qk];
    if (planIdForLoad == null || planIdForLoad.isEmpty) {
      await loadPastConversationsList(force: true);
      if (workId != _planWorkGeneration) {
        return;
      }
      planIdForLoad = _planIdByQueryKey[qk];
    }
    if (planIdForLoad == null || planIdForLoad.isEmpty) {
      if (workId != _planWorkGeneration) {
        return;
      }
      literatureError =
          'No saved plan found for this question yet. Run a new search to create one.';
      experimentPlan = null;
      planFetchQc = null;
      planId = null;
      lastPlanRequestId = null;
      usedPriorFeedback = false;
      planGroundingCaveat = null;
      literatureReview = null;
      literatureReviewId = _litReviewIdByQueryKey[qk];
      notifyListeners();
      return;
    }

    isLoadingPlan = true;
    notifyListeners();
    try {
      final GeneratePlanResult r =
          await _repository.fetchSavedPlanById(planIdForLoad);
      if (workId != _planWorkGeneration) {
        return;
      }
      _applyRestoredPlan(r, queryKey: qk, resolvedPlanId: planIdForLoad);
    } catch (err) {
      if (workId != _planWorkGeneration) {
        return;
      }
      debugPrint('Restore saved plan error: $err');
      planError = 'Could not load the saved plan. Please retry.';
      planErrorRequestId = err is ScientistApiException ? err.requestId : null;
      experimentPlan = null;
      planFetchQc = null;
      planId = null;
      lastPlanRequestId = null;
      usedPriorFeedback = false;
      planGroundingCaveat = null;
      literatureReview = null;
      literatureReviewId = null;
    } finally {
      if (workId == _planWorkGeneration) {
        isLoadingPlan = false;
        notifyListeners();
      }
    }
  }

  void _applyRestoredPlan(
    GeneratePlanResult r, {
    required String queryKey,
    required String resolvedPlanId,
  }) {
    experimentPlan = r.plan;
    planFetchQc = r.qc;
    planId = (r.planId != null && r.planId!.isNotEmpty) ? r.planId : resolvedPlanId;
    lastPlanRequestId = r.requestId.isNotEmpty ? r.requestId : null;
    usedPriorFeedback = r.usedPriorFeedback;
    planGroundingCaveat = r.groundingSummary?.groundingCaveat;
    planError = null;
    literatureReviewId = _litReviewIdByQueryKey[queryKey];
    literatureReview = LiteratureReviewFromQc.fromQc(
      r.qc,
      literatureReviewId: literatureReviewId,
    );
    literatureError = null;
  }

  Future<void> loadExperimentPlan() async {
    final String? query = currentQuery;
    final String? litId = literatureReviewId;
    if (query == null || query.isEmpty || litId == null || litId.isEmpty) {
      return;
    }
    _bumpPlanWorkGeneration();
    final int workId = _planWorkGeneration;
    isLoadingPlan = true;
    planError = null;
    planErrorRequestId = null;
    notifyListeners();
    try {
      final GeneratePlanResult result =
          await _repository.fetchGeneratePlan(query, litId);
      if (workId != _planWorkGeneration) {
        return;
      }
      if (currentQuery != query || literatureReviewId != litId) {
        return;
      }
      experimentPlan = result.plan;
      planFetchQc = result.qc;
      planId = result.planId;
      lastPlanRequestId = result.requestId.isNotEmpty ? result.requestId : null;
      usedPriorFeedback = result.usedPriorFeedback;
      planGroundingCaveat = result.groundingSummary?.groundingCaveat;
      final String k = conversationQueryKey(query);
      final String? outPid = result.planId;
      if (outPid != null && outPid.isNotEmpty) {
        _planIdByQueryKey[k] = outPid;
      }
      if (litId.isNotEmpty) {
        _litReviewIdByQueryKey[k] = litId;
      }
    } catch (err) {
      if (workId != _planWorkGeneration) {
        return;
      }
      if (currentQuery != query || literatureReviewId != litId) {
        return;
      }
      debugPrint('Experiment plan error: $err');
      planError = 'Marie couldn\'t generate the experiment plan. Please retry.';
      planErrorRequestId =
          err is ScientistApiException ? err.requestId : null;
      experimentPlan = null;
      planFetchQc = null;
      planId = null;
      lastPlanRequestId = null;
      usedPriorFeedback = false;
      planGroundingCaveat = null;
    } finally {
      if (workId == _planWorkGeneration) {
        isLoadingPlan = false;
        notifyListeners();
      }
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

  /// Removes [query] from the recent list and deletes the persisted plan when
  /// one exists. Returns false when the API call fails (caller may toast).
  /// When the removed question is the active session, clears in-memory session
  /// state (caller should navigate away from past conversation if needed).
  Future<bool> deleteRecentQuestion(String query) async {
    final String normalized = query.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final String qk = conversationQueryKey(normalized);
    final String? existingPlanId = _planIdByQueryKey[qk];
    String? convIdToClear;
    for (final MapEntry<String, String> e in _conversationIdByPastQuery.entries) {
      if (conversationQueryKey(e.key) == qk) {
        convIdToClear = e.value;
        break;
      }
    }
    try {
      if (existingPlanId != null && existingPlanId.isNotEmpty) {
        await _repository.deleteSavedPlan(existingPlanId);
      }
    } catch (err, stackTrace) {
      debugPrint('deleteRecentQuestion: $err\n$stackTrace');
      return false;
    }
    pastConversations.removeWhere(
      (String q) => conversationQueryKey(q) == qk,
    );
    _planIdByQueryKey.remove(qk);
    _litReviewIdByQueryKey.remove(qk);
    _conversationIdByPastQuery.removeWhere(
      (String k, _) => conversationQueryKey(k) == qk,
    );
    if (convIdToClear != null) {
      _planReviewSessions.remove(convIdToClear);
    }
    final bool wasCurrent =
        currentQuery != null && conversationQueryKey(currentQuery!) == qk;
    if (wasCurrent) {
      _bumpPlanWorkGeneration();
      await _literatureSubscription?.cancel();
      _literatureSubscription = null;
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
      usedPriorFeedback = false;
    }
    notifyListeners();
    return true;
  }

  void reset() {
    _bumpPlanWorkGeneration();
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
    usedPriorFeedback = false;
    planGroundingCaveat = null;
    _literatureSubscription?.cancel();
    _literatureSubscription = null;
    _planReviewSessions.clear();
    _conversationIdByPastQuery.clear();
    _planIdByQueryKey.clear();
    _litReviewIdByQueryKey.clear();
    _loadedPastConversations = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _literatureSubscription?.cancel();
    super.dispose();
  }
}
