import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/data/dto/experiment_plan_dto.dart';
import 'package:scientist_ai/data/dto/material_dto.dart';
import 'package:scientist_ai/data/dto/step_dto.dart';
import 'package:scientist_ai/data/dto/time_plan_dto.dart';
import 'package:scientist_ai/data/dto/budget_dto.dart';
import 'package:scientist_ai/data/mappers/experiment_plan_mapper.dart';
import 'package:scientist_ai/models/experiment_plan.dart';
import 'package:scientist_ai/models/plan_source_ref.dart';

void main() {
  group('ExperimentPlanMapper – source refs', () {
    const Map<String, dynamic> inputLiteratureRef = <String, dynamic>{
      'kind': 'literature',
      'reference_index': 2,
    };
    const Map<String, dynamic> inputPreviousLearningRef = <String, dynamic>{
      'kind': 'previous_learning',
    };

    ExperimentPlanDto _buildDto({
      List<Map<String, dynamic>> stepsSectionRefs =
          const <Map<String, dynamic>>[],
      List<Map<String, dynamic>> materialsSectionRefs =
          const <Map<String, dynamic>>[],
      List<Map<String, dynamic>> stepRefs = const <Map<String, dynamic>>[],
      List<Map<String, dynamic>> materialRefs =
          const <Map<String, dynamic>>[],
    }) {
      return ExperimentPlanDto(
        description: 'Test plan',
        stepsSectionSourceRefs: stepsSectionRefs,
        materialsSectionSourceRefs: materialsSectionRefs,
        budget: BudgetDto(
          total: 100,
          currency: 'USD',
          materials: <MaterialDto>[
            MaterialDto(
              title: 'Reagent A',
              catalogNumber: 'RA-001',
              description: 'Test reagent',
              amount: 1,
              price: 50,
              sourceRefs: materialRefs,
            ),
          ],
        ),
        timePlan: TimePlanDto(
          totalDurationSeconds: 86400,
          steps: <StepDto>[
            StepDto(
              number: 1,
              durationSeconds: 86400,
              name: 'Step one',
              description: 'Do the thing',
              sourceRefs: stepRefs,
            ),
          ],
        ),
      );
    }

    test('maps literature source ref on step', () {
      final ExperimentPlanDto inputDto =
          _buildDto(stepRefs: <Map<String, dynamic>>[inputLiteratureRef]);

      final ExperimentPlan actualPlan = ExperimentPlanMapper.toDomain(inputDto);

      final List<PlanSourceRef> actualRefs =
          actualPlan.timePlan.steps.first.sourceRefs;
      expect(actualRefs, hasLength(1));
      final LiteratureSourceRef actualLit =
          actualRefs.first as LiteratureSourceRef;
      expect(actualLit.referenceIndex, 2);
    });

    test('maps previous-learning source ref on material', () {
      final ExperimentPlanDto inputDto =
          _buildDto(materialRefs: <Map<String, dynamic>>[inputPreviousLearningRef]);

      final ExperimentPlan actualPlan = ExperimentPlanMapper.toDomain(inputDto);

      final List<PlanSourceRef> actualRefs =
          actualPlan.budget.materials.first.sourceRefs;
      expect(actualRefs, hasLength(1));
      expect(actualRefs.first, isA<PreviousLearningSourceRef>());
    });

    test('maps section-level source refs on ExperimentPlan', () {
      final ExperimentPlanDto inputDto = _buildDto(
        stepsSectionRefs: <Map<String, dynamic>>[inputLiteratureRef],
        materialsSectionRefs: <Map<String, dynamic>>[inputPreviousLearningRef],
      );

      final ExperimentPlan actualPlan = ExperimentPlanMapper.toDomain(inputDto);

      expect(actualPlan.stepsSectionSourceRefs, hasLength(1));
      expect(
        actualPlan.stepsSectionSourceRefs.first,
        isA<LiteratureSourceRef>(),
      );
      expect(actualPlan.materialsSectionSourceRefs, hasLength(1));
      expect(
        actualPlan.materialsSectionSourceRefs.first,
        isA<PreviousLearningSourceRef>(),
      );
    });

    test('empty source_refs when field is absent', () {
      final ExperimentPlanDto inputDto = _buildDto();

      final ExperimentPlan actualPlan = ExperimentPlanMapper.toDomain(inputDto);

      expect(actualPlan.timePlan.steps.first.sourceRefs, isEmpty);
      expect(actualPlan.budget.materials.first.sourceRefs, isEmpty);
      expect(actualPlan.stepsSectionSourceRefs, isEmpty);
      expect(actualPlan.materialsSectionSourceRefs, isEmpty);
    });

    test('round-trips source refs through fromDomain → toDomain', () {
      const List<PlanSourceRef> inputStepRefs = <PlanSourceRef>[
        LiteratureSourceRef(referenceIndex: 3),
        PreviousLearningSourceRef(),
      ];
      final ExperimentPlan inputPlan = ExperimentPlan(
        description: 'Round-trip plan',
        stepsSectionSourceRefs: const <PlanSourceRef>[
          LiteratureSourceRef(referenceIndex: 1),
        ],
        materialsSectionSourceRefs: const <PlanSourceRef>[
          PreviousLearningSourceRef(),
        ],
        budget: Budget(
          total: 0,
          materials: <Material>[
            const Material(
              id: 'mat-1',
              title: 'Widget',
              catalogNumber: 'W-1',
              description: '',
              amount: 1,
              price: 0,
              sourceRefs: <PlanSourceRef>[
                LiteratureSourceRef(referenceIndex: 2),
              ],
            ),
          ],
        ),
        timePlan: TimePlan(
          totalDuration: const Duration(days: 1),
          steps: <Step>[
            const Step(
              id: 'step-1',
              number: 1,
              duration: Duration(days: 1),
              name: 'Step',
              description: '',
              sourceRefs: inputStepRefs,
            ),
          ],
        ),
      );

      final ExperimentPlanDto actualDto = ExperimentPlanMapper.fromDomain(inputPlan);
      final ExperimentPlan actualPlan = ExperimentPlanMapper.toDomain(actualDto);

      expect(
        actualPlan.timePlan.steps.first.sourceRefs,
        equals(inputStepRefs),
      );
      expect(
        actualPlan.budget.materials.first.sourceRefs,
        equals(<PlanSourceRef>[const LiteratureSourceRef(referenceIndex: 2)]),
      );
      expect(
        actualPlan.stepsSectionSourceRefs,
        equals(<PlanSourceRef>[const LiteratureSourceRef(referenceIndex: 1)]),
      );
      expect(
        actualPlan.materialsSectionSourceRefs,
        equals(const <PlanSourceRef>[PreviousLearningSourceRef()]),
      );
    });

    test('ignores unknown kind gracefully, defaults to previous_learning', () {
      const Map<String, dynamic> inputUnknownRef = <String, dynamic>{
        'kind': 'external_database',
      };
      final ExperimentPlanDto inputDto =
          _buildDto(stepRefs: <Map<String, dynamic>>[inputUnknownRef]);

      final ExperimentPlan actualPlan = ExperimentPlanMapper.toDomain(inputDto);

      expect(
        actualPlan.timePlan.steps.first.sourceRefs.first,
        isA<PreviousLearningSourceRef>(),
      );
    });
  });
}
