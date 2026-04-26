import 'package:flutter/material.dart' hide Material, Step;

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/experiment_plan.dart';
import '../../../ui/app_section_header.dart';
import '../../../ui/plan_source_badges.dart';
import '../../review/widgets/focus_highlight_container.dart';
import '../experiment_plan_view.dart'
    show
        formatExperimentPlanTotalDuration,
        planHasSummaryBesideHero,
        planHeroHeadline,
        timelineBarStepsForPlan;
import '../widgets/plan_validation_section.dart';
import '../widgets/plan_references_panel.dart';
import '../widgets/plan_risks_section.dart';
import 'models/change_target.dart';
import 'models/review_section.dart';
import 'models/step_field.dart';
import 'widgets/review_hero_metrics.dart';
import 'widgets/review_materials_list.dart';
import 'widgets/review_plan_timeline.dart';
import 'widgets/review_step_tile.dart';
import 'widgets/section_feedback_bar.dart';
import 'widgets/selectable_plan_text.dart';

/// Read-only body of the review screen. Mirrors [ExperimentPlanView] but
/// every text field is suggestion-aware and selectable for comments, and
/// each major section gets its own feedback bar.
class ReadOnlyReviewBody extends StatelessWidget {
  const ReadOnlyReviewBody({
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
          SelectablePlanText(
            target: const PlanDescriptionTarget(),
            text: plan.description,
            style: context.scientist.bodySecondary,
          ),
        ],
        const SizedBox(height: kSpace24),
        ReviewHeroMetrics(
          totalTimeLabel: formatExperimentPlanTotalDuration(
            plan.timePlan.totalDuration,
          ),
          totalBudgetLabel: '\$${plan.budget.total.toStringAsFixed(2)}',
        ),
        const SizedBox(height: kSpace32),
        FocusHighlightContainer(
          section: ReviewSection.timeline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ReviewPlanTimeline(steps: timelineBarStepsForPlan(plan)),
              const SectionFeedbackBar(section: ReviewSection.timeline),
            ],
          ),
        ),
        const SizedBox(height: kSpace16),
        if (!planHasSummaryBesideHero(plan) && plan.description.trim().isNotEmpty)
          SelectablePlanText(
            target: const PlanDescriptionTarget(),
            text: plan.description,
            style: context.scientist.bodySecondary,
          ),
        if (!planHasSummaryBesideHero(plan) && plan.description.trim().isNotEmpty)
          const SizedBox(height: kSpace16),
        const SizedBox(height: kSpace32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: FocusHighlightContainer(
                section: ReviewSection.steps,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppSectionHeader(
                      title: 'Steps',
                      trailing: plan.stepsSectionSourceRefs.isNotEmpty
                          ? PlanSourceBadges(
                              refs: plan.stepsSectionSourceRefs,
                            )
                          : null,
                    ),
                    for (int i = 0;
                        i < plan.timePlan.steps.length;
                        i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: kSpace12),
                      FocusHighlightContainer(
                        target: StepFieldTarget(
                          stepId: plan.timePlan.steps[i].id,
                          field: StepField.name,
                        ),
                        child: ReviewStepTile(step: plan.timePlan.steps[i]),
                      ),
                    ],
                    const SectionFeedbackBar(section: ReviewSection.steps),
                  ],
                ),
              ),
            ),
            const SizedBox(width: kSpace32),
            Expanded(
              child: FocusHighlightContainer(
                section: ReviewSection.materials,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppSectionHeader(
                      title: 'Materials',
                      trailing: plan.materialsSectionSourceRefs.isNotEmpty
                          ? PlanSourceBadges(
                              refs: plan.materialsSectionSourceRefs,
                            )
                          : null,
                    ),
                    ReviewMaterialsList(materials: plan.budget.materials),
                    const SectionFeedbackBar(
                        section: ReviewSection.materials),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpace32),
        FocusHighlightContainer(
          section: ReviewSection.risks,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (plan.validation != null) ...<Widget>[
                PlanValidationSection(validation: plan.validation!),
                const SizedBox(height: kSpace24),
              ],
              PlanRisksSection(risks: plan.risks),
              const SectionFeedbackBar(section: ReviewSection.risks),
            ],
          ),
        ),
        PlanReferencesPanel(plan: plan),
        const SizedBox(height: kSpace32),
      ],
    );
  }
}
