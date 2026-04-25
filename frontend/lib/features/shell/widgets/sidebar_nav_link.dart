import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';

/// A flat navigation row used at the top of the sidebar (e.g. "New
/// conversation", "Reviewer"). Mirrors the visual language of
/// [PastConversationTile] for hover/active states so the whole sidebar
/// reads as a single navigation list.
class SidebarNavLink extends StatefulWidget {
  const SidebarNavLink({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  State<SidebarNavLink> createState() => _SidebarNavLinkState();
}

class _SidebarNavLinkState extends State<SidebarNavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final bool isActive = widget.isActive;
    final Color background = isActive
        ? scheme.primaryContainer
        : (_isHovered ? scheme.surface : Colors.transparent);
    final Color foreground = isActive ? scheme.primary : scheme.onSurface;
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
          child: Row(
            children: <Widget>[
              Icon(widget.icon, size: 16, color: foreground),
              const SizedBox(width: kSpace12),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
