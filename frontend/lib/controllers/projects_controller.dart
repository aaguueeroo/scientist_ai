import 'package:flutter/foundation.dart';

import '../data/mock/mock_projects.dart';
import '../models/experiment_plan.dart';
import '../models/project.dart';

/// Owns the in-memory list of ongoing projects shown in the sidebar and
/// in the project plan view. Both roles read from the same store; only
/// lab scientists mutate it (toggle completion, attach materials).
class ProjectsController extends ChangeNotifier {
  ProjectsController({List<Project>? initialProjects})
      : _projects = List<Project>.from(initialProjects ?? buildMockProjects());

  final List<Project> _projects;

  List<Project> get projects => List<Project>.unmodifiable(_projects);

  Project? findById(String id) {
    for (final Project p in _projects) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }

  /// Fraction of completed steps over total steps, in `[0, 1]`.
  double progressFor(Project project) {
    final List<Step> steps = project.plan.timePlan.steps;
    if (steps.isEmpty) {
      return 0;
    }
    int completed = 0;
    for (final Step s in steps) {
      if (project.isStepCompleted(s.id)) {
        completed += 1;
      }
    }
    return completed / steps.length;
  }

  void toggleStepCompletion({
    required String projectId,
    required String stepId,
  }) {
    final Project? project = findById(projectId);
    if (project == null) {
      return;
    }
    final bool current = project.isStepCompleted(stepId);
    project.stepCompletion[stepId] = !current;
    notifyListeners();
  }

  void addAttachment({
    required String projectId,
    required String stepId,
    required ProjectAttachment attachment,
  }) {
    final Project? project = findById(projectId);
    if (project == null) {
      return;
    }
    final List<ProjectAttachment> list = project.stepAttachments.putIfAbsent(
      stepId,
      () => <ProjectAttachment>[],
    );
    list.add(attachment);
    notifyListeners();
  }

  void addProject(Project project) {
    _projects.insert(0, project);
    notifyListeners();
  }

  void removeAttachment({
    required String projectId,
    required String stepId,
    required String attachmentId,
  }) {
    final Project? project = findById(projectId);
    if (project == null) {
      return;
    }
    final List<ProjectAttachment>? list = project.stepAttachments[stepId];
    if (list == null) {
      return;
    }
    list.removeWhere((ProjectAttachment a) => a.id == attachmentId);
    if (list.isEmpty) {
      project.stepAttachments.remove(stepId);
    }
    notifyListeners();
  }
}
