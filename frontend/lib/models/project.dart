import '../core/id_generator.dart';
import 'experiment_plan.dart';

/// A single in-flight research project. Bundles the experiment plan with
/// per-step completion + uploaded materials and the lab/scientist that is
/// executing it. UI-only, kept in memory.
class Project {
  Project({
    required this.id,
    required this.title,
    required this.assignedScientistName,
    required this.assignedScientistAvatarUrl,
    required this.labName,
    required this.startedAt,
    required this.lastUpdatedAt,
    required this.plan,
    Map<String, bool>? stepCompletion,
    Map<String, List<ProjectAttachment>>? stepAttachments,
  })  : stepCompletion = <String, bool>{...?stepCompletion},
        stepAttachments = <String, List<ProjectAttachment>>{
          for (final MapEntry<String, List<ProjectAttachment>> e
              in (stepAttachments ?? <String, List<ProjectAttachment>>{}).entries)
            e.key: List<ProjectAttachment>.from(e.value),
        };

  final String id;
  final String title;
  final String assignedScientistName;
  final String assignedScientistAvatarUrl;
  final String labName;
  final DateTime startedAt;
  final DateTime lastUpdatedAt;
  final ExperimentPlan plan;
  final Map<String, bool> stepCompletion;
  final Map<String, List<ProjectAttachment>> stepAttachments;

  bool isStepCompleted(String stepId) {
    return stepCompletion[stepId] ?? false;
  }

  List<ProjectAttachment> attachmentsFor(String stepId) {
    return stepAttachments[stepId] ?? const <ProjectAttachment>[];
  }
}

/// A locally tracked file attachment a lab scientist has submitted against
/// a step. We never upload the bytes; we only remember enough to render
/// it in a list (and let the funder "download" via a snackbar).
class ProjectAttachment {
  ProjectAttachment({
    String? id,
    required this.fileName,
    required this.sizeBytes,
    required this.addedAt,
  }) : id = id ?? generateLocalId('att');

  final String id;
  final String fileName;
  final int sizeBytes;
  final DateTime addedAt;
}
