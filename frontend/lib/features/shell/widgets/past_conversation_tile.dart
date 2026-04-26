import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/theme_context.dart';

class PastConversationTile extends StatefulWidget {
  const PastConversationTile({
    super.key,
    required this.title,
    this.isActive = false,
    this.onTap,
    this.onDelete,
  });

  final String title;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  State<PastConversationTile> createState() => _PastConversationTileState();
}

class _PastConversationTileState extends State<PastConversationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = context.appColorScheme;
    final bool isActive = widget.isActive;
    final Color background = isActive
        ? scheme.primaryContainer
        : (_isHovered ? scheme.surface : Colors.transparent);
    final Color textColor = isActive
        ? scheme.primary
        : scheme.onSurface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(kRadius - 2),
        ),
        padding: const EdgeInsets.only(
          left: kSpace12,
          right: kSpace4,
          top: kSpace8,
          bottom: kSpace8,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                onTap: widget.onTap ?? () {},
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (widget.onDelete != null)
              Tooltip(
                message: 'Remove from recent',
                child: IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: scheme.onSurfaceVariant,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
