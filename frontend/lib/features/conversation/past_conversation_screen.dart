import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../models/experiment_plan.dart';
import '../../models/literature_review.dart';
import '../../ui/app_surface.dart';
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

class _PromptPane extends StatelessWidget {
  const _PromptPane({required this.query});

  final String? query;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    if (query == null || query!.isEmpty) {
      return Center(
        child: Text(
          'No question recorded for this conversation.',
          style: context.scientist.bodySecondary,
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Prompt', style: textTheme.headlineMedium),
          const SizedBox(height: kSpace8),
          Text(
            'The research question you asked Marie.',
            style: context.scientist.bodySecondary,
          ),
          const SizedBox(height: kSpace24),
          AppSurface(
            padding: const EdgeInsets.all(kSpace24),
            child: Text(query!, style: textTheme.bodyLarge),
          ),
        ],
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
    required this.onLivePlanChanged,
  });

  final ExperimentPlan? plan;
  final String? query;
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
      conversationId: query ?? '',
      onLivePlanChanged: onLivePlanChanged,
    );
  }
}
