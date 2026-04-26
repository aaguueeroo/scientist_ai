import 'package:flutter/material.dart' hide Material, Step;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:toastification/toastification.dart';

import 'controllers/marie_shell_peek_controller.dart';
import 'controllers/user_api_keys_store.dart';
import 'controllers/projects_controller.dart';
import 'controllers/review_store_controller.dart';
import 'controllers/role_controller.dart';
import 'controllers/scientist_controller.dart';
import 'core/api_config.dart';
import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'core/desktop_platform.dart';
import 'features/settings/user_api_keys_manage_panel.dart';
import 'features/settings/user_api_keys_setup_host.dart';
import 'data/clients/http_scientist_backend_client.dart';
import 'data/clients/mock_scientist_backend_client.dart';
import 'data/clients/scientist_backend_client.dart';
import 'repositories/scientist_repository.dart';
import 'repositories/scientist_repository_impl.dart';

class ScientistApp extends StatefulWidget {
  const ScientistApp({
    super.key,
    required this.userApiKeysStore,
  });

  final UserApiKeysStore userApiKeysStore;

  @override
  State<ScientistApp> createState() => _ScientistAppState();
}

class _ScientistAppState extends State<ScientistApp> {
  late final GoRouter _router = createAppRouter(
    userApiKeysStore: widget.userApiKeysStore,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<UserApiKeysStore>.value(
          value: widget.userApiKeysStore,
        ),
        Provider<ScientistBackendClient>(
          create: (BuildContext c) {
            if (!kUseRealScientistApi) {
              return MockScientistBackendClient();
            }
            final UserApiKeysStore store = c.read<UserApiKeysStore>();
            return HttpScientistBackendClient(
              baseUrl: Uri.parse(kScientistApiBaseUrl.trim()),
              openAiApiKeyProvider: () => store.activeOpenAiSecretForHttpHeader,
              tavilyApiKeyProvider: () => store.activeTavilySecretForHttpHeader,
            );
          },
        ),
        Provider<ScientistRepository>(
          create: (BuildContext c) =>
              ScientistRepositoryImpl(client: c.read<ScientistBackendClient>()),
        ),
        ChangeNotifierProvider<ScientistController>(
          create: (BuildContext c) =>
              ScientistController(repository: c.read<ScientistRepository>()),
        ),
        ChangeNotifierProvider<MarieShellPeekController>(
          create: (_) => MarieShellPeekController(),
        ),
        ChangeNotifierProvider<ReviewStoreController>(
          create: (BuildContext c) => ReviewStoreController(
            repository: c.read<ScientistRepository>(),
          )..loadReviews(),
        ),
        ChangeNotifierProvider<RoleController>(
          create: (BuildContext c) => RoleController(),
        ),
        ChangeNotifierProvider<ProjectsController>(
          create: (BuildContext c) => ProjectsController(),
        ),
      ],
      child: ToastificationWrapper(
        config: const ToastificationConfig(
          itemWidth: 400,
          animationDuration: Duration(milliseconds: 400),
        ),
        child: MaterialApp.router(
          title: 'Marie Query',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          themeMode: ThemeMode.dark,
          routerConfig: _router,
          builder: (BuildContext context, Widget? child) {
            if (kUseRealScientistApi) {
              widget.userApiKeysStore.bindRepository(
                context.read<ScientistRepository>(),
              );
            }
            Widget body = UserApiKeysSetupHost(
              child: child ?? const SizedBox.shrink(),
            );
            if (kSupportsDesktopNativeAppMenu) {
              body = PlatformMenuBar(
                menus: <PlatformMenu>[
                  PlatformMenu(
                    label: 'Marie Query',
                    menus: <PlatformMenuItem>[
                      PlatformMenuItem(
                        label: 'API Keys…',
                        onSelected: () {
                          final BuildContext? nav =
                              appRootNavigatorKey.currentContext;
                          if (nav != null && nav.mounted) {
                            showManageUserApiKeysDialog(nav);
                          }
                        },
                      ),
                    ],
                  ),
                ],
                child: body,
              );
            }
            return body;
          },
        ),
      ),
    );
  }
}
