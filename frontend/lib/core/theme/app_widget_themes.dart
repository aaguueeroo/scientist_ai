import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_constants.dart';
import 'app_color_scheme.dart';
import 'app_text_theme.dart';
import 'scientist_app_theme_data.dart';

ThemeData buildApplicationTheme() {
  final TextTheme textTheme = buildAppTextTheme();
  final ColorScheme colorScheme = buildAppColorScheme();
  final ScientistAppTheme scientist = ScientistAppTheme.of(colorScheme, textTheme);
  final WidgetStateProperty<Color?> accentOverlay = WidgetStateProperty
      .resolveWith<Color?>((Set<WidgetState> states) {
    if (states.contains(WidgetState.pressed)) {
      return AppColors.accentHover.withValues(alpha: 0.16);
    }
    if (states.contains(WidgetState.hovered)) {
      return AppColors.accentHover.withValues(alpha: 0.10);
    }
    if (states.contains(WidgetState.focused)) {
      return AppColors.accent.withValues(alpha: 0.12);
    }
    return null;
  });
  final WidgetStateProperty<Color?> filledButtonBackground = WidgetStateProperty
      .resolveWith<Color?>((Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return colorScheme.surface;
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.pressed)) {
      return AppColors.accentHover;
    }
    return colorScheme.primary;
  });
  final WidgetStateProperty<Color?> filledButtonForeground = WidgetStateProperty
      .resolveWith<Color?>((Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return scientist.onSurfaceFaint;
    }
    return colorScheme.onPrimary;
  });
  final WidgetStateProperty<Color?> outlineHover = WidgetStateProperty
      .resolveWith<Color?>((Set<WidgetState> states) {
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.pressed) ||
        states.contains(WidgetState.focused)) {
      return colorScheme.primaryContainer;
    }
    return null;
  });
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surfaceContainerHighest,
    canvasColor: colorScheme.surfaceContainerHighest,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.standard,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[scientist],
    iconTheme: IconThemeData(
      color: colorScheme.onSurfaceVariant,
      size: 20,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surface,
      showCheckmark: false,
      side: BorderSide.none,
      labelStyle: textTheme.bodyMedium,
      padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace4),
      labelPadding: const EdgeInsets.symmetric(horizontal: kSpace8, vertical: kSpace4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0x00000000),
      thickness: 0,
      space: 0,
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      hoverColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpace16,
        vertical: kSpace12,
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: scientist.onSurfaceFaint,
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.primary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: filledButtonBackground,
        foregroundColor: filledButtonForeground,
        overlayColor: WidgetStateProperty.all(
          colorScheme.onPrimary.withValues(alpha: 0.10),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace12),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        elevation: WidgetStateProperty.all(0),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        animationDuration: const Duration(milliseconds: 150),
        mouseCursor: WidgetStateProperty.resolveWith<MouseCursor>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return SystemMouseCursors.basic;
            }
            return SystemMouseCursors.click;
          },
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return scientist.onSurfaceFaint;
            }
            return colorScheme.onSurface;
          },
        ),
        backgroundColor: outlineHover,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        side: WidgetStateProperty.all(BorderSide.none),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace12),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        animationDuration: const Duration(milliseconds: 150),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return scientist.onSurfaceFaint;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return AppColors.accentHover;
            }
            return colorScheme.primary;
          },
        ),
        overlayColor: accentOverlay,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: kSpace12, vertical: kSpace8),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: colorScheme.onSurfaceVariant,
      collapsedIconColor: colorScheme.onSurfaceVariant,
      textColor: colorScheme.onSurface,
      collapsedTextColor: colorScheme.onSurface,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: kSpace16, vertical: kSpace4),
      childrenPadding: const EdgeInsets.fromLTRB(kSpace16, 0, kSpace16, kSpace16),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      textColor: colorScheme.onSurface,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surfaceContainerHighest,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
  );
}
