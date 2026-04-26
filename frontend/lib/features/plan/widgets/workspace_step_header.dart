import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_colors.dart';
import '../../../models/experiment_plan.dart' show ExperimentPlan;
import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../core/theme/theme_context.dart';

const List<String> kWorkspaceStepLabels = <String>[
  'Prompt',
  'Literature review',
  'Experiment Plan',
];

const List<IconData> kWorkspaceStepIcons = <IconData>[
  Icons.chat_bubble_outline_rounded,
  Icons.menu_book_outlined,
  Icons.science_outlined,
];

const double _kWorkspaceTabBarMaxWidth = 640;
const double _kWorkspaceTabTrackPadding = 4;
const double _kWorkspaceTabMinWidth = 260;
const double _kWorkspaceTabPillRadius = 6;
const int _kWorkspaceTabBarAnimationMs = 220;

void navigateToWorkspaceStep(BuildContext context, int index) {
  if (index == 0) {
    context.go(kRouteHome);
  } else if (index == 1) {
    context.go(kRouteLiterature);
  } else if (index == 2) {
    context.go(kRoutePlan);
  }
}

/// Gating for workspace tabs: step 0 is always [true]; step 1 after a research
/// question exists; step 2 after the user has started or received a plan load.
List<bool> workspaceStepEnabled({
  required String? currentQuery,
  required bool isLoadingPlan,
  required ExperimentPlan? experimentPlan,
  required String? planError,
}) {
  final bool hasQuery = (currentQuery ?? '').trim().isNotEmpty;
  final bool canUsePlan = hasQuery &&
      (isLoadingPlan ||
          experimentPlan != null ||
          (planError != null && planError.isNotEmpty));
  return <bool>[
    true,
    hasQuery,
    canUsePlan,
  ];
}

class WorkspaceStepHeader extends StatelessWidget {
  const WorkspaceStepHeader({
    super.key,
    required this.stepIndex,
    required this.stepLabels,
    required this.onSelect,
    this.stepEnabled,
  }) : assert(
          stepEnabled == null || stepEnabled.length == stepLabels.length,
        );

  final int stepIndex;
  final List<String> stepLabels;
  final ValueChanged<int> onSelect;
  /// When null, every step is tappable. Otherwise must match [stepLabels] length.
  final List<bool>? stepEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double parentW = constraints.maxWidth;
        final double cap = _kWorkspaceTabBarMaxWidth;
        final double barW = !parentW.isFinite
            ? cap
            : (parentW < cap ? parentW : cap);
        final double effectiveW = barW < _kWorkspaceTabMinWidth
            ? _kWorkspaceTabMinWidth
            : barW;
        final Widget track = SizedBox(
          width: effectiveW,
          child: _WorkspaceSegmentedTrack(
            stepLabels: stepLabels,
            stepIndex: stepIndex,
            stepEnabled: stepEnabled,
            onSelect: onSelect,
          ),
        );
        if (parentW < _kWorkspaceTabMinWidth) {
          return Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: kSpace8),
              child: track,
            ),
          );
        }
        return Center(child: track);
      },
    );
  }
}

class _WorkspaceSegmentedTrack extends StatelessWidget {
  const _WorkspaceSegmentedTrack({
    required this.stepLabels,
    required this.stepIndex,
    required this.stepEnabled,
    required this.onSelect,
  });

  final List<String> stepLabels;
  final int stepIndex;
  final List<bool>? stepEnabled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    return Semantics(
      container: true,
      label: 'Workspace step',
      child: Container(
        padding: const EdgeInsets.all(_kWorkspaceTabTrackPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(kRadius + 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final int n = stepLabels.length;
              if (n == 0) {
                return const SizedBox.shrink();
              }
              final double w = c.maxWidth;
              final double h = 80;
              return SizedBox(
                width: w,
                height: h,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: <Widget>[
                    _SelectionPill(
                      stepIndex: stepIndex,
                      count: n,
                      width: w,
                      height: h,
                      scheme: scheme,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (int i = 0; i < n; i++) ...<Widget>[
                          Expanded(
                            child: _WorkspaceStepTab(
                              icon: i < kWorkspaceStepIcons.length
                                  ? kWorkspaceStepIcons[i]
                                  : Icons.tab_outlined,
                              label: stepLabels[i],
                              isSelected: i == stepIndex,
                              isEnabled: stepEnabled == null || stepEnabled![i],
                              showLeadingDivider: i > 0,
                              onTap: () => onSelect(i),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ),
    );
  }
}

class _SelectionPill extends StatelessWidget {
  const _SelectionPill({
    required this.stepIndex,
    required this.count,
    required this.width,
    required this.height,
    required this.scheme,
  });

  final int stepIndex;
  final int count;
  final double width;
  final double height;
  final ColorScheme scheme;

  BorderRadius _radiusForIndex(int i, int n) {
    if (n == 1) {
      return BorderRadius.circular(_kWorkspaceTabPillRadius);
    }
    const Radius r = Radius.circular(_kWorkspaceTabPillRadius);
    const Radius z = Radius.zero;
    if (i == 0) {
      return const BorderRadius.only(
        topLeft: r,
        bottomLeft: r,
        topRight: z,
        bottomRight: z,
      );
    }
    if (i == n - 1) {
      return const BorderRadius.only(
        topLeft: z,
        bottomLeft: z,
        topRight: r,
        bottomRight: r,
      );
    }
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const SizedBox.shrink();
    }
    final double segW = width / count;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: _kWorkspaceTabBarAnimationMs),
      curve: Curves.easeOutCubic,
      left: stepIndex * segW,
      top: 0,
      width: segW,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: _radiusForIndex(stepIndex, count),
        ),
      ),
    );
  }
}

class _WorkspaceStepTab extends StatefulWidget {
  const _WorkspaceStepTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    required this.showLeadingDivider,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isEnabled;
  final bool showLeadingDivider;
  final VoidCallback onTap;

  @override
  State<_WorkspaceStepTab> createState() => _WorkspaceStepTabState();
}

class _WorkspaceStepTabState extends State<_WorkspaceStepTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final bool selected = widget.isSelected;
    final bool enabled = widget.isEnabled;
    final Color unselectedLabelColor = scheme.onSurfaceVariant;
    final bool showHover = enabled && _isHovered && !selected;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: widget.label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: showHover
              ? AppColors.skeleton.withValues(alpha: 0.2)
              : Colors.transparent,
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                InkWell(
                  onTap: enabled ? widget.onTap : null,
                  hoverColor: AppColors.skeleton.withValues(alpha: 0.12),
                  splashColor: scheme.primary.withValues(alpha: 0.1),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: kSpace8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            widget.icon,
                            size: 22,
                            color: selected
                                ? scheme.primary
                                : unselectedLabelColor,
                          ),
                          const SizedBox(height: kSpace4),
                          Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : unselectedLabelColor,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
