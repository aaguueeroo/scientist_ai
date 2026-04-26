import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../controllers/scientist_controller.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_router.dart';
import '../../../core/app_routes.dart';
import '../../../core/theme/theme_context.dart';
import 'past_conversation_tile.dart';
import 'sidebar_nav_link.dart';

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

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final String location = GoRouterState.of(context).matchedLocation;
    final int currentBranch = navigationShell.currentIndex;
    final bool isHomeActive = _isAtConversationHome(currentBranch, location);
    final bool isReviewerActive = currentBranch == kBranchReviewer;
    return Container(
      decoration: BoxDecoration(
        color: context.scientist.sidebarBackground,
      ),
      child: Consumer<ScientistController>(
        builder: (
          BuildContext context,
          ScientistController controller,
          Widget? child,
        ) {
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
                  'Scientist AI',
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
                      label: 'New conversation',
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
                  'PAST CONVERSATIONS',
                  style: textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: kSpace8),
              Expanded(
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
            ],
          );
        },
      ),
    );
  }
}
