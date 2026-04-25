import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/scientist_controller.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../core/theme/theme_context.dart';
import 'past_conversation_tile.dart';
import 'sidebar_nav_link.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final String? activeRoute = ModalRoute.of(context)?.settings.name;
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
                      isActive: activeRoute == kRouteHome,
                      onTap: () {
                        controller.reset();
                        if (activeRoute != kRouteHome) {
                          Navigator.pushReplacementNamed(context, kRouteHome);
                        }
                      },
                    ),
                    SidebarNavLink(
                      icon: Icons.rate_review_outlined,
                      label: 'Reviewer',
                      isActive: activeRoute == kRouteReviewer,
                      onTap: () {
                        if (activeRoute == kRouteReviewer) return;
                        Navigator.pushNamed(context, kRouteReviewer);
                      },
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
                    return PastConversationTile(
                      title: title,
                      isActive: controller.currentQuery == title,
                      onTap: () {
                        controller.openPastConversationReplay(title);
                        Navigator.pushNamed(
                          context,
                          kRoutePastConversation,
                        );
                      },
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
