import 'package:flutter/material.dart' hide Material, Step;

import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../models/experiment_plan.dart';
import '../../ui/app_section_header.dart';
import '../../ui/app_surface.dart';
import '../../ui/marie_loading_lottie.dart';
import 'widgets/material_tile.dart';
import 'widgets/plan_hero_metrics.dart';
import 'widgets/plan_risks_section.dart';
import 'widgets/plan_timeline.dart';
import 'widgets/plan_validation_section.dart';
import 'widgets/step_tile.dart';

String planHeroHeadline(ExperimentPlan plan) {
  final String h = plan.hypothesis.trim();
  if (h.isNotEmpty) {
    return h;
  }
  return plan.description;
}

bool planHasSummaryBesideHero(ExperimentPlan plan) {
  final String hero = planHeroHeadline(plan);
  return plan.description.trim().isNotEmpty &&
      plan.description.trim() != hero.trim();
}

List<Step> timelineBarStepsForPlan(ExperimentPlan plan) {
  if (plan.timelinePhases.isEmpty) {
    return plan.timePlan.steps;
  }
  return <Step>[
    for (int i = 0; i < plan.timelinePhases.length; i++)
      Step(
        id: 'timeline_phase_$i',
        number: i + 1,
        duration: Duration(days: plan.timelinePhases[i].durationDays),
        name: plan.timelinePhases[i].phase,
        dependsOn: List<String>.from(plan.timelinePhases[i].dependsOn),
        description: plan.timelinePhases[i].dependsOn.isEmpty
            ? ''
            : 'Depends on: ${plan.timelinePhases[i].dependsOn.join(', ')}',
      ),
  ];
}

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
    final String hero = planHeroHeadline(plan);
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
        const SizedBox(height: kSpace16),
        Text(
          hero,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (planHasSummaryBesideHero(plan)) ...<Widget>[
          const SizedBox(height: kSpace8),
          Text(
            'Summary',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: kSpace4),
          Text(
            plan.description,
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
        PlanTimeline(steps: timelineBarStepsForPlan(plan)),
        const SizedBox(height: kSpace16),
        if (!planHasSummaryBesideHero(plan) &&
            plan.description.trim().isNotEmpty)
          Text(
            plan.description,
            style: context.scientist.bodySecondary,
          ),
        if (!planHasSummaryBesideHero(plan) &&
            plan.description.trim().isNotEmpty)
          const SizedBox(height: kSpace16),
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
        const SizedBox(height: kSpace32),
        if (plan.validation != null)
          PlanValidationSection(validation: plan.validation!),
        if (plan.validation != null) const SizedBox(height: kSpace32),
        PlanRisksSection(risks: plan.risks),
      ],
    );
  }
}

class ExperimentPlanLoadingView extends StatelessWidget {
  const ExperimentPlanLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: kSpace32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MarieLoadingLottie(),
            const SizedBox(height: kSpace24),
            Text(
              'Drafting your experiment plan…',
              style: context.scientist.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ExperimentPlanErrorView extends StatelessWidget {
  const ExperimentPlanErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.requestId,
  });

  final String message;
  final VoidCallback onRetry;
  final String? requestId;

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
                if (requestId != null && requestId!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: kSpace12),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Reference ID',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      children: <Widget>[
                        SelectableText(
                          requestId!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
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
