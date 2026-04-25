import 'step_dto.dart';

class TimePlanDto {
  const TimePlanDto({
    required this.totalDurationSeconds,
    required this.steps,
  });

  factory TimePlanDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSteps =
        (json['steps'] as List<dynamic>? ?? <dynamic>[]);
    return TimePlanDto(
      totalDurationSeconds: (json['total_duration_seconds'] as num).toInt(),
      steps: rawSteps
          .map((dynamic e) => StepDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int totalDurationSeconds;
  final List<StepDto> steps;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total_duration_seconds': totalDurationSeconds,
      'steps': steps.map((StepDto s) => s.toJson()).toList(),
    };
  }
}
