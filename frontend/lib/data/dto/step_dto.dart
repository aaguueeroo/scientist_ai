class StepDto {
  const StepDto({
    required this.number,
    required this.durationSeconds,
    required this.name,
    required this.description,
    this.milestone,
  });

  factory StepDto.fromJson(Map<String, dynamic> json) {
    return StepDto(
      number: (json['number'] as num).toInt(),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String,
      milestone: json['milestone'] as String?,
    );
  }

  final int number;
  final int durationSeconds;
  final String name;
  final String description;
  final String? milestone;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'number': number,
      'duration_seconds': durationSeconds,
      'name': name,
      'description': description,
      'milestone': milestone,
    };
  }
}
