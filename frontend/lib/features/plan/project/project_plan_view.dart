import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';
import '../../../models/project.dart';
import '../../../models/user_role.dart';
import '../../../ui/app_section_header.dart';
import '../experiment_plan_view.dart' show formatExperimentPlanTotalDuration;
import '../widgets/plan_hero_metrics.dart';
import 'widgets/project_lab_info_card.dart';
import 'widgets/project_plan_timeline.dart';
import 'widgets/project_step_tile.dart';
import 'widgets/project_time_tracker.dart';

/// Body of the project plan screen. Layout is shared between roles; the
/// step tiles and the optional lab-info header are role-aware.
class ProjectPlanView extends StatelessWidget {
  const ProjectPlanView({
    super.key,
    required this.project,
    required this.role,
  });

  final Project project;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ExperimentPlan plan = project.plan;
    final List<Step> steps = plan.timePlan.steps;
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        Text(
          project.title,
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: kSpace8),
        Text(
          plan.description,
          style: context.scientist.bodySecondary,
        ),
        if (role == UserRole.funder) ...<Widget>[
          const SizedBox(height: kSpace24),
          ProjectLabInfoCard(project: project),
        ],
        const SizedBox(height: kSpace32),
        PlanHeroMetrics(
          totalTimeLabel: formatExperimentPlanTotalDuration(
            plan.timePlan.totalDuration,
          ),
          totalBudgetLabel: '\$${plan.budget.total.toStringAsFixed(2)}',
        ),
        const SizedBox(height: kSpace24),
        ProjectTimeTracker(project: project),
        const SizedBox(height: kSpace32),
        ProjectPlanTimeline(project: project),
        const SizedBox(height: kSpace32),
        const AppSectionHeader(title: 'Steps'),
        for (int i = 0; i < steps.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: kSpace12),
          ProjectStepTile(
            project: project,
            step: steps[i],
            role: role,
          ),
        ],
        const SizedBox(height: kSpace40),
      ],
    );
  }
}
