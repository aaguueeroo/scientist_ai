import 'package:flutter/material.dart' hide Material, Step;

import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../models/experiment_plan.dart';
import '../../ui/app_section_header.dart';
import '../../ui/app_surface.dart';
import '../../ui/skeleton_bar.dart';
import 'widgets/material_tile.dart';
import 'widgets/plan_hero_metrics.dart';
import 'widgets/plan_timeline.dart';
import 'widgets/step_tile.dart';

String formatExperimentPlanTotalDuration(Duration value) {
  final int days = value.inDays;
  final int hours = value.inHours.remainder(24);
  if (hours == 0) {
    return '$days days';
  }
  return '$days d $hours h';
}

List<Widget> _buildStepTiles(List<Step> steps) {
  final List<Widget> widgets = <Widget>[];
  for (int i = 0; i < steps.length; i++) {
    if (i > 0) {
      widgets.add(const SizedBox(height: kSpace12));
    }
    widgets.add(StepTile(step: steps[i]));
  }
  return widgets;
}

/// Single source of truth for the experiment plan body: hero metrics, timeline,
/// and steps + materials in two columns.
class ExperimentPlanView extends StatelessWidget {
  const ExperimentPlanView({
    super.key,
    required this.plan,
    this.query,
  });

  final ExperimentPlan plan;
  final String? query;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Text(
          'Experiment plan',
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
        PlanHeroMetrics(
          totalTimeLabel: formatExperimentPlanTotalDuration(
            plan.timePlan.totalDuration,
          ),
          totalBudgetLabel: '\$${plan.budget.total.toStringAsFixed(2)}',
        ),
        const SizedBox(height: kSpace32),
        PlanTimeline(steps: plan.timePlan.steps),
        const SizedBox(height: kSpace16),
        Text(
          plan.description,
          style: context.scientist.bodySecondary,
        ),
        const SizedBox(height: kSpace32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const AppSectionHeader(title: 'Steps'),
                  ..._buildStepTiles(plan.timePlan.steps),
                ],
              ),
            ),
            const SizedBox(width: kSpace32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const AppSectionHeader(title: 'Materials'),
                  PlanMaterialsList(materials: plan.budget.materials),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ExperimentPlanLoadingView extends StatelessWidget {
  const ExperimentPlanLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        const SkeletonBar(height: 26, width: 240),
        const SizedBox(height: kSpace8),
        const SkeletonBar(height: 14, width: 360),
        const SizedBox(height: kSpace24),
        const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SkeletonBlock(
                children: <Widget>[
                  SkeletonBar(height: 40, width: 100),
                  SizedBox(height: kSpace4),
                  SkeletonBar(height: 12, width: 80),
                ],
              ),
              SizedBox(width: kSpace40),
              SkeletonBlock(
                children: <Widget>[
                  SkeletonBar(height: 40, width: 88),
                  SizedBox(height: kSpace4),
                  SkeletonBar(height: 12, width: 64),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: kSpace32),
        AppSurface(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace24,
            vertical: kSpace24,
          ),
          child: SkeletonBlock(
            children: const <Widget>[
              SkeletonBar(height: 12),
              SizedBox(height: kSpace12),
              SkeletonBar(height: 2),
              SizedBox(height: kSpace8),
              SkeletonBar(height: 10, width: 200),
            ],
          ),
        ),
        const SizedBox(height: kSpace16),
        const SkeletonBar(height: 12, width: 480),
        const SizedBox(height: kSpace8),
        const SkeletonBar(height: 12, width: 320),
        const SizedBox(height: kSpace32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SkeletonBar(height: 16, width: 72),
                  const SizedBox(height: kSpace12),
                  AppSurface(
                    padding: const EdgeInsets.all(kSpace16),
                    child: const SkeletonBlock(
                      children: <Widget>[
                        SkeletonBar(height: 12),
                        SizedBox(height: kSpace8),
                        SkeletonBar(height: 10, width: 220),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpace32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SkeletonBar(height: 16, width: 88),
                  const SizedBox(height: kSpace12),
                  AppSurface(
                    padding: EdgeInsets.zero,
                    child: SkeletonBlock(
                      children: const <Widget>[
                        SkeletonBar(height: 12),
                        SizedBox(height: kSpace8),
                        SkeletonBar(height: 12, width: 200),
                      ],
                    ),
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

class ExperimentPlanErrorView extends StatelessWidget {
  const ExperimentPlanErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(kSpace24),
          child: AppSurface(
            padding: const EdgeInsets.all(kSpace24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  color: context.appColorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(height: kSpace12),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: kSpace16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
