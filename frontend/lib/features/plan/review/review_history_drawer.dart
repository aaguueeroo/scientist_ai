import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as m show Material;
import 'package:provider/provider.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import 'models/plan_version.dart';
import 'models/suggestion_batch.dart';
import 'plan_review_controller.dart';
import 'widgets/review_action_bar.dart';

const double _kDrawerWidth = 340;

/// Right-side history drawer. Lists every accepted batch (and the
/// original AI version) with author, timestamp, change count and color
/// chip; tapping a row opens the historical snapshot.
class ReviewHistoryDrawer extends StatelessWidget {
  const ReviewHistoryDrawer({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: _kDrawerWidth, end: 0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double offset, Widget? child) {
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: SizedBox(
              width: _kDrawerWidth,
              child: _DrawerContent(onClose: onClose),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerContent extends StatelessWidget {
  const _DrawerContent({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final PlanReviewController controller =
        context.watch<PlanReviewController>();
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<PlanVersion> versions = controller.versions.reversed.toList();
    return m.Material(
      color: scheme.surface,
      elevation: 12,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(kSpace16),
              child: Row(
                children: <Widget>[
                  Icon(Icons.history_rounded,
                      size: 18, color: scheme.onSurface),
                  const SizedBox(width: kSpace8),
                  Text('Marie\'s revisions', style: textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: kSpace8),
                itemCount: versions.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 4),
                itemBuilder: (BuildContext context, int index) {
                  final PlanVersion version = versions[index];
                  final SuggestionBatch? batch = controller.acceptedBatches
                      .where((SuggestionBatch b) => b.id == version.batchId)
                      .cast<SuggestionBatch?>()
                      .firstWhere(
                        (SuggestionBatch? b) => b != null,
                        orElse: () => null,
                      );
                  final bool isCurrent = index == 0 &&
                      !controller.isHistoricalView;
                  final bool isViewing =
                      controller.viewingVersionId == version.id;
                  return _VersionTile(
                    version: version,
                    versionLabel: 'v${versions.length - 1 - index}',
                    color: batch?.color ?? scheme.outlineVariant,
                    authorLabel: controller.authorLabel(version.authorId),
                    isCurrent: isCurrent,
                    isViewing: isViewing,
                    onTap: () {
                      if (version.isOriginal && !controller.isHistoricalView) {
                        controller.viewVersion(version.id);
                      } else if (isCurrent) {
                        // No-op; already showing current.
                      } else {
                        controller.viewVersion(version.id);
                      }
                    },
                  );
                },
              ),
            ),
            if (controller.isHistoricalView)
              Padding(
                padding: const EdgeInsets.all(kSpace12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: controller.returnToCurrentVersion,
                    icon: const Icon(Icons.fast_forward_rounded, size: 16),
                    label: const Text('Return to current'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({
    required this.version,
    required this.versionLabel,
    required this.color,
    required this.authorLabel,
    required this.isCurrent,
    required this.isViewing,
    required this.onTap,
  });

  final PlanVersion version;
  final String versionLabel;
  final Color color;
  final String authorLabel;
  final bool isCurrent;
  final bool isViewing;
  final VoidCallback onTap;

  String _formatRelative(DateTime at) {
    final Duration delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color tileColor = isViewing
        ? scheme.primaryContainer
        : Colors.transparent;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpace16,
          vertical: kSpace12,
        ),
        color: tileColor,
        child: Row(
          children: <Widget>[
            BatchColorChip(color: color, size: 10),
            const SizedBox(width: kSpace12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        versionLabel,
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(width: kSpace8),
                      Text(
                        authorLabel,
                        style: textTheme.bodySmall,
                      ),
                      const Spacer(),
                      if (isCurrent)
                        Text(
                          'Current',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: kSpace4),
                  Text(
                    version.isOriginal
                        ? 'Marie\'s first draft'
                        : '${version.changeCount} change${version.changeCount == 1 ? '' : 's'}',
                    style: textTheme.bodySmall?.copyWith(
                      color: context.scientist.onSurfaceFaint,
                    ),
                  ),
                  Text(
                    _formatRelative(version.at),
                    style: textTheme.labelSmall?.copyWith(
                      color: context.scientist.onSurfaceFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
