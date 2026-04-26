import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as m show Material;
import 'package:provider/provider.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../ui/app_surface.dart';
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
    final Color batchFallback = context.scientist.onSurfaceFaint;
    return m.Material(
      color: scheme.surface,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(kRadius),
          bottomLeft: Radius.circular(kRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              color: scheme.surface,
              padding: const EdgeInsets.fromLTRB(
                kSpace16,
                kSpace16,
                kSpace4,
                kSpace12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: kSpace12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Version history',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: kSpace4),
                        Text(
                          'Preview Marie\'s revisions or restore an earlier state.',
                          style: textTheme.bodySmall?.copyWith(
                            color: context.scientist.onSurfaceFaint,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    tooltip: 'Close',
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: context.scientist.sidebarBackground,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace12,
                    vertical: kSpace12,
                  ),
                  itemCount: versions.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: kSpace8),
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
                    final bool canRestore =
                        isViewing && !isCurrent && !version.isOriginal;
                    return _VersionTile(
                      version: version,
                      versionLabel: 'v${versions.length - 1 - index}',
                      color: batch?.color ?? batchFallback,
                      authorLabel: controller.authorLabel(version.authorId),
                      isCurrent: isCurrent,
                      isViewing: isViewing,
                      onTap: () {
                        if (version.isOriginal &&
                            !controller.isHistoricalView) {
                          controller.viewVersion(version.id);
                        } else if (isCurrent) {
                          // No-op; already showing current.
                        } else {
                          controller.viewVersion(version.id);
                        }
                      },
                      onRestore: canRestore
                          ? () => controller.restoreVersion(version.id)
                          : null,
                    );
                  },
                ),
              ),
            ),
            if (controller.isHistoricalView) ...<Widget>[
              Container(
                color: scheme.surface,
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
    this.onRestore,
  });

  final PlanVersion version;
  final String versionLabel;
  final Color color;
  final String authorLabel;
  final bool isCurrent;
  final bool isViewing;
  final VoidCallback onTap;
  final VoidCallback? onRestore;

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
    final bool isActiveCard = isViewing;
    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: kSpace12,
        vertical: kSpace12,
      ),
      color: isActiveCard
          ? scheme.primaryContainer
          : scheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: BatchColorChip(color: color, size: 12),
          ),
          const SizedBox(width: kSpace12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        versionLabel,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpace8,
                          vertical: kSpace4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(kRadius),
                        ),
                        child: Text(
                          'Current',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else if (isViewing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpace8,
                          vertical: kSpace4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(kRadius),
                        ),
                        child: Text(
                          'Previewing',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: kSpace4),
                Text(
                  authorLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: kSpace4),
                Text(
                  version.isOriginal
                      ? 'Marie\'s first draft'
                      : '${version.changeCount} change${version.changeCount == 1 ? '' : 's'}',
                  style: textTheme.bodySmall?.copyWith(
                    color: context.scientist.onSurfaceFaint,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: kSpace4),
                Text(
                  _formatRelative(version.at),
                  style: textTheme.labelSmall?.copyWith(
                    color: context.scientist.onSurfaceFaint,
                  ),
                ),
                if (onRestore != null) ...<Widget>[
                  const SizedBox(height: kSpace8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: onRestore,
                      icon: const Icon(
                        Icons.restore_rounded,
                        size: 14,
                      ),
                      label: const Text('Restore this version'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpace12,
                          vertical: kSpace8,
                        ),
                        textStyle: textTheme.labelSmall,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
