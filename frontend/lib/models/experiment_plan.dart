class ExperimentPlan {
  const ExperimentPlan({
    required this.description,
    required this.budget,
    required this.timePlan,
  });

  final String description;
  final Budget budget;
  final TimePlan timePlan;

  ExperimentPlan copyWith({
    String? description,
    Budget? budget,
    TimePlan? timePlan,
  }) {
    return ExperimentPlan(
      description: description ?? this.description,
      budget: budget ?? this.budget,
      timePlan: timePlan ?? this.timePlan,
    );
  }
}

class Budget {
  const Budget({
    required this.total,
    required this.materials,
  });

  final double total;
  final List<Material> materials;

  Budget copyWith({
    double? total,
    List<Material>? materials,
  }) {
    return Budget(
      total: total ?? this.total,
      materials: materials ?? this.materials,
    );
  }
}

class Material {
  const Material({
    required this.title,
    required this.catalogNumber,
    required this.description,
    required this.amount,
    required this.price,
  });

  factory Material.blank() {
    return const Material(
      title: 'New material',
      catalogNumber: '',
      description: '',
      amount: 1,
      price: 0,
    );
  }

  final String title;
  final String catalogNumber;
  final String description;
  final int amount;
  final double price;

  Material copyWith({
    String? title,
    String? catalogNumber,
    String? description,
    int? amount,
    double? price,
  }) {
    return Material(
      title: title ?? this.title,
      catalogNumber: catalogNumber ?? this.catalogNumber,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      price: price ?? this.price,
    );
  }
}

class TimePlan {
  const TimePlan({
    required this.totalDuration,
    required this.steps,
  });

  final Duration totalDuration;
  final List<Step> steps;

  TimePlan copyWith({
    Duration? totalDuration,
    List<Step>? steps,
  }) {
    return TimePlan(
      totalDuration: totalDuration ?? this.totalDuration,
      steps: steps ?? this.steps,
    );
  }
}

class Step {
  const Step({
    required this.number,
    required this.duration,
    required this.name,
    required this.description,
    this.milestone,
  });

  factory Step.blank({required int number}) {
    return Step(
      number: number,
      duration: const Duration(days: 1),
      name: 'New step',
      description: '',
    );
  }

  final int number;
  final Duration duration;
  final String name;
  final String description;
  final String? milestone;

  bool get isMilestone => milestone != null;

  Step copyWith({
    int? number,
    Duration? duration,
    String? name,
    String? description,
    String? milestone,
    bool clearMilestone = false,
  }) {
    return Step(
      number: number ?? this.number,
      duration: duration ?? this.duration,
      name: name ?? this.name,
      description: description ?? this.description,
      milestone: clearMilestone ? null : (milestone ?? this.milestone),
    );
  }
}
