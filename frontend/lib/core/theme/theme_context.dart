import 'package:flutter/material.dart';

import 'scientist_app_theme_data.dart';

extension ScientistTheme on BuildContext {
  ScientistAppTheme get scientist => Theme.of(this).extension<ScientistAppTheme>()!;

  ColorScheme get appColorScheme => Theme.of(this).colorScheme;
}
