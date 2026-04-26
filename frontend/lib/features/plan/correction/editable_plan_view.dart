import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';
import '../../../ui/app_section_header.dart';
import '../review/models/removed_draft_slot.dart';
import '../review/plan_review_controller.dart';
import 'correction_format.dart';
import 'widgets/edit_highlight.dart';
import 'widgets/editable_hero_metrics.dart';
import 'widgets/editable_material_tile.dart';
import 'widgets/editable_plan_timeline.dart';
import 'widgets/editable_step_tile.dart';
import 'widgets/step_insert_slot.dart';

class EditablePlanView extends StatelessWidget {
  const EditablePlanView({
    super.key,
    this.query,
  });

  final String? query;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final ExperimentPlan draft = controller.draft ?? controller.livePlan;
    final List<RemovedStepSlot> removedSteps = controller.draftRemovedStepSlots;
    final List<RemovedMaterialSlot> removedMaterials =
        controller.draftRemovedMaterialSlots;
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Text(
          'Marie\'s experiment plan',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (query != null && query!.isNotEmpty) ...<Widget>[
          const SizedBox(height: kSpace8),
          Text(
            query!,
            style: context.scientist.bodySecondary,
          ),
        ],
        const SizedBox(height: kSpace24),
        const EditableHeroMetrics(),
        const SizedBox(height: kSpace32),
        const EditablePlanTimeline(),
        const SizedBox(height: kSpace16),
        Text(
          draft.description,
          style: context.scientist.bodySecondary,
        ),
        const SizedBox(height: kSpace32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _EditableStepsColumn(
                steps: draft.timePlan.steps,
                removedSlots: removedSteps,
                onStepChanged: controller.updateStep,
                onStepRemoved: controller.removeStep,
                onAddStep: controller.appendStep,
                onInsertStepAfter: controller.insertStepAt,
              ),
            ),
            const SizedBox(width: kSpace32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const AppSectionHeader(title: 'Materials'),
                  EditablePlanMaterialsList(
                    materials: draft.budget.materials,
                    removedSlots: removedMaterials,
                    onMaterialChanged: controller.updateMaterial,
                    onMaterialRemoved: controller.removeMaterial,
                    onAddMaterial: controller.appendMaterial,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditableStepsColumn extends StatelessWidget {
  const _EditableStepsColumn({
    required this.steps,
    required this.removedSlots,
    required this.onStepChanged,
    required this.onStepRemoved,
    required this.onAddStep,
    required this.onInsertStepAfter,
  });

  final List<Step> steps;
  final List<RemovedStepSlot> removedSlots;
  final void Function(int index, Step step) onStepChanged;
  final ValueChanged<int> onStepRemoved;
  final VoidCallback onAddStep;
  final ValueChanged<int> onInsertStepAfter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppSectionHeader(title: 'Steps'),
        ..._buildTiles(),
        if (steps.isNotEmpty || removedSlots.isNotEmpty)
          const SizedBox(height: kSpace12),
        AddStepTile(onPressed: onAddStep),
      ],
    );
  }

  List<Widget> _buildTiles() {
    final Map<String?, List<Step>> tombstonesByAnchor = <String?, List<Step>>{};
    for (final RemovedStepSlot slot in removedSlots) {
      tombstonesByAnchor
          .putIfAbsent(slot.afterDraftStepId, () => <Step>[])
          .add(slot.step);
    }
    final List<Widget> widgets = <Widget>[];
    for (final Step removed in tombstonesByAnchor[null] ?? const <Step>[]) {
      widgets.add(_buildStepTombstone(removed));
      widgets.add(const SizedBox(height: kSpace8));
    }
    for (int i = 0; i < steps.length; i++) {
      if (i > 0) {
        widgets.add(
          StepInsertSlot(
            onInsert: () => onInsertStepAfter(i - 1),
          ),
        );
      }
      widgets.add(
        EditableStepTile(
          step: steps[i],
          onChanged: (Step next) => onStepChanged(i, next),
          onRemove: () => onStepRemoved(i),
        ),
      );
      final List<Step> following =
          tombstonesByAnchor[steps[i].id] ?? const <Step>[];
      for (final Step removed in following) {
        widgets.add(const SizedBox(height: kSpace8));
        widgets.add(_buildStepTombstone(removed));
      }
    }
    return widgets;
  }

  Widget _buildStepTombstone(Step removed) {
    final String title = removed.name.trim().isEmpty
        ? 'Untitled step'
        : removed.name.trim();
    final String detail = <String>[
      if (removed.description.trim().isNotEmpty) removed.description.trim(),
      if (removed.duration.inMinutes > 0)
        formatDurationLabel(removed.duration),
    ].join('  •  ');
    return RemovedDraftSlot(
      removedLabel: 'Step',
      title: title,
      detail: detail.isEmpty ? null : detail,
    );
  }
}
