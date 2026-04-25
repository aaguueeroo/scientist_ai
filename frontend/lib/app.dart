import 'package:flutter/material.dart' hide Material, Step;
import 'package:provider/provider.dart';

import 'controllers/scientist_controller.dart';
import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'features/corrections/corrections_screen.dart';
import 'features/home/home_screen.dart';
import 'features/literature/literature_screen.dart';
import 'features/plan/plan_screen.dart';
import 'features/shell/app_shell.dart';
import 'services/scientist_api.dart';

class ScientistApp extends StatelessWidget {
  const ScientistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScientistController>(
      create: (_) => ScientistController(api: MockScientistApi()),
      child: MaterialApp(
        title: 'Scientist AI',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: kRouteHome,
        routes: <String, WidgetBuilder>{
          kRouteHome: (_) => const AppShell(child: HomeScreen()),
          kRouteLiterature: (_) => const AppShell(child: LiteratureScreen()),
          kRoutePlan: (_) => const AppShell(child: PlanScreen()),
          kRouteCorrections: (_) => const AppShell(child: CorrectionsScreen()),
        },
      ),
    );
  }
}
