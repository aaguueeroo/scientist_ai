import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import 'controllers/review_store_controller.dart';
import 'controllers/scientist_controller.dart';
import 'core/app_router.dart';
import 'core/app_theme.dart';
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
          create: (_) => MockScientistBackendClient(),
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
      ],
      child: MaterialApp.router(
        title: 'Scientist AI',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: appRouter,
      ),
    );
  }
}
