import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import '../../../controllers/projects_controller.dart';
import '../../../controllers/role_controller.dart';
import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/project.dart';
import '../../../ui/app_surface.dart';
import 'project_plan_view.dart';

/// Hosts the role-aware project plan body. Resolves the requested
/// project from [ProjectsController] and renders a graceful "not found"
/// surface when the id is unknown (per the global error policy: keep
/// the UI responsive).
class ProjectPlanScreen extends StatelessWidget {
  const ProjectPlanScreen({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpace40,
        kSpace32,
        kSpace40,
        kSpace40,
      ),
      child: Consumer2<ProjectsController, RoleController>(
        builder: (
          BuildContext context,
          ProjectsController projects,
          RoleController role,
          Widget? child,
        ) {
          final Project? project = projects.findById(projectId);
          if (project == null) {
            return const _ProjectNotFound();
          }
          return ProjectPlanView(
            project: project,
            role: role.role,
          );
        },
      ),
    );
  }
}

class _ProjectNotFound extends StatelessWidget {
  const _ProjectNotFound();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppSurface(
          padding: const EdgeInsets.all(kSpace24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.folder_off_outlined,
                color: scheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: kSpace12),
              Text(
                'Project not found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: kSpace8),
              Text(
                'This project is no longer available. Pick another one '
                'from the sidebar to continue.',
                style: context.scientist.bodySecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
