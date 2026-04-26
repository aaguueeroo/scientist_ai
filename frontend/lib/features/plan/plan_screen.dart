import 'package:flutter/material.dart' hide Material, Step;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../models/experiment_plan.dart';
import 'experiment_plan_view.dart';
import 'project/project_plan_screen.dart';
import 'review/plan_review_scaffold.dart';
import 'widgets/workspace_step_header.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? projectId =
        GoRouterState.of(context).uri.queryParameters['projectId'];
    if (projectId != null && projectId.isNotEmpty) {
      return ProjectPlanScreen(projectId: projectId);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpace40,
        kSpace32,
        kSpace40,
        kSpace40,
      ),
      child: Consumer<ScientistController>(
        builder: (
          BuildContext context,
          ScientistController controller,
          Widget? child,
        ) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              WorkspaceStepHeader(
                stepIndex: 2,
                stepLabels: kWorkspaceStepLabels,
                stepEnabled: workspaceStepEnabled(
                  currentQuery: controller.currentQuery,
                  isLoadingPlan: controller.isLoadingPlan,
                  experimentPlan: controller.experimentPlan,
                  planError: controller.planError,
                ),
                onSelect: (int i) => navigateToWorkspaceStep(context, i),
              ),
              const SizedBox(height: kSpace32),
              Expanded(
                child: _PlanBody(
                  isLoadingPlan: controller.isLoadingPlan,
                  planError: controller.planError,
                  plan: controller.experimentPlan,
                  currentQuery: controller.currentQuery,
                  onRetry: controller.loadExperimentPlan,
                  onLivePlanChanged: controller.applyCorrectedPlan,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({
    required this.isLoadingPlan,
    required this.planError,
    required this.plan,
    required this.currentQuery,
    required this.onRetry,
    required this.onLivePlanChanged,
  });

  final bool isLoadingPlan;
  final String? planError;
  final ExperimentPlan? plan;
  final String? currentQuery;
  final VoidCallback onRetry;
  final void Function(ExperimentPlan) onLivePlanChanged;

  @override
  Widget build(BuildContext context) {
    if (isLoadingPlan && plan == null) {
      return const ExperimentPlanLoadingView();
    }
    if (planError != null) {
      return ExperimentPlanErrorView(
        message: planError!,
        onRetry: onRetry,
      );
    }
    if (plan == null) {
      return Center(
        child: Text(
          'Marie hasn\'t prepared an experiment plan yet.',
          style: context.scientist.bodySecondary,
        ),
      );
    }
    return PlanReviewScaffold(
      plan: plan!,
      query: currentQuery,
      conversationId: currentQuery ?? '',
      onLivePlanChanged: onLivePlanChanged,
    );
  }
}
