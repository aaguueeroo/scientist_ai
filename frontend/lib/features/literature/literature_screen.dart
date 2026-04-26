import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../core/app_routes.dart';
import '../../models/literature_review.dart';
import '../plan/widgets/workspace_step_header.dart';
import '../shell/marie_shell_peek_sync.dart';
import '../shell/marie_workspace_peek_visibility.dart';
import '../../ui/app_surface.dart';
import 'widgets/literature_empty.dart';
import 'widgets/literature_loading.dart';
import 'widgets/source_tile.dart';

class LiteratureScreen extends StatelessWidget {
  const LiteratureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScientistController>(
      builder: (
        BuildContext context,
        ScientistController controller,
        Widget? child,
      ) {
        final LiteratureReview? review = controller.literatureReview;
        final TextTheme textTheme = Theme.of(context).textTheme;
        final String headline = review != null && review.doesSimilarWorkExist
            ? '${review.totalSources} papers found'
            : 'Literature Review';
        return MarieShellPeekSync(
          visible: mariePeekShowLiteratureBody(controller),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpace40,
              kSpace32,
              kSpace40,
              kSpace24,
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              WorkspaceStepHeader(
                stepIndex: 1,
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
              Text(headline, style: textTheme.headlineMedium),
              if ((controller.currentQuery ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: kSpace8),
                Text(
                  controller.currentQuery!,
                  style: context.scientist.bodySecondary,
                ),
              ],
              const SizedBox(height: kSpace24),
              if (controller.literatureError != null) ...<Widget>[
                _LiteratureError(
                  message: controller.literatureError!,
                  requestId: controller.literatureErrorRequestId,
                  onRetry: controller.loadLiteratureReview,
                ),
                const SizedBox(height: kSpace16),
              ],
              Expanded(
                child: _LiteratureExpandedBody(
                  controller: controller,
                  review: review,
                ),
              ),
              if (!controller.isLoadingLiterature) ...<Widget>[
                const SizedBox(height: kSpace24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: (review == null ||
                            review.sources.isEmpty ||
                            !review.isFinal ||
                            (review.literatureReviewId ?? '').isEmpty)
                        ? null
                        : () {
                            controller.loadExperimentPlan();
                            context.go(kRoutePlan);
                          },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Ask Marie for an experiment plan'),
                  ),
                ),
              ],
            ],
            ),
          ),
        );
      },
    );
  }
}

class _LiteratureExpandedBody extends StatelessWidget {
  const _LiteratureExpandedBody({
    required this.controller,
    required this.review,
  });

  final ScientistController controller;
  final LiteratureReview? review;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingLiterature && review == null) {
      return const LiteratureLoading();
    }
    if (review == null) {
      return const SizedBox.shrink();
    }
    final LiteratureReview loadedReview = review!;
    if (loadedReview.sources.isEmpty) {
      return const LiteratureEmpty();
    }
    return ListView.builder(
      itemCount: loadedReview.sources.length,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == loadedReview.sources.length - 1 ? 0 : kSpace12,
          ),
          child: SourceTile(
            source: loadedReview.sources[index],
          ),
        );
      },
    );
  }
}

class _LiteratureError extends StatelessWidget {
  const _LiteratureError({
    required this.message,
    required this.onRetry,
    this.requestId,
  });

  final String message;
  final VoidCallback onRetry;
  final String? requestId;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 18,
                color: context.appColorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: kSpace12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
          if (requestId != null && requestId!.isNotEmpty) ...<Widget>[
            const SizedBox(height: kSpace8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
        ],
      ),
    );
  }
}
