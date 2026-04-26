import 'package:flutter/material.dart' hide Material, Step;
import 'package:go_router/go_router.dart';

import '../features/conversation/past_conversation_screen.dart';
import '../features/home/home_screen.dart';
import '../features/literature/literature_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/review/reviewer_screen.dart';
import '../features/shell/app_shell.dart';
import 'app_routes.dart';

/// Top-level router for Scientist AI.
///
/// Uses [StatefulShellRoute.indexedStack] so the app has two independent
/// navigation branches – the conversation workspace and the reviewer – with
/// the [AppShell] (sidebar + body outlet) persisting across navigation.
/// Each branch keeps its own navigation stack, so switching between them
/// preserves where the user was inside that branch.
final GoRouter appRouter = GoRouter(
  initialLocation: kRouteHome,
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell navigationShell,
      ) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: kRouteHome,
              name: 'home',
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(child: HomeScreen());
              },
            ),
            GoRoute(
              path: kRouteLiterature,
              name: 'literature',
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(child: LiteratureScreen());
              },
            ),
            GoRoute(
              path: kRoutePlan,
              name: 'plan',
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(child: PlanScreen());
              },
            ),
            GoRoute(
              path: kRoutePastConversation,
              name: 'past-conversation',
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(
                  child: PastConversationScreen(),
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: kRouteReviewer,
              name: 'reviewer',
              pageBuilder: (BuildContext context, GoRouterState state) {
                return const NoTransitionPage<void>(child: ReviewerScreen());
              },
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Branch indices for [StatefulNavigationShell.goBranch].
const int kBranchConversation = 0;
const int kBranchReviewer = 1;
