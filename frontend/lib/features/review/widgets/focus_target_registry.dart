import 'package:flutter/widgets.dart';

import '../../plan/review/models/change_target.dart';
import '../../plan/review/models/review_section.dart';

/// Lightweight in-tree registry that lets focus-aware widgets register the
/// [GlobalKey] of their bounding box, so the Reviewer screen can
/// programmatically scroll to a specific focused [ChangeTarget] or
/// [ReviewSection].
///
/// The registry is opt-in: when no [FocusTargetRegistry] is in scope (i.e.
/// the regular plan review surface), [registerTarget] / [registerSection]
/// are no-ops and rendering is unaffected.
///
/// The backing maps are owned by the host [State] (so they survive widget
/// rebuilds) and passed in via the constructor; the inherited widget itself
/// is just a thin lookup channel.
class FocusTargetRegistry extends InheritedWidget {
  const FocusTargetRegistry({
    super.key,
    required this.targetKeys,
    required this.sectionKeys,
    required super.child,
  });

  final Map<ChangeTarget, GlobalKey> targetKeys;
  final Map<ReviewSection, GlobalKey> sectionKeys;

  /// Idempotently associates [target] with [key]. Subsequent registrations
  /// for the same [target] overwrite the previous key (last widget wins).
  void registerTarget(ChangeTarget target, GlobalKey key) {
    targetKeys[target] = key;
  }

  void registerSection(ReviewSection section, GlobalKey key) {
    sectionKeys[section] = key;
  }

  GlobalKey? keyFor(ChangeTarget target) => targetKeys[target];
  GlobalKey? keyForSection(ReviewSection section) => sectionKeys[section];

  static FocusTargetRegistry? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FocusTargetRegistry>();
  }

  @override
  bool updateShouldNotify(FocusTargetRegistry oldWidget) {
    return targetKeys != oldWidget.targetKeys ||
        sectionKeys != oldWidget.sectionKeys;
  }
}
