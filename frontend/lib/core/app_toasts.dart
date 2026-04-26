import 'package:flutter/material.dart';
import 'package:scientist_ai/core/app_colors.dart';
import 'package:scientist_ai/core/app_constants.dart';
import 'package:scientist_ai/core/theme/theme_context.dart';
import 'package:toastification/toastification.dart';

/// Semantic variant for in-app toasts (aligned with [ColorScheme] and app chrome).
enum AppToastVariant { info, success, error }

void showAppToast(
  BuildContext context, {
  required String message,
  AppToastVariant variant = AppToastVariant.info,
  Duration autoCloseDuration = const Duration(seconds: 3),
}) {
  if (!context.mounted) {
    return;
  }
  // Capture the route theme: overlay toasts are not always under the same
  // [Material] subtree, so the widget below is wrapped in this [Theme] explicitly.
  final ThemeData appTheme = Theme.of(context);
  final ColorScheme scheme = context.appColorScheme;
  final (IconData icon, Color iconColor) = switch (variant) {
    AppToastVariant.info => (Icons.info_outlined, AppColors.accent),
    AppToastVariant.success => (
        Icons.check_circle_outline_rounded,
        AppColors.feedbackPositive
      ),
    AppToastVariant.error => (Icons.error_outline_rounded, scheme.error),
  };
  toastification.showCustom(
    context: context,
    autoCloseDuration: autoCloseDuration,
    animationDuration: const Duration(milliseconds: 400),
    builder: (BuildContext _, ToastificationItem item) {
      return Theme(
        data: appTheme,
        child: _AppToastContent(
          message: message,
          icon: icon,
          iconColor: iconColor,
          surfaceColor: scheme.surface,
          item: item,
        ),
      );
    },
  );
}

class _AppToastContent extends StatelessWidget {
  const _AppToastContent({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.surfaceColor,
    required this.item,
  });

  final String message;
  final IconData icon;
  final Color iconColor;
  final Color surfaceColor;
  final ToastificationItem item;

  @override
  Widget build(BuildContext context) {
    final bool hasTimer = item.hasTimer;
    final TextTheme textTheme = Theme.of(context).textTheme;
    // Matches primary copy at 14px (e.g. [ActionChip] labels, form-adjacent text).
    final TextStyle textStyle = textTheme.bodyMedium!;
    final BorderRadius borderRadius = BorderRadius.circular(kRadius);
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kSpace16,
          vertical: kSpace12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: kSpace12),
            Expanded(
              child: Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
          ],
        ),
      ),
    );
    if (hasTimer) {
      surface = MouseRegion(
        onEnter: (_) => item.pause(),
        onExit: (_) => item.start(),
        child: surface,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpace4),
      child: Dismissible(
        key: ValueKey<String>(item.id),
        direction: DismissDirection.horizontal,
        onDismissed: (_) {
          toastification.dismiss(
            item,
            showRemoveAnimation: false,
          );
        },
        child: surface,
      ),
    );
  }
}
