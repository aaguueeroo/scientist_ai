import 'dart:math' as math;

import 'package:flutter/material.dart' hide Step;

import '../../../core/app_constants.dart';
import '../../../models/experiment_plan.dart';
import 'timeline_dag_layout.dart';

/// Scrollable DAG timeline: edges under positioned nodes and labels.
class PlanTimelineDagCanvas extends StatelessWidget {
  const PlanTimelineDagCanvas({
    super.key,
    required this.steps,
    required this.metrics,
    required this.edgeColor,
    required this.nameLabelBuilder,
    required this.subLabelBuilder,
    required this.nodeBuilder,
  });

  final List<Step> steps;
  final TimelineDagPaintMetrics metrics;
  final Color edgeColor;

  final Widget Function(BuildContext context, Step step, int index)
      nameLabelBuilder;
  final Widget Function(BuildContext context, Step step, int index)
      subLabelBuilder;
  final Widget Function(BuildContext context, Step step, int index, Rect nodeRect)
      nodeBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: metrics.contentWidth,
      height: metrics.totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          CustomPaint(
            size: Size(metrics.contentWidth, metrics.totalHeight),
            painter: TimelineDagEdgesPainter(
              fromPoints: metrics.edgeFromPoints,
              toPoints: metrics.edgeToPoints,
              color: edgeColor,
            ),
          ),
          ..._stackChildren(context),
        ],
      ),
    );
  }

  List<Widget> _stackChildren(BuildContext context) {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < steps.length; i++) {
      final Rect r = metrics.nodeRects[i];
      final double nameW =
          math.max(96.0, r.width + kSpace16).clamp(0.0, metrics.contentWidth);
      final double nameL =
          (r.center.dx - nameW / 2).clamp(0.0, metrics.contentWidth - nameW);
      out.add(
        Positioned(
          left: nameL,
          top: 0,
          width: nameW,
          height: metrics.labelBandHeight,
          child: nameLabelBuilder(context, steps[i], i),
        ),
      );
      out.add(
        Positioned.fromRect(
          rect: r,
          child: nodeBuilder(context, steps[i], i, r),
        ),
      );
      final double subW =
          math.max(kPlanTimelineDagMinNodeWidth, r.width).clamp(0.0, metrics.contentWidth);
      final double subL =
          (r.center.dx - subW / 2).clamp(0.0, metrics.contentWidth - subW);
      out.add(
        Positioned(
          left: subL,
          top: metrics.totalHeight - metrics.subLabelBandHeight,
          width: subW,
          height: metrics.subLabelBandHeight,
          child: subLabelBuilder(context, steps[i], i),
        ),
      );
    }
    return out;
  }
}
