import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_constants.dart';
import '../models/suggestion_batch.dart';
import '../plan_review_controller.dart';

/// Top-right action cluster. Three states:
/// - viewing: History + Edit plan.
/// - editing: Cancel + Apply suggestions.
/// - reviewingPending: batch color chip + Discard + Accept.
class ReviewActionBar extends StatelessWidget {
  const ReviewActionBar({
    super.key,
    required this.onToggleHistory,
  });

  final VoidCallback onToggleHistory;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    if (controller.isHistoricalView) {
      return _HistoricalReturnBar(
        onReturn: controller.returnToCurrentVersion,
      );
    }
    switch (controller.mode) {
      case ReviewMode.viewing:
        return _ViewingActions(
          onHistory: onToggleHistory,
          onEdit: controller.enterEditing,
        );
      case ReviewMode.editing:
        return _EditingActions(
          onCancel: controller.cancelEditing,
          onApply: controller.applySuggestions,
        );
      case ReviewMode.reviewingPending:
        return _PendingActions(
          batch: controller.pendingBatch!,
          onAccept: controller.acceptPendingBatch,
          onDiscard: controller.discardPendingBatch,
        );
    }
  }
}

class _ViewingActions extends StatelessWidget {
  const _ViewingActions({required this.onHistory, required this.onEdit});

  final VoidCallback onHistory;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: onHistory,
          icon: const Icon(Icons.history_rounded, size: 16),
          label: const Text('History'),
        ),
        const SizedBox(width: kSpace12),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit plan'),
        ),
      ],
    );
  }
}

class _EditingActions extends StatelessWidget {
  const _EditingActions({required this.onCancel, required this.onApply});

  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        const SizedBox(width: kSpace12),
        FilledButton.icon(
          onPressed: onApply,
          icon: const Icon(Icons.compare_arrows_rounded, size: 16),
          label: const Text('Apply suggestions'),
        ),
      ],
    );
  }
}

class _PendingActions extends StatelessWidget {
  const _PendingActions({
    required this.batch,
    required this.onAccept,
    required this.onDiscard,
  });

  final SuggestionBatch batch;
  final VoidCallback onAccept;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BatchColorChip(color: batch.color),
        const SizedBox(width: kSpace12),
        OutlinedButton.icon(
          onPressed: onDiscard,
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Discard batch'),
        ),
        const SizedBox(width: kSpace12),
        FilledButton.icon(
          onPressed: batch.isEmpty ? null : onAccept,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Accept batch'),
        ),
      ],
    );
  }
}

class _HistoricalReturnBar extends StatelessWidget {
  const _HistoricalReturnBar({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onReturn,
      icon: const Icon(Icons.fast_forward_rounded, size: 16),
      label: const Text('Return to current version'),
    );
  }
}

/// Small color dot used to attribute a batch (color of the suggestion).
class BatchColorChip extends StatelessWidget {
  const BatchColorChip({super.key, required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
