import 'package:flutter/material.dart' hide Material, Step;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../models/experiment_plan.dart';
import '../../models/literature_qc.dart';
import '../../models/literature_review.dart';
import 'experiment_plan_view.dart';
import 'project/project_plan_screen.dart';
import 'review/plan_review_scaffold.dart';
import 'widgets/plan_qc_only_view.dart';
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
                  planFetchQc: controller.planFetchQc,
                ),
                onSelect: (int i) => navigateToWorkspaceStep(context, i),
              ),
              const SizedBox(height: kSpace32),
              Expanded(
                child: _PlanBody(
                  isLoadingPlan: controller.isLoadingPlan,
                  planError: controller.planError,
                  planErrorRequestId: controller.planErrorRequestId,
                  plan: controller.experimentPlan,
                  planFetchQc: controller.planFetchQc,
                  currentQuery: controller.currentQuery,
                  conversationId: controller.currentConversationId,
                  usedPriorFeedback: controller.usedPriorFeedback,
                  planGroundingCaveat: controller.planGroundingCaveat,
                  literatureReview: controller.literatureReview,
                  isLoadingLiterature: controller.isLoadingLiterature,
                  onRequestExperimentPlan: controller.loadExperimentPlan,
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
    this.planErrorRequestId,
    required this.plan,
    this.planFetchQc,
    required this.currentQuery,
    required this.conversationId,
    required this.usedPriorFeedback,
    this.planGroundingCaveat,
    this.literatureReview,
    required this.isLoadingLiterature,
    required this.onRequestExperimentPlan,
    required this.onRetry,
    required this.onLivePlanChanged,
  });

  final bool isLoadingPlan;
  final String? planError;
  final String? planErrorRequestId;
  final ExperimentPlan? plan;
  final LiteratureQcResult? planFetchQc;
  final String? currentQuery;
  final String? conversationId;
  final bool usedPriorFeedback;
  final String? planGroundingCaveat;
  final LiteratureReview? literatureReview;
  final bool isLoadingLiterature;
  final VoidCallback onRequestExperimentPlan;
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
        requestId: planErrorRequestId,
      );
    }
    if (plan == null && planFetchQc != null) {
      return PlanQcOnlyView(
        qc: planFetchQc!,
        onRetry: onRetry,
      );
    }
    if (plan == null) {
      final LiteratureReview? lit = literatureReview;
      final bool canRequestExperimentPlan = !isLoadingLiterature &&
          lit != null &&
          lit.sources.isNotEmpty &&
          lit.isFinal &&
          (lit.literatureReviewId ?? '').isNotEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Marie hasn\'t prepared an experiment plan yet.',
              style: context.scientist.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: kSpace24),
            FilledButton(
              onPressed: canRequestExperimentPlan ? onRequestExperimentPlan : null,
              child: const Text('Ask Marie to prepare it'),
            ),
          ],
        ),
      );
    }
    return PlanReviewScaffold(
      plan: plan!,
      query: currentQuery,
      conversationId: conversationId ?? currentQuery ?? '',
      onLivePlanChanged: onLivePlanChanged,
      usedPriorFeedback: usedPriorFeedback,
      groundingCaveat: planGroundingCaveat,
    );
  }
}
