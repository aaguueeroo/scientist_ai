import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../controllers/plan_review_session_snapshot.dart';
import '../../../controllers/review_store_controller.dart';
import '../../../controllers/scientist_controller.dart';
import '../../../core/app_constants.dart';
import '../../../models/experiment_plan.dart';
import '../../../models/literature_review.dart';
import '../../review/models/review.dart' as global_review;
import '../widgets/plan_sources_navigator.dart';
import 'editable_review_body.dart';
import 'plan_review_controller.dart';
import 'read_only_review_body.dart';
import 'review_history_drawer.dart';
import 'widgets/grounding_caveat_bar.dart';
import 'widgets/learned_from_feedback_bar.dart';
import 'widgets/review_action_bar.dart';
import 'widgets/send_plan_to_lab_bar.dart';

/// Top-level surface for the review feature. Owns the
/// [PlanReviewController] for the lifetime of the screen.
class PlanReviewScaffold extends StatefulWidget {
  const PlanReviewScaffold({
    super.key,
    required this.plan,
    required this.onLivePlanChanged,
    required this.conversationId,
    this.query,
    this.usedPriorFeedback = false,
    this.groundingCaveat,
  });

  final ExperimentPlan plan;
  final ValueChanged<ExperimentPlan> onLivePlanChanged;
  final String conversationId;
  final String? query;

  /// When true, a hint line is shown: prior corrections influenced this plan.
  final bool usedPriorFeedback;

  /// When set, a warning bar shows (no automated citation/catalog verification).
  final String? groundingCaveat;

  @override
  State<PlanReviewScaffold> createState() => _PlanReviewScaffoldState();
}

class _PlanReviewScaffoldState extends State<PlanReviewScaffold> {
  late ScientistController _scientist;
  late PlanReviewController _controller;
  bool _historyOpen = false;

  @override
  void initState() {
    super.initState();
    _scientist = context.read<ScientistController>();
    final PlanReviewSessionSnapshot? cached =
        _scientist.planReviewSessionFor(widget.conversationId);
    _controller = _buildController(cached: cached);
  }

  PlanReviewController _buildController({PlanReviewSessionSnapshot? cached}) {
    if (cached != null) {
      return PlanReviewController(
        source: cached.originalPlan,
        onLivePlanChanged: widget.onLivePlanChanged,
        conversationId: widget.conversationId,
        query: widget.query ?? '',
        onReviewsEmitted: _forwardReviewsToStore,
        initialComments: cached.comments,
        initialSectionFeedback: cached.sectionFeedback,
        initialAcceptedBatches: cached.acceptedBatches,
        initialVersions: cached.versions,
        initialViewingVersionId: cached.viewingVersionId,
      );
    }
    return PlanReviewController(
      source: widget.plan,
      onLivePlanChanged: widget.onLivePlanChanged,
      conversationId: widget.conversationId,
      query: widget.query ?? '',
      onReviewsEmitted: _forwardReviewsToStore,
    );
  }

  void _forwardReviewsToStore(List<global_review.Review> reviews) {
    final ReviewStoreController store =
        context.read<ReviewStoreController>();
    store.submitReviews(reviews);
  }

  @override
  void didUpdateWidget(covariant PlanReviewScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool conversationChanged =
        oldWidget.conversationId != widget.conversationId ||
        oldWidget.query != widget.query;
    if (conversationChanged) {
      if (oldWidget.conversationId.isNotEmpty) {
        _scientist.savePlanReviewSession(
          oldWidget.conversationId,
          PlanReviewSessionSnapshot.fromController(_controller),
        );
      }
      _controller.dispose();
      final PlanReviewSessionSnapshot? cached =
          _scientist.planReviewSessionFor(widget.conversationId);
      _controller = _buildController(cached: cached);
      return;
    }
    // The plan reference can also change because we just emitted an
    // updated live plan via _onLivePlanChanged → ScientistController
    // → Consumer rebuild. Those self-induced updates must NOT wipe
    // version history, so we ignore plan-identity changes here.
  }

  @override
  void dispose() {
    if (widget.conversationId.isNotEmpty) {
      _scientist.savePlanReviewSession(
        widget.conversationId,
        PlanReviewSessionSnapshot.fromController(_controller),
      );
    }
    _controller.dispose();
    super.dispose();
  }

  void _toggleHistory() {
    setState(() => _historyOpen = !_historyOpen);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlanReviewController>.value(
      value: _controller,
      child: _ReviewScaffoldShell(
        query: widget.query,
        usedPriorFeedback: widget.usedPriorFeedback,
        groundingCaveat: widget.groundingCaveat,
        onToggleHistory: _toggleHistory,
        historyOpen: _historyOpen,
        onCloseHistory: () => setState(() => _historyOpen = false),
      ),
    );
  }
}

class _ReviewScaffoldShell extends StatelessWidget {
  const _ReviewScaffoldShell({
    required this.query,
    this.usedPriorFeedback = false,
    this.groundingCaveat,
    required this.onToggleHistory,
    required this.historyOpen,
    required this.onCloseHistory,
  });

  final String? query;
  final bool usedPriorFeedback;
  final String? groundingCaveat;
  final VoidCallback onToggleHistory;
  final bool historyOpen;
  final VoidCallback onCloseHistory;

  Widget _bodyForMode(PlanReviewController controller) {
    if (controller.mode == ReviewMode.editing) {
      return EditableReviewBody(query: query);
    }
    return ReadOnlyReviewBody(
      plan: controller.displayPlan,
      query: query,
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final LiteratureReview? literatureReview =
        context.watch<ScientistController>().literatureReview;
    return PlanSourcesNavigatorScope(
      literatureReview: literatureReview,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 56),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kRadius),
                child: Column(
                  children: <Widget>[
                    if (groundingCaveat != null && groundingCaveat!.isNotEmpty) ...<Widget>[
                      GroundingCaveatBar(message: groundingCaveat!),
                      const SizedBox(height: kSpace12),
                    ],
                    if (controller.isHistoricalView)
                      _HistoricalBanner(
                        onReturn: controller.returnToCurrentVersion,
                      ),
                    Expanded(child: _bodyForMode(controller)),
                    if (usedPriorFeedback) ...<Widget>[
                      const SizedBox(height: kSpace12),
                      const LearnedFromFeedbackBar(),
                    ],
                    SendPlanToLabBar(query: query),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: ReviewActionBar(onToggleHistory: onToggleHistory),
          ),
          if (historyOpen)
            Positioned.fill(
              child: ReviewHistoryDrawer(
                onClose: onCloseHistory,
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoricalBanner extends StatelessWidget {
  const _HistoricalBanner({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: kSpace16),
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.history_rounded, size: 16, color: scheme.primary),
          const SizedBox(width: kSpace8),
          Expanded(
            child: Text(
              'Viewing a historical version of this plan',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: kSpace12),
          FilledButton.tonalIcon(
            onPressed: onReturn,
            icon: const Icon(Icons.fast_forward_rounded, size: 16),
            label: const Text('Return to current'),
          ),
        ],
      ),
    );
  }
}
