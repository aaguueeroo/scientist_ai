import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

import 'controllers/projects_controller.dart';
import 'controllers/review_store_controller.dart';
import 'controllers/role_controller.dart';
import 'controllers/scientist_controller.dart';
import 'core/api_config.dart';
import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'data/clients/http_scientist_backend_client.dart';
import 'data/clients/mock_scientist_backend_client.dart';
import 'data/clients/scientist_backend_client.dart';
import 'repositories/scientist_repository.dart';
import 'repositories/scientist_repository_impl.dart';

class ScientistApp extends StatelessWidget {
  const ScientistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ScientistBackendClient>(
          create: (_) => kUseRealScientistApi
              ? HttpScientistBackendClient(
                  baseUrl: Uri.parse(kScientistApiBaseUrl.trim()),
                )
              : MockScientistBackendClient(),
        ),
        Provider<ScientistRepository>(
          create: (BuildContext c) =>
              ScientistRepositoryImpl(client: c.read<ScientistBackendClient>()),
        ),
        ChangeNotifierProvider<ScientistController>(
          create: (BuildContext c) =>
              ScientistController(repository: c.read<ScientistRepository>()),
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
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
