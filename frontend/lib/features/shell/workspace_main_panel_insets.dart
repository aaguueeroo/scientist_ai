import 'package:flutter/material.dart';

import '../../core/app_constants.dart';

/// Horizontal inset of the centered main column within the shell's main panel
/// (the “gutter” between that column and the sidebar).
class WorkspaceMainPanelInsets extends InheritedWidget {
  const WorkspaceMainPanelInsets({
    super.key,
    required this.leftGutter,
    required super.child,
  });

  final double leftGutter;

  static WorkspaceMainPanelInsets? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<WorkspaceMainPanelInsets>();
  }

  static double leftGutterOf(BuildContext context) {
    return maybeOf(context)?.leftGutter ?? 0;
  }

  @override
  bool updateShouldNotify(WorkspaceMainPanelInsets oldWidget) {
    return leftGutter != oldWidget.leftGutter;
  }
}

/// [Positioned.left] for the Marie corner illustration so it sits in the left
/// gutter; may be negative to extend past the content column’s padding.
double marieWorkspacePeekStackLeft(BuildContext context) {
  return marieWorkspacePeekLeftForGutter(
    WorkspaceMainPanelInsets.leftGutterOf(context),
  );
}

/// Same as [marieWorkspacePeekStackLeft] when the gutter width is known
/// (e.g. from [LayoutBuilder] in [AppShell]).
double marieWorkspacePeekLeftForGutter(double leftGutter) =>
    kSpace4 + 100 - leftGutter;
