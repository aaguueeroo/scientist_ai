import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import 'controllers/scientist_controller.dart';
import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'data/clients/mock_scientist_backend_client.dart';
import 'data/clients/scientist_backend_client.dart';
import 'features/conversation/past_conversation_screen.dart';
import 'features/corrections/corrections_screen.dart';
import 'features/home/home_screen.dart';
import 'features/literature/literature_screen.dart';
import 'features/plan/plan_screen.dart';
import 'features/shell/app_shell.dart';
import 'repositories/scientist_repository.dart';
import 'repositories/scientist_repository_impl.dart';

class ScientistApp extends StatelessWidget {
  const ScientistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ScientistBackendClient>(
          create: (_) => const MockScientistBackendClient(),
        ),
        Provider<ScientistRepository>(
          create: (BuildContext c) =>
              ScientistRepositoryImpl(client: c.read<ScientistBackendClient>()),
        ),
        ChangeNotifierProvider<ScientistController>(
          create: (BuildContext c) =>
              ScientistController(repository: c.read<ScientistRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'Scientist AI',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        initialRoute: kRouteHome,
        routes: <String, WidgetBuilder>{
          kRouteHome: (_) => const AppShell(child: HomeScreen()),
          kRouteLiterature: (_) => const AppShell(child: LiteratureScreen()),
          kRoutePlan: (_) => const AppShell(child: PlanScreen()),
          kRouteCorrections: (_) => const AppShell(child: CorrectionsScreen()),
          kRoutePastConversation: (_) =>
              const AppShell(child: PastConversationScreen()),
        },
      ),
    );
  }
}
