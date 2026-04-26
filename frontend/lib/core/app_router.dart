import 'package:flutter/material.dart' hide Material, Step;
import 'package:go_router/go_router.dart';

import '../controllers/user_api_keys_store.dart';
import '../features/conversation/past_conversation_screen.dart';
import '../features/home/home_screen.dart';
import '../features/literature/literature_screen.dart';
import '../features/prompt/workspace_prompt_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/review/reviewer_screen.dart';
import '../features/settings/user_api_keys_screen.dart';
import '../features/shell/app_shell.dart';
import 'app_routes.dart';
import 'user_api_keys_navigation.dart';

/// Root [NavigatorState] for native desktop menus and imperative navigation.
final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({
  required UserApiKeysStore userApiKeysStore,
}) {
  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: kRouteHome,
    refreshListenable: userApiKeysStore,
    redirect: (BuildContext context, GoRouterState state) {
      return redirectForUserApiKeysGate(
        hasAllProviderKeysReady: userApiKeysStore.hasAllProviderKeysReady,
        matchedLocation: state.matchedLocation,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: kRouteOpenAiApiKeys,
        builder: (BuildContext context, GoRouterState state) {
          return const UserApiKeysScreen();
        },
      ),
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
                path: kRoutePrompt,
                name: 'prompt',
                pageBuilder: (BuildContext context, GoRouterState state) {
                  return const NoTransitionPage<void>(
                    child: WorkspacePromptScreen(),
                  );
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
}

/// Branch indices for [StatefulNavigationShell.goBranch].
const int kBranchConversation = 0;
const int kBranchReviewer = 1;
