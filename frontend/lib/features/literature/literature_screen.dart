import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/scientist_controller.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../models/literature_review.dart';
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
        return Padding(
          padding: const EdgeInsets.all(kSpaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Literature Review',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: kSpaceXs),
              Text(
                controller.currentQuery ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: kSpaceM),
              if (controller.literatureError != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(controller.literatureError!),
                    trailing: TextButton(
                      onPressed: controller.loadLiteratureReview,
                      child: const Text('Retry'),
                    ),
                  ),
                ),
              if (review != null && review.doesSimilarWorkExist)
                Padding(
                  padding: const EdgeInsets.only(bottom: kSpaceM),
                  child: Text(
                    '${review.totalSources} papers found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              Expanded(
                child: controller.isLoadingLiterature && review == null
                    ? const LiteratureLoading()
                    : review == null
                    ? const SizedBox.shrink()
                    : review.sources.isEmpty
                    ? const LiteratureEmpty()
                    : ListView.separated(
                        itemCount: review.sources.length,
                        separatorBuilder: (_, _) => const SizedBox(height: kSpaceS),
                        itemBuilder: (BuildContext context, int index) {
                          return SourceTile(source: review.sources[index]);
                        },
                      ),
              ),
              const SizedBox(height: kSpaceM),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: (review == null || review.sources.isEmpty)
                      ? null
                      : () {
                          controller.loadExperimentPlan();
                          Navigator.pushNamed(context, kRoutePlan);
                        },
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Generate experiment plan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
