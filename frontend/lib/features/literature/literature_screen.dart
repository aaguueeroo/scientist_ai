import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/theme/theme_context.dart';
import '../../core/app_routes.dart';
import '../../models/literature_review.dart';
import '../plan/widgets/workspace_step_header.dart';
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
        return Padding(
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
                  onRetry: controller.loadLiteratureReview,
                ),
                const SizedBox(height: kSpace16),
              ],
              Expanded(
                child: controller.isLoadingLiterature && review == null
                    ? const LiteratureLoading()
                    : review == null
                        ? const SizedBox.shrink()
                        : review.sources.isEmpty
                            ? const LiteratureEmpty()
                            : ListView.builder(
                                itemCount: review.sources.length,
                                itemBuilder:
                                    (BuildContext context, int index) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index ==
                                              review.sources.length - 1
                                          ? 0
                                          : kSpace12,
                                    ),
                                    child: SourceTile(
                                      source: review.sources[index],
                                    ),
                                  );
                                },
                              ),
              ),
              const SizedBox(height: kSpace24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: (review == null || review.sources.isEmpty)
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
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Row(
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
    );
  }
}
