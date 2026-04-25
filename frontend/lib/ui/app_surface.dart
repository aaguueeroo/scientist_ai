import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../core/theme/theme_context.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(kSpace16),
    this.color,
    this.borderColor,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(kRadius);
    final BoxDecoration decoration = BoxDecoration(
      color: color ?? scheme.surface,
      borderRadius: radius,
      border: borderColor == null
          ? null
          : Border.all(color: borderColor!),
    );
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: radius,
          hoverColor: scheme.primaryContainer,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
