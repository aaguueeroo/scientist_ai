import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/data/dto/generate_plan_response_dto.dart';
import 'package:scientist_ai/data/mappers/backend_plan_mapper.dart';

void main() {
  test('toGeneratePlanResult maps QC-only response (plan null)', () {
    final GeneratePlanResponseDto dto = GeneratePlanResponseDto.fromJson(
      <String, dynamic>{
        'plan_id': null,
        'request_id': 'req-1',
        'qc': <String, dynamic>{
          'novelty': 'exact_match',
          'confidence': 'low',
          'references': <Map<String, dynamic>>[],
          'tier_0_drops': 0,
        },
        'plan': null,
      },
    );
    final result = BackendPlanMapper.toGeneratePlanResult(dto);
    expect(result.plan, isNull);
    expect(result.qc.novelty, 'exact_match');
    expect(result.requestId, 'req-1');
  });
}
