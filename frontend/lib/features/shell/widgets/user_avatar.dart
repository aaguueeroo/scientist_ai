import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';

/// Circular avatar that loads a network image and falls back to the user's
/// initials whenever the network fetch fails or the URL is empty.
///
/// Designed to never block the UI: load errors are caught and produce the
/// initials fallback instead of bubbling up.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    this.size = 32,
  });

  final String name;
  final String imageUrl;
  final double size;

  String _initialsFor(String fullName) {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.characters.take(1).toString().toUpperCase();
    }
    final String first = parts.first.characters.take(1).toString();
    final String last = parts.last.characters.take(1).toString();
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Widget fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initialsFor(name),
        style: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (imageUrl.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            debugPrint('UserAvatar load failed for $imageUrl: $error');
            return fallback;
          },
          loadingBuilder: (
            BuildContext context,
            Widget child,
            ImageChunkEvent? progress,
          ) {
            if (progress == null) {
              return child;
            }
            return Container(
              color: scheme.surface,
              alignment: Alignment.center,
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: scheme.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
