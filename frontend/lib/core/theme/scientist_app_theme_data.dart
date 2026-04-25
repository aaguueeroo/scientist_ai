import 'package:flutter/material.dart';

import '../app_colors.dart';
import 'app_text_theme.dart';

@immutable
class ScientistAppTheme extends ThemeExtension<ScientistAppTheme> {
  const ScientistAppTheme({
    required this.sidebarBackground,
    required this.skeleton,
    required this.onSurfaceFaint,
    required this.timelineConnector,
    required this.bodySecondary,
    required this.bodyTertiary,
    required this.bodyTertiaryMonospace,
    required this.numericBody,
  });

  final Color sidebarBackground;
  final Color skeleton;
  final Color onSurfaceFaint;
  final Color timelineConnector;
  final TextStyle bodySecondary;
  final TextStyle bodyTertiary;
  final TextStyle bodyTertiaryMonospace;
  final TextStyle numericBody;

  static ScientistAppTheme of(ColorScheme colorScheme, TextTheme textTheme) {
    return ScientistAppTheme(
      sidebarBackground: AppColors.sidebarSurface,
      skeleton: AppColors.skeleton,
      onSurfaceFaint: AppColors.textTertiary,
      timelineConnector: AppColors.textTertiary.withValues(alpha: 0.45),
      bodySecondary: kBodySecondaryStyle(colorScheme, textTheme),
      bodyTertiary: kBodyTertiaryStyle(textTheme, AppColors.textTertiary),
      bodyTertiaryMonospace: kBodyTertiaryStyle(
        textTheme,
        AppColors.textTertiary,
      ).copyWith(fontFamily: 'monospace'),
      numericBody: kNumericBodyStyle(textTheme),
    );
  }

  @override
  ScientistAppTheme copyWith({
    Color? sidebarBackground,
    Color? skeleton,
    Color? onSurfaceFaint,
    Color? timelineConnector,
    TextStyle? bodySecondary,
    TextStyle? bodyTertiary,
    TextStyle? bodyTertiaryMonospace,
    TextStyle? numericBody,
  }) {
    return ScientistAppTheme(
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      skeleton: skeleton ?? this.skeleton,
      onSurfaceFaint: onSurfaceFaint ?? this.onSurfaceFaint,
      timelineConnector: timelineConnector ?? this.timelineConnector,
      bodySecondary: bodySecondary ?? this.bodySecondary,
      bodyTertiary: bodyTertiary ?? this.bodyTertiary,
      bodyTertiaryMonospace:
          bodyTertiaryMonospace ?? this.bodyTertiaryMonospace,
      numericBody: numericBody ?? this.numericBody,
    );
  }

  @override
  ScientistAppTheme lerp(ThemeExtension<ScientistAppTheme>? other, double t) {
    if (other is! ScientistAppTheme) {
      return this;
    }
    return ScientistAppTheme(
      sidebarBackground:
          Color.lerp(sidebarBackground, other.sidebarBackground, t) ??
          sidebarBackground,
      skeleton: Color.lerp(skeleton, other.skeleton, t) ?? skeleton,
      onSurfaceFaint:
          Color.lerp(onSurfaceFaint, other.onSurfaceFaint, t) ??
          onSurfaceFaint,
      timelineConnector:
          Color.lerp(timelineConnector, other.timelineConnector, t) ??
          timelineConnector,
      bodySecondary: TextStyle.lerp(bodySecondary, other.bodySecondary, t) ??
          bodySecondary,
      bodyTertiary: TextStyle.lerp(bodyTertiary, other.bodyTertiary, t) ??
          bodyTertiary,
      bodyTertiaryMonospace: TextStyle.lerp(
            bodyTertiaryMonospace,
            other.bodyTertiaryMonospace,
            t,
          ) ??
          bodyTertiaryMonospace,
      numericBody: TextStyle.lerp(numericBody, other.numericBody, t) ??
          numericBody,
    );
  }
}
