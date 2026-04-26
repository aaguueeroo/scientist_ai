import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../shell/marie_shell_peek_sync.dart';
import '../shell/marie_workspace_peek_visibility.dart';
import '../../models/experiment_plan.dart';
import '../../models/literature_review.dart';
import '../literature/widgets/literature_loading.dart';
import '../literature/widgets/source_tile.dart';
import '../plan/experiment_plan_view.dart';
import '../plan/review/plan_review_scaffold.dart';
import '../plan/widgets/workspace_step_header.dart';
import 'widgets/blackboard_prompt_view.dart';

class PastConversationScreen extends StatefulWidget {
  const PastConversationScreen({super.key});

  @override
  State<PastConversationScreen> createState() => _PastConversationScreenState();
}

class _PastConversationScreenState extends State<PastConversationScreen> {
  int _stepIndex = 0;

  void _goToStep(int index) {
    if (index < 0 || index >= kWorkspaceStepLabels.length) {
      return;
    }
    setState(() => _stepIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScientistController>(
      builder: (
        BuildContext context,
        ScientistController controller,
        Widget? child,
      ) {
        return MarieShellPeekSync(
          visible: mariePeekShowPastConversation(controller, _stepIndex),
          child: Padding(
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
                  stepIndex: _stepIndex,
                  stepLabels: kWorkspaceStepLabels,
                  stepEnabled: workspaceStepEnabled(
                    currentQuery: controller.currentQuery,
                    isLoadingPlan: controller.isLoadingPlan,
                    experimentPlan: controller.experimentPlan,
                    planError: controller.planError,
                    planFetchQc: controller.planFetchQc,
                  ),
                  onSelect: _goToStep,
                ),
                const SizedBox(height: kSpace32),
                Expanded(
                  child: IndexedStack(
                    clipBehavior: Clip.none,
                    index: _stepIndex,
                    children: <Widget>[
                    BlackboardPromptView(query: controller.currentQuery),
                    _LiteraturePane(
                      review: controller.literatureReview,
                      query: controller.currentQuery,
                    ),
                    _ExperimentPlanStepPane(
                      plan: controller.experimentPlan,
                      isLoadingPlan: controller.isLoadingPlan,
                      query: controller.currentQuery,
                      conversationId: controller.currentConversationId,
                      usedPriorFeedback: controller.usedPriorFeedback,
                      planGroundingCaveat: controller.planGroundingCaveat,
                      literatureReview: controller.literatureReview,
                      isLoadingLiterature: controller.isLoadingLiterature,
                      onRequestExperimentPlan: controller.loadExperimentPlan,
                      onLivePlanChanged: controller.applyCorrectedPlan,
                    ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LiteraturePane extends StatelessWidget {
  const _LiteraturePane({required this.review, required this.query});

  final LiteratureReview? review;
  final String? query;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final LiteratureReview? currentReview = review;
    if (currentReview == null) {
      return Consumer<ScientistController>(
        builder: (
          BuildContext context,
          ScientistController controller,
          Widget? child,
        ) {
          if (controller.isLoadingLiterature) {
            return const LiteratureLoading();
          }
          final bool canRequest = (query ?? '').isNotEmpty;
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Marie hasn\'t reviewed the literature for this question yet.',
                    textAlign: TextAlign.center,
                    style: context.scientist.bodySecondary,
                  ),
                  if (controller.literatureError != null) ...<Widget>[
                    const SizedBox(height: kSpace16),
                    Text(
                      controller.literatureError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (controller.literatureErrorRequestId != null &&
                        controller
                            .literatureErrorRequestId!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: kSpace8),
                      SelectableText(
                        controller.literatureErrorRequestId!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ],
                  ],
                  const SizedBox(height: kSpace24),
                  FilledButton(
                    onPressed: canRequest
                        ? () {
                            controller.loadLiteratureReview();
                          }
                        : null,
                    child: const Text('Ask Marie to review the literature'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    final String headline = currentReview.doesSimilarWorkExist
        ? '${currentReview.totalSources} papers found'
        : 'Literature Review';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(headline, style: textTheme.headlineMedium),
        if ((query ?? '').isNotEmpty) ...<Widget>[
          const SizedBox(height: kSpace8),
          Text(
            query!,
            style: context.scientist.bodySecondary,
          ),
        ],
        const SizedBox(height: kSpace24),
        Expanded(
          child: currentReview.sources.isEmpty
              ? Center(
                  child: Text(
                    'No sources to display.',
                    style: context.scientist.bodySecondary,
                  ),
                )
              : ListView.builder(
                  itemCount: currentReview.sources.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == currentReview.sources.length - 1
                            ? 0
                            : kSpace12,
                      ),
                      child: SourceTile(
                        source: currentReview.sources[index],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ExperimentPlanStepPane extends StatelessWidget {
  const _ExperimentPlanStepPane({
    required this.plan,
    required this.isLoadingPlan,
    required this.query,
    required this.conversationId,
    required this.usedPriorFeedback,
    this.planGroundingCaveat,
    this.literatureReview,
    required this.isLoadingLiterature,
    required this.onRequestExperimentPlan,
    required this.onLivePlanChanged,
  });

  final ExperimentPlan? plan;
  final bool isLoadingPlan;
  final String? query;
  final String? conversationId;
  final bool usedPriorFeedback;
  final String? planGroundingCaveat;
  final LiteratureReview? literatureReview;
  final bool isLoadingLiterature;
  final VoidCallback onRequestExperimentPlan;
  final ValueChanged<ExperimentPlan> onLivePlanChanged;

  @override
  Widget build(BuildContext context) {
    final ExperimentPlan? currentPlan = plan;
    if (isLoadingPlan && currentPlan == null) {
      return const ExperimentPlanLoadingView();
    }
    if (currentPlan == null) {
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
      plan: currentPlan,
      query: query,
      conversationId: conversationId ?? query ?? '',
      onLivePlanChanged: onLivePlanChanged,
      usedPriorFeedback: usedPriorFeedback,
      groundingCaveat: planGroundingCaveat,
    );
  }
}
