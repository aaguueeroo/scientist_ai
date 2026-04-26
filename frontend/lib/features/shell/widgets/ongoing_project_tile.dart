import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';
import '../../../models/project.dart';
import '../../../models/user_role.dart';
import 'user_avatar.dart';

/// Sidebar tile representing one ongoing project.
///
/// Variant is driven by the active [UserRole]:
///  - [UserRole.labScientist]: shows project title + a thin progress bar.
///  - [UserRole.funder]: shows project title with the assigned scientist's
///    avatar, the lab name and a percent label.
class OngoingProjectTile extends StatefulWidget {
  const OngoingProjectTile({
    super.key,
    required this.project,
    required this.role,
    required this.progress,
    required this.isActive,
    required this.onTap,
  });

  final Project project;
  final UserRole role;
  final double progress;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<OngoingProjectTile> createState() => _OngoingProjectTileState();
}

class _OngoingProjectTileState extends State<OngoingProjectTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isActive = widget.isActive;
    final Color background = isActive
        ? scheme.primaryContainer
        : (_isHovered ? scheme.surface : Colors.transparent);
    final Color textColor = isActive ? scheme.primary : scheme.onSurface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(kRadius - 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace12,
            vertical: kSpace8,
          ),
          child: widget.role == UserRole.labScientist
              ? _buildLabBody(textTheme, scheme, textColor, isActive)
              : _buildFunderBody(textTheme, scheme, textColor, isActive),
        ),
      ),
    );
  }

  Widget _buildLabBody(
    TextTheme textTheme,
    ColorScheme scheme,
    Color textColor,
    bool isActive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          widget.project.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: kSpace8),
        Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: widget.progress.clamp(0, 1).toDouble(),
                  minHeight: 4,
                  backgroundColor: scheme.outline.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
            ),
            const SizedBox(width: kSpace8),
            Text(
              _formatPercent(widget.progress),
              style: context.scientist.numericBody.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFunderBody(
    TextTheme textTheme,
    ColorScheme scheme,
    Color textColor,
    bool isActive,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        UserAvatar(
          name: widget.project.assignedScientistName,
          imageUrl: widget.project.assignedScientistAvatarUrl,
          size: 28,
        ),
        const SizedBox(width: kSpace12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.project.labName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.scientist.bodyTertiary,
              ),
            ],
          ),
        ),
        const SizedBox(width: kSpace8),
        Text(
          _formatPercent(widget.progress),
          style: context.scientist.numericBody.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatPercent(double v) {
    final int pct = (v.clamp(0, 1) * 100).round();
    return '$pct%';
  }
}
