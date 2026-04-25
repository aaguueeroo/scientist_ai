class ExperimentPlan {
  const ExperimentPlan({
    required this.budget,
    required this.timePlan,
  });

  final Budget budget;
  final TimePlan timePlan;
}

class Budget {
  const Budget({
    required this.total,
    required this.materials,
  });

  final double total;
  final List<Material> materials;
}

class Material {
  const Material({
    required this.title,
    required this.catalogNumber,
    required this.description,
    required this.amount,
    required this.price,
  });

  final String title;
  final String catalogNumber;
  final String description;
  final int amount;
  final double price;
}

class TimePlan {
  const TimePlan({
    required this.totalDuration,
    required this.steps,
  });

  final Duration totalDuration;
  final List<Step> steps;
}

class Step {
  const Step({
    required this.number,
    required this.duration,
    required this.name,
    required this.description,
  });

  final int number;
  final Duration duration;
  final String name;
  final String description;
}
