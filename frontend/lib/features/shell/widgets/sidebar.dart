import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../controllers/projects_controller.dart';
import '../../../controllers/role_controller.dart';
import '../../../controllers/scientist_controller.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_router.dart';
import '../../../core/app_routes.dart';
import '../../../core/app_toasts.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/project.dart';
import '../../../models/user_role.dart';
import 'ongoing_project_tile.dart';
import 'past_conversation_tile.dart';
import 'sidebar_nav_link.dart';
import 'sidebar_user_menu.dart';

const String _kCurrentUserName = 'Jane Doe';
const String _kCurrentUserAvatarUrl = 'https://i.pravatar.cc/120?u=jane-doe';

/// Persistent sidebar shown alongside every screen.
///
/// Navigation is driven via the [StatefulNavigationShell] from go_router:
/// switching between top-level destinations uses [goBranch] so each branch
/// keeps its own stack, while opening a past conversation pushes a new
/// location inside the conversation branch.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  bool _isAtConversationHome(int currentBranch, String location) {
    return currentBranch == kBranchConversation && location == kRouteHome;
  }

  void _goToConversationHome(BuildContext context, ScientistController c) {
    c.reset();
    if (navigationShell.currentIndex == kBranchConversation) {
      context.go(kRouteHome);
      return;
    }
    navigationShell.goBranch(
      kBranchConversation,
      initialLocation: true,
    );
  }

  void _goToReviewer() {
    if (navigationShell.currentIndex == kBranchReviewer) {
      return;
    }
    navigationShell.goBranch(kBranchReviewer);
  }

  void _openPastConversation(
    BuildContext context,
    ScientistController controller,
    String title,
  ) {
    controller.openPastConversationReplay(title);
    if (navigationShell.currentIndex != kBranchConversation) {
      navigationShell.goBranch(kBranchConversation);
    }
    context.go(kRoutePastConversation);
  }

  void _openProject(BuildContext context, String projectId) {
    if (navigationShell.currentIndex != kBranchConversation) {
      navigationShell.goBranch(kBranchConversation);
    }
    context.go('$kRoutePlan?projectId=$projectId');
  }

  void _showSettingsPlaceholder(BuildContext context) {
    showAppToast(
      context,
      message: 'Settings are not available in this preview yet.',
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final String location = GoRouterState.of(context).matchedLocation;
    final String? activeProjectId =
        GoRouterState.of(context).uri.queryParameters['projectId'];
    final int currentBranch = navigationShell.currentIndex;
    final bool isHomeActive = _isAtConversationHome(currentBranch, location);
    final bool isReviewerActive = currentBranch == kBranchReviewer;
    return Container(
      decoration: BoxDecoration(
        color: context.scientist.sidebarBackground,
      ),
      child: Consumer3<ScientistController, RoleController, ProjectsController>(
        builder: (
          BuildContext context,
          ScientistController controller,
          RoleController roleController,
          ProjectsController projectsController,
          Widget? child,
        ) {
          final List<Project> projects = projectsController.projects;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSpace24,
                  kSpace24,
                  kSpace24,
                  kSpace16,
                ),
                child: Text(
                  'Marie Query',
                  style: textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpace8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SidebarNavLink(
                      icon: Icons.add_rounded,
                      label: 'New question',
                      isActive: isHomeActive,
                      onTap: () => _goToConversationHome(context, controller),
                    ),
                    SidebarNavLink(
                      icon: Icons.rate_review_outlined,
                      label: 'Reviewer',
                      isActive: isReviewerActive,
                      onTap: _goToReviewer,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSpace16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpace16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: scheme.outline.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(height: kSpace16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpace24),
                child: Text(
                  'RECENT QUESTIONS',
                  style: textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: kSpace8),
              Flexible(
                flex: 2,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpace8,
                    vertical: kSpace4,
                  ),
                  itemCount: controller.pastConversations.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String title = controller.pastConversations[index];
                    final bool isActiveTile =
                        currentBranch == kBranchConversation &&
                            location == kRoutePastConversation &&
                            controller.currentQuery == title;
                    return PastConversationTile(
                      title: title,
                      isActive: isActiveTile,
                      onTap: () => _openPastConversation(
                        context,
                        controller,
                        title,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: kSpace16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpace16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: scheme.outline.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(height: kSpace16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpace24),
                child: Text(
                  'ONGOING PROJECTS',
                  style: textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: kSpace8),
              Flexible(
                flex: 3,
                child: projects.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpace24,
                        ),
                        child: Text(
                          'No ongoing projects yet. Ask Marie to get started.',
                          style: context.scientist.bodyTertiary,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kSpace8,
                          vertical: kSpace4,
                        ),
                        itemCount: projects.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Project project = projects[index];
                          final bool isActive =
                              currentBranch == kBranchConversation &&
                                  location == kRoutePlan &&
                                  activeProjectId == project.id;
                          return OngoingProjectTile(
                            project: project,
                            role: roleController.role,
                            progress:
                                projectsController.progressFor(project),
                            isActive: isActive,
                            onTap: () => _openProject(context, project.id),
                          );
                        },
                      ),
              ),
              const SizedBox(height: kSpace8),
              SidebarUserMenu(
                userName: _kCurrentUserName,
                userAvatarUrl: _kCurrentUserAvatarUrl,
                role: roleController.role,
                onSelectRole: (UserRole next) {
                  roleController.setRole(next);
                },
                onOpenSettings: () => _showSettingsPlaceholder(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
