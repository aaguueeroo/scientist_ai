import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../controllers/review_store_controller.dart';
import '../../../core/app_constants.dart';
import '../../../models/experiment_plan.dart';
import '../../review/models/review.dart' as global_review;
import 'editable_review_body.dart';
import 'plan_review_controller.dart';
import 'read_only_review_body.dart';
import 'review_history_drawer.dart';
import 'widgets/review_action_bar.dart';

/// Top-level surface for the review feature. Owns the
/// [PlanReviewController] for the lifetime of the screen.
class PlanReviewScaffold extends StatefulWidget {
  const PlanReviewScaffold({
    super.key,
    required this.plan,
    required this.onLivePlanChanged,
    required this.conversationId,
    this.query,
  });

  final ExperimentPlan plan;
  final ValueChanged<ExperimentPlan> onLivePlanChanged;
  final String conversationId;
  final String? query;

  @override
  State<PlanReviewScaffold> createState() => _PlanReviewScaffoldState();
}

class _PlanReviewScaffoldState extends State<PlanReviewScaffold> {
  late PlanReviewController _controller;
  bool _historyOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
  }

  PlanReviewController _buildController() {
    return PlanReviewController(
      source: widget.plan,
      onLivePlanChanged: widget.onLivePlanChanged,
      conversationId: widget.conversationId,
      query: widget.query ?? '',
      onReviewsEmitted: _forwardReviewsToStore,
    );
  }

  void _forwardReviewsToStore(List<global_review.Review> reviews) {
    final ReviewStoreController? store =
        context.read<ReviewStoreController?>();
    if (store == null) return;
    store.submitReviews(reviews);
  }

  @override
  void didUpdateWidget(covariant PlanReviewScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.plan, widget.plan) ||
        oldWidget.conversationId != widget.conversationId ||
        oldWidget.query != widget.query) {
      // Plan or conversation context changes from outside (e.g. fresh
      // literature review). Recreate controller to keep state coherent.
      _controller.dispose();
      _controller = _buildController();
    }
  }

  @override
  void dispose() {
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
    required this.onToggleHistory,
    required this.historyOpen,
    required this.onCloseHistory,
  });

  final String? query;
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
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(top: 56),
            child: Column(
              children: <Widget>[
                if (controller.isHistoricalView)
                  _HistoricalBanner(
                    onReturn: controller.returnToCurrentVersion,
                  ),
                Expanded(child: _bodyForMode(controller)),
              ],
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
        color: scheme.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.4),
        ),
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
