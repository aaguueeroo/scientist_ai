import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../core/app_constants.dart';
import '../../../models/experiment_plan.dart';

/// One directed edge from predecessor index to successor index.
class TimelineDagEdge {
  const TimelineDagEdge({required this.from, required this.to});

  final int from;
  final int to;
}

/// Layout for a dependency-aware horizontal timeline (time-proportional widths).
class TimelineDagLayout {
  const TimelineDagLayout({
    required this.startMs,
    required this.endMs,
    required this.lanes,
    required this.laneCount,
    required this.edges,
    required this.usedDAGTiming,
  });

  factory TimelineDagLayout.empty() {
    return const TimelineDagLayout(
      startMs: <double>[],
      endMs: <double>[],
      lanes: <int>[],
      laneCount: 0,
      edges: <TimelineDagEdge>[],
      usedDAGTiming: false,
    );
  }

  final List<double> startMs;
  final List<double> endMs;
  final List<int> lanes;
  final int laneCount;
  final List<TimelineDagEdge> edges;

  /// When false, [startMs]/[endMs] follow a simple sequential chain (list order).
  final bool usedDAGTiming;

  int get nodeCount => startMs.length;

  double get totalSpanMs {
    if (endMs.isEmpty) {
      return 0;
    }
    double m = 0;
    for (int i = 0; i < endMs.length; i++) {
      m = math.max(m, endMs[i]);
    }
    return m;
  }
}

/// Builds [TimelineDagLayout] from [steps] using `dependsOn` → predecessor names.
TimelineDagLayout computeTimelineDagLayout(List<Step> steps) {
  final int n = steps.length;
  if (n == 0) {
    return TimelineDagLayout.empty();
  }

  final Map<String, int> nameToIndex = <String, int>{};
  for (int i = 0; i < n; i++) {
    nameToIndex[steps[i].name.trim()] = i;
  }

  final List<TimelineDagEdge> edges = <TimelineDagEdge>[];
  final List<List<int>> preds = List<List<int>>.generate(n, (_) => <int>[]);

  for (int i = 0; i < n; i++) {
    for (final String rawDep in steps[i].dependsOn) {
      final int? p = nameToIndex[rawDep.trim()];
      if (p != null && p != i && !preds[i].contains(p)) {
        preds[i].add(p);
        edges.add(TimelineDagEdge(from: p, to: i));
      }
    }
  }

  if (edges.isEmpty) {
    return _layoutSequentialChain(steps);
  }

  final List<int>? topo = _topologicalOrder(n, edges);
  if (topo == null || topo.length != n) {
    return _layoutSequentialListOrder(steps);
  }

  return _layoutDAG(steps, preds, topo, edges);
}

List<double> _effectiveDurationsMs(List<Step> steps) {
  return List<double>.generate(steps.length, (int i) {
    final int ms = steps[i].duration.inMilliseconds;
    return math.max(1, ms.toDouble());
  });
}

TimelineDagLayout _layoutSequentialChain(List<Step> steps) {
  final int n = steps.length;
  final List<double> dur = _effectiveDurationsMs(steps);
  final List<double> startMs = List<double>.filled(n, 0);
  final List<double> endMs = List<double>.filled(n, 0);
  double t = 0;
  for (int i = 0; i < n; i++) {
    startMs[i] = t;
    endMs[i] = t + dur[i];
    t = endMs[i];
  }
  return TimelineDagLayout(
    startMs: startMs,
    endMs: endMs,
    lanes: List<int>.filled(n, 0),
    laneCount: 1,
    edges: const <TimelineDagEdge>[],
    usedDAGTiming: false,
  );
}

TimelineDagLayout _layoutSequentialListOrder(List<Step> steps) {
  final int n = steps.length;
  final List<double> dur = _effectiveDurationsMs(steps);
  final List<double> startMs = List<double>.filled(n, 0);
  final List<double> endMs = List<double>.filled(n, 0);
  double t = 0;
  for (int i = 0; i < n; i++) {
    startMs[i] = t;
    endMs[i] = t + dur[i];
    t = endMs[i];
  }
  return TimelineDagLayout(
    startMs: startMs,
    endMs: endMs,
    lanes: List<int>.filled(n, 0),
    laneCount: 1,
    edges: const <TimelineDagEdge>[],
    usedDAGTiming: false,
  );
}

TimelineDagLayout _layoutDAG(
  List<Step> steps,
  List<List<int>> preds,
  List<int> topo,
  List<TimelineDagEdge> edges,
) {
  final int n = steps.length;
  final List<double> dur = _effectiveDurationsMs(steps);
  final List<double> startMs = List<double>.filled(n, 0);
  final List<double> endMs = List<double>.filled(n, 0);

  for (final int i in topo) {
    double s = 0;
    for (final int p in preds[i]) {
      s = math.max(s, endMs[p]);
    }
    startMs[i] = s;
    endMs[i] = s + dur[i];
  }

  final List<_Interval> intervals = List<_Interval>.generate(n, (int i) {
    return _Interval(index: i, start: startMs[i], end: endMs[i]);
  });
  intervals.sort((_Interval a, _Interval b) {
    final int c = a.start.compareTo(b.start);
    if (c != 0) {
      return c;
    }
    return a.end.compareTo(b.end);
  });

  final List<List<_Interval>> laneOccupants = <List<_Interval>>[];
  final List<int> lanes = List<int>.filled(n, 0);

  for (final _Interval iv in intervals) {
    int L = 0;
    for (;; L++) {
      if (L == laneOccupants.length) {
        laneOccupants.add(<_Interval>[]);
      }
      bool ok = true;
      for (final _Interval o in laneOccupants[L]) {
        if (iv.start < o.end && o.start < iv.end) {
          ok = false;
          break;
        }
      }
      if (ok) {
        laneOccupants[L].add(iv);
        lanes[iv.index] = L;
        break;
      }
    }
  }

  return TimelineDagLayout(
    startMs: startMs,
    endMs: endMs,
    lanes: lanes,
    laneCount: math.max(1, laneOccupants.length),
    edges: edges,
    usedDAGTiming: true,
  );
}

class _Interval {
  const _Interval({
    required this.index,
    required this.start,
    required this.end,
  });

  final int index;
  final double start;
  final double end;
}

/// Kahn topological sort. Returns null if a cycle remains.
List<int>? _topologicalOrder(int n, List<TimelineDagEdge> edges) {
  final List<int> indeg = List<int>.filled(n, 0);
  final List<List<int>> adj = List<List<int>>.generate(n, (_) => <int>[]);
  for (final TimelineDagEdge e in edges) {
    adj[e.from].add(e.to);
    indeg[e.to]++;
  }
  final List<int> q = <int>[];
  for (int i = 0; i < n; i++) {
    if (indeg[i] == 0) {
      q.add(i);
    }
  }
  final List<int> out = <int>[];
  int head = 0;
  while (head < q.length) {
    final int u = q[head++];
    out.add(u);
    for (final int v in adj[u]) {
      indeg[v]--;
      if (indeg[v] == 0) {
        q.add(v);
      }
    }
  }
  if (out.length != n) {
    return null;
  }
  return out;
}

/// Pixel metrics for painting and hit-testing.
class TimelineDagPaintMetrics {
  const TimelineDagPaintMetrics({
    required this.pixelsPerMs,
    required this.contentWidth,
    required this.totalHeight,
    required this.labelBandHeight,
    required this.laneBandTop,
    required this.laneRowHeight,
    required this.subLabelBandHeight,
    required this.nodeRects,
    required this.edgeFromPoints,
    required this.edgeToPoints,
  });

  final double pixelsPerMs;
  final double contentWidth;
  final double totalHeight;
  final double labelBandHeight;
  final double laneBandTop;
  final double laneRowHeight;
  final double subLabelBandHeight;
  final List<Rect> nodeRects;
  final List<Offset> edgeFromPoints;
  final List<Offset> edgeToPoints;
}

/// Converts [layout] to pixel geometry; [viewportInnerWidth] is max width inside padding.
TimelineDagPaintMetrics computeTimelineDagPaintMetrics({
  required TimelineDagLayout layout,
  required double viewportInnerWidth,
  required double labelBandHeight,
  required double laneRowHeight,
  required double subLabelBandHeight,
  required double minNodeWidth,
}) {
  if (layout.nodeCount == 0) {
    return TimelineDagPaintMetrics(
      pixelsPerMs: 1,
      contentWidth: 0,
      totalHeight: labelBandHeight + laneRowHeight + subLabelBandHeight,
      labelBandHeight: labelBandHeight,
      laneBandTop: labelBandHeight,
      laneRowHeight: laneRowHeight,
      subLabelBandHeight: subLabelBandHeight,
      nodeRects: const <Rect>[],
      edgeFromPoints: const <Offset>[],
      edgeToPoints: const <Offset>[],
    );
  }

  final double span = layout.totalSpanMs;
  double ppm = 0.12;
  if (span > 0 && viewportInnerWidth > 0) {
    ppm = viewportInnerWidth / span;
  }
  for (int i = 0; i < layout.nodeCount; i++) {
    final double wMs = layout.endMs[i] - layout.startMs[i];
    final double wPx = wMs * ppm;
    if (wPx < minNodeWidth && wMs > 0) {
      ppm = math.max(ppm, minNodeWidth / wMs);
    }
  }

  final double laneBandTop = labelBandHeight;
  final double graphHeight = layout.laneCount * laneRowHeight;
  final double totalHeight =
      labelBandHeight + graphHeight + subLabelBandHeight;

  final List<Rect> nodeRects = List<Rect>.generate(layout.nodeCount, (int i) {
    final double left = layout.startMs[i] * ppm;
    final double width = math.max(
      minNodeWidth,
      (layout.endMs[i] - layout.startMs[i]) * ppm,
    );
    final int lane = layout.lanes[i];
    final double nodeH = math.min(laneRowHeight - 4, 28);
    final double top =
        laneBandTop + lane * laneRowHeight + (laneRowHeight - nodeH) * 0.5;
    return Rect.fromLTWH(left, top, width, nodeH);
  });

  final List<Offset> fromPts = <Offset>[];
  final List<Offset> toPts = <Offset>[];
  for (final TimelineDagEdge e in layout.edges) {
    final Rect a = nodeRects[e.from];
    final Rect b = nodeRects[e.to];
    fromPts.add(a.centerRight);
    toPts.add(b.centerLeft);
  }

  double maxRight = 0;
  for (final Rect r in nodeRects) {
    maxRight = math.max(maxRight, r.right);
  }
  final double contentWidth = math.max(
    viewportInnerWidth,
    maxRight + kSpace16,
  );

  return TimelineDagPaintMetrics(
    pixelsPerMs: ppm,
    contentWidth: contentWidth,
    totalHeight: totalHeight,
    labelBandHeight: labelBandHeight,
    laneBandTop: laneBandTop,
    laneRowHeight: laneRowHeight,
    subLabelBandHeight: subLabelBandHeight,
    nodeRects: nodeRects,
    edgeFromPoints: fromPts,
    edgeToPoints: toPts,
  );
}

/// Orthogonal connectors between timeline nodes (painted under widgets).
class TimelineDagEdgesPainter extends CustomPainter {
  TimelineDagEdgesPainter({
    required this.fromPoints,
    required this.toPoints,
    required this.color,
  });

  final List<Offset> fromPoints;
  final List<Offset> toPoints;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (fromPoints.length != toPoints.length || fromPoints.isEmpty) {
      return;
    }
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = kPlanTimelineLineThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < fromPoints.length; i++) {
      final Offset a = fromPoints[i];
      final Offset b = toPoints[i];
      final Path path = Path();
      path.moveTo(a.dx, a.dy);
      final double midX = a.dx + (b.dx - a.dx) * 0.5;
      path.lineTo(midX, a.dy);
      path.lineTo(midX, b.dy);
      path.lineTo(b.dx, b.dy);
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant TimelineDagEdgesPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.fromPoints != fromPoints ||
        oldDelegate.toPoints != toPoints;
  }
}
