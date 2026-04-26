import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../models/experiment_plan.dart';
import '../../models/literature_review.dart';
import '../literature/widgets/source_tile.dart';
import '../plan/review/plan_review_scaffold.dart';
import '../plan/widgets/workspace_step_header.dart';

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
                  index: _stepIndex,
                  children: <Widget>[
                    _PromptPane(query: controller.currentQuery),
                    _LiteraturePane(
                      review: controller.literatureReview,
                      query: controller.currentQuery,
                    ),
                    _ExperimentPlanStepPane(
                      plan: controller.experimentPlan,
                      query: controller.currentQuery,
                      conversationId: controller.currentConversationId,
                      usedPriorFeedback: controller.usedPriorFeedback,
                      onLivePlanChanged: controller.applyCorrectedPlan,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const String _kBlackboardAsset = 'lib/assets/marie-query-blackboard.png';

class _PromptPane extends StatelessWidget {
  const _PromptPane({required this.query});

  final String? query;

  @override
  Widget build(BuildContext context) {
    if (query == null || query!.isEmpty) {
      return Center(
        child: Text(
          'No question recorded for this conversation.',
          style: context.scientist.bodySecondary,
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 560),
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            Image.asset(
              _kBlackboardAsset,
              fit: BoxFit.contain,
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: 0,
              child: FractionallySizedBox(
                widthFactor: 0.52,
                heightFactor: 0.40,
                alignment: const Alignment(-0.72, -0.62),
                child: Padding(
                  padding: const EdgeInsets.all(kSpace16),
                  child: Center(
                    child: Text(
                      query!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xDDEEEEE8),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
      return Center(
        child: Text(
          'Marie hasn\'t reviewed the literature for this question yet.',
          style: context.scientist.bodySecondary,
        ),
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
                      child: SourceTile(source: currentReview.sources[index]),
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
    required this.query,
    required this.conversationId,
    required this.usedPriorFeedback,
    required this.onLivePlanChanged,
  });

  final ExperimentPlan? plan;
  final String? query;
  final String? conversationId;
  final bool usedPriorFeedback;
  final ValueChanged<ExperimentPlan> onLivePlanChanged;

  @override
  Widget build(BuildContext context) {
    final ExperimentPlan? currentPlan = plan;
    if (currentPlan == null) {
      return Center(
        child: Text(
          'Marie hasn\'t prepared an experiment plan yet.',
          style: context.scientist.bodySecondary,
        ),
      );
    }
    return PlanReviewScaffold(
      plan: currentPlan,
      query: query,
      conversationId: conversationId ?? query ?? '',
      onLivePlanChanged: onLivePlanChanged,
      usedPriorFeedback: usedPriorFeedback,
    );
  }
}
