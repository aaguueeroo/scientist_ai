import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/features/plan/widgets/timeline_dag_layout.dart';
import 'package:scientist_ai/models/experiment_plan.dart';

Step _step({
  required String id,
  required String name,
  required int days,
  List<String> dependsOn = const <String>[],
}) {
  return Step(
    id: id,
    number: 1,
    duration: Duration(days: days),
    name: name,
    description: '',
    dependsOn: dependsOn,
  );
}

void main() {
  group('computeTimelineDagLayout', () {
    test('empty steps yields empty layout', () {
      final TimelineDagLayout layout = computeTimelineDagLayout(<Step>[]);
      expect(layout.nodeCount, 0);
      expect(layout.totalSpanMs, 0);
    });

    test('no depends_on uses sequential chain and single lane', () {
      final List<Step> steps = <Step>[
        _step(id: 'a', name: 'A', days: 2),
        _step(id: 'b', name: 'B', days: 3),
      ];
      final TimelineDagLayout layout = computeTimelineDagLayout(steps);
      expect(layout.usedDAGTiming, isFalse);
      expect(layout.laneCount, 1);
      expect(layout.startMs[0], 0);
      expect(layout.endMs[0], closeTo(2 * Duration.millisecondsPerDay, 1));
      expect(
        layout.startMs[1],
        closeTo(2 * Duration.millisecondsPerDay, 1),
      );
      expect(layout.edges, isEmpty);
    });

    test('parallel roots get separate lanes and same start time', () {
      final List<Step> steps = <Step>[
        _step(id: 'a', name: 'A', days: 5),
        _step(id: 'b', name: 'B', days: 3),
        _step(
          id: 'c',
          name: 'C',
          days: 1,
          dependsOn: <String>['A', 'B'],
        ),
      ];
      final TimelineDagLayout layout = computeTimelineDagLayout(steps);
      expect(layout.usedDAGTiming, isTrue);
      expect(layout.laneCount, greaterThanOrEqualTo(2));
      expect(layout.startMs[0], layout.startMs[1]);
      final double cStart = layout.startMs[2];
      expect(
        cStart,
        greaterThanOrEqualTo(layout.endMs[0]),
      );
      expect(
        cStart,
        greaterThanOrEqualTo(layout.endMs[1]),
      );
      expect(layout.lanes[0], isNot(layout.lanes[1]));
    });

    test('unknown depends_on entries are ignored', () {
      final List<Step> steps = <Step>[
        _step(
          id: 'a',
          name: 'A',
          days: 1,
          dependsOn: <String>['Nope'],
        ),
      ];
      final TimelineDagLayout layout = computeTimelineDagLayout(steps);
      expect(layout.edges, isEmpty);
      expect(layout.usedDAGTiming, isFalse);
    });

    test('cycle falls back to sequential list order', () {
      final List<Step> steps = <Step>[
        _step(
          id: 'a',
          name: 'A',
          days: 1,
          dependsOn: <String>['B'],
        ),
        _step(
          id: 'b',
          name: 'B',
          days: 1,
          dependsOn: <String>['A'],
        ),
      ];
      final TimelineDagLayout layout = computeTimelineDagLayout(steps);
      expect(layout.usedDAGTiming, isFalse);
      expect(layout.edges, isEmpty);
      expect(layout.laneCount, 1);
      expect(layout.startMs[1], greaterThan(layout.startMs[0]));
    });

    test('trims dependency names when matching', () {
      final List<Step> steps = <Step>[
        _step(id: 'a', name: 'Phase A', days: 1),
        _step(
          id: 'b',
          name: 'B',
          days: 1,
          dependsOn: <String>['  Phase A  '],
        ),
      ];
      final TimelineDagLayout layout = computeTimelineDagLayout(steps);
      expect(layout.edges.length, 1);
      expect(layout.usedDAGTiming, isTrue);
    });
  });
}
