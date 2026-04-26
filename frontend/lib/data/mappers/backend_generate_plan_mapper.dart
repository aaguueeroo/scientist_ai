import 'dart:math' as math;

import '../../core/id_generator.dart';
import '../../models/experiment_plan.dart';

/// Maps the FastAPI `ExperimentPlan` JSON (nested under `plan` in
/// [GeneratePlanResponse]) into the Flutter domain [ExperimentPlan].
class BackendGeneratePlanMapper {
  const BackendGeneratePlanMapper._();

  static ExperimentPlan toDomain(Map<String, dynamic> plan) {
    final String description = (plan['hypothesis'] as String?)?.trim().isNotEmpty == true
        ? plan['hypothesis'] as String
        : 'Experiment plan';

    final List<dynamic> rawMats =
        plan['materials'] as List<dynamic>? ?? const <dynamic>[];
    final List<Material> materials = <Material>[
      for (int i = 0; i < rawMats.length; i++)
        _materialFromBackend(
          Map<String, dynamic>.from(rawMats[i] as Map),
          i,
        ),
    ];

    double total = (plan['budget'] is Map<String, dynamic>)
        ? (((plan['budget'] as Map<String, dynamic>)['total_usd'] as num?)?.toDouble() ?? 0)
        : 0;
    if (total <= 0 && materials.isNotEmpty) {
      total = materials.map((Material m) => m.price * m.amount).fold(0.0, (a, b) => a + b);
    }

    final List<dynamic> rawPhases =
        plan['timeline'] as List<dynamic>? ?? const <dynamic>[];
    final List<Step> steps = <Step>[
      for (int i = 0; i < rawPhases.length; i++)
        _stepFromTimeline(
          Map<String, dynamic>.from(rawPhases[i] as Map),
          i + 1,
        ),
    ];

    final Duration totalDur = steps.isEmpty
        ? Duration.zero
        : Duration(
            seconds: steps.map((Step s) => s.duration.inSeconds).fold(0, (a, b) => a + b),
          );

    return ExperimentPlan(
      description: description,
      budget: Budget(
        total: total,
        materials: materials,
      ),
      timePlan: TimePlan(
        totalDuration: totalDur,
        steps: steps,
      ),
    );
  }

  static Material _materialFromBackend(Map<String, dynamic> m, int index) {
    final num? qty = m['qty'] as num?;
    final num? unitCost = m['unit_cost_usd'] as num?;
    final int amount = math.max(1, (qty ?? 1).round());
    final double price = (unitCost ?? 0).toDouble();
    final String title = (m['reagent'] as String?) ?? 'Material ${index + 1}';
    final String sku = (m['sku'] as String?) ?? '';
    final String vendor = (m['vendor'] as String?) ?? '';
    final String? notes = m['notes'] as String?;
    return Material(
      id: generateLocalId('mat'),
      title: title,
      catalogNumber: sku,
      description: [if (vendor.isNotEmpty) vendor, if (notes != null && notes.isNotEmpty) notes]
          .join(' — '),
      amount: amount,
      price: price,
    );
  }

  static Step _stepFromTimeline(Map<String, dynamic> phase, int number) {
    final String name = (phase['phase'] as String?) ?? 'Phase $number';
    final int days = (phase['duration_days'] as num?)?.toInt() ?? 0;
    final List<dynamic> deps = phase['depends_on'] as List<dynamic>? ?? const <dynamic>[];
    final List<String> dependsOn = deps.map((dynamic e) => e.toString()).toList();
    return Step(
      id: generateLocalId('step'),
      number: number,
      duration: Duration(days: math.max(0, days)),
      name: name,
      description: '',
      dependsOn: dependsOn,
    );
  }
}
