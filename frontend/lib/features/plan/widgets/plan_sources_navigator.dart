import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';

import '../../../models/literature_review.dart';
import '../../../models/plan_source_ref.dart';

const Duration kPlanSourceScrollDuration = Duration(milliseconds: 450);
const Duration kPlanSourceHighlightVisibleDuration = Duration(
  milliseconds: 800,
);

/// Provides [GlobalKey]s for each reference entry in [PlanReferencesPanel]
/// and exposes [scrollToRef] so source badges can trigger a smooth scroll.
///
/// Wrap the plan body in [PlanSourcesNavigatorScope] to inject this into the
/// subtree. Badges and the panel both find it via [PlanSourcesNavigator.maybeOf].
class PlanSourcesNavigator extends InheritedWidget {
  const PlanSourcesNavigator({
    super.key,
    required this.literatureReview,
    required this.literatureKeys,
    required this.previousLearningKey,
    required this.highlightedRef,
    required this.onScrollToRef,
    required super.child,
  });

  final LiteratureReview? literatureReview;

  /// Keys indexed 1-based (matching [LiteratureSourceRef.referenceIndex]).
  final Map<int, GlobalKey> literatureKeys;

  /// Key for the previous-learning row in the references panel.
  final GlobalKey previousLearningKey;

  /// The reference row currently being highlighted after [scrollToRef], or
  /// `null` when none. Listen with [ValueListenableBuilder] in the panel.
  final ValueNotifier<PlanSourceRef?> highlightedRef;

  /// [anchorContext] should be a context under the plan [ListView] (e.g. the
  /// source badge) so the parent [Scrollable] can be used when the target row
  /// is not built yet.
  final void Function(PlanSourceRef ref, BuildContext? anchorContext)
  onScrollToRef;

  static PlanSourcesNavigator? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PlanSourcesNavigator>();
  }

  void scrollToRef(PlanSourceRef ref, [BuildContext? anchorContext]) {
    onScrollToRef(ref, anchorContext);
  }

  @override
  bool updateShouldNotify(PlanSourcesNavigator oldWidget) =>
      literatureReview != oldWidget.literatureReview ||
      literatureKeys != oldWidget.literatureKeys ||
      previousLearningKey != oldWidget.previousLearningKey;
}

/// Stateful wrapper that owns [GlobalKey]s and rebuilds them when the source
/// count changes. Inject above any plan body that needs scroll-to-reference.
class PlanSourcesNavigatorScope extends StatefulWidget {
  const PlanSourcesNavigatorScope({
    super.key,
    required this.literatureReview,
    required this.child,
  });

  final LiteratureReview? literatureReview;
  final Widget child;

  @override
  State<PlanSourcesNavigatorScope> createState() =>
      _PlanSourcesNavigatorScopeState();
}

class _PlanSourcesNavigatorScopeState extends State<PlanSourcesNavigatorScope> {
  late Map<int, GlobalKey> _literatureKeys;
  late GlobalKey _previousLearningKey;
  late final ValueNotifier<PlanSourceRef?> _highlightedRef;
  Timer? _highlightClearTimer;

  @override
  void initState() {
    super.initState();
    _highlightedRef = ValueNotifier<PlanSourceRef?>(null);
    _buildKeys();
  }

  @override
  void didUpdateWidget(PlanSourcesNavigatorScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int oldCount = oldWidget.literatureReview?.sources.length ?? 0;
    final int newCount = widget.literatureReview?.sources.length ?? 0;
    if (oldCount != newCount) {
      setState(_buildKeys);
    }
  }

  @override
  void dispose() {
    _highlightClearTimer?.cancel();
    _highlightedRef.dispose();
    super.dispose();
  }

  void _buildKeys() {
    final int count = widget.literatureReview?.sources.length ?? 0;
    _literatureKeys = <int, GlobalKey>{
      for (int i = 1; i <= count; i++) i: GlobalKey(),
    };
    _previousLearningKey = GlobalKey();
  }

  void _scrollToRef(PlanSourceRef ref, BuildContext? anchorContext) {
    _highlightClearTimer?.cancel();
    unawaited(_runScrollToRefAsync(ref, anchorContext));
  }

  /// Returns the target [BuildContext] when the ref row is already built.
  BuildContext? _contextForRef(PlanSourceRef ref) {
    return switch (ref) {
      LiteratureSourceRef(:final int referenceIndex) =>
        _literatureKeys[referenceIndex]?.currentContext,
      PreviousLearningSourceRef() => _previousLearningKey.currentContext,
    };
  }

  bool _scrollTargetToVisible(PlanSourceRef ref) {
    final BuildContext? targetContext = _contextForRef(ref);
    if (targetContext == null) {
      return false;
    }
    Scrollable.ensureVisible(
      targetContext,
      duration: kPlanSourceScrollDuration,
      curve: Curves.easeInOutCubic,
      alignment: 0.12,
    );
    return true;
  }

  /// [ListView] only builds off-screen children lazily, so the reference
  /// [GlobalKey] often has no [BuildContext] until we scroll. Scroll the
  /// list toward the end first, then [Scrollable.ensureVisible] on the row.
  Future<void> _runScrollToRefAsync(
    PlanSourceRef ref,
    BuildContext? anchorContext,
  ) async {
    if (_scrollTargetToVisible(ref)) {
      if (mounted) {
        _applyHighlight(ref);
      }
      return;
    }
    final ScrollableState? scrollable = anchorContext == null
        ? null
        : Scrollable.maybeOf(anchorContext);
    if (scrollable != null) {
      final ScrollPosition p = scrollable.position;
      int guard = 0;
      while (!p.hasContentDimensions && guard < 8) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        guard += 1;
        if (!mounted) {
          return;
        }
      }
      if (p.hasContentDimensions) {
        await p.animateTo(
          p.maxScrollExtent,
          duration: kPlanSourceScrollDuration,
          curve: Curves.easeInOutCubic,
        );
      }
    } else {
      await Future<void>.delayed(Duration.zero);
    }
    if (!mounted) {
      return;
    }
    if (_scrollTargetToVisible(ref)) {
      _applyHighlight(ref);
      return;
    }
    // One more frame: items may have mounted after the scroll animation.
    await Future<void>.delayed(const Duration(milliseconds: 32));
    if (!mounted) {
      return;
    }
    if (_scrollTargetToVisible(ref)) {
      _applyHighlight(ref);
      return;
    }
    if (scrollable == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (_scrollTargetToVisible(ref)) {
          _applyHighlight(ref);
        } else {
          _applyHighlight(ref);
        }
      });
      return;
    }
    _applyHighlight(ref);
  }

  void _applyHighlight(PlanSourceRef ref) {
    _highlightedRef.value = ref;
    _highlightClearTimer = Timer(kPlanSourceHighlightVisibleDuration, () {
      if (_highlightedRef.value == ref) {
        _highlightedRef.value = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlanSourcesNavigator(
      literatureReview: widget.literatureReview,
      literatureKeys: _literatureKeys,
      previousLearningKey: _previousLearningKey,
      highlightedRef: _highlightedRef,
      onScrollToRef: _scrollToRef,
      child: widget.child,
    );
  }
}
