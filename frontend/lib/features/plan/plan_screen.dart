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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WorkspaceStepHeader(
            stepIndex: 2,
            stepLabels: kWorkspaceStepLabels,
            onSelect: (int i) => navigateToWorkspaceStep(context, i),
          ),
          const SizedBox(height: kSpace32),
          Expanded(
            child: Consumer<ScientistController>(
              builder: (
                BuildContext context,
                ScientistController controller,
                Widget? child,
              ) {
                final ExperimentPlan? plan = controller.experimentPlan;
                if (controller.isLoadingPlan && plan == null) {
                  return const ExperimentPlanLoadingView();
                }
                if (controller.planError != null) {
                  return ExperimentPlanErrorView(
                    message: controller.planError!,
                    onRetry: controller.loadExperimentPlan,
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
                  plan: plan,
                  query: controller.currentQuery,
                  conversationId: controller.currentQuery ?? '',
                  onLivePlanChanged: controller.applyCorrectedPlan,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
