import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';
import '../models/feedback_polarity.dart';

/// Twin like / dislike toggle. Tapping the active polarity clears it,
/// tapping the other polarity switches to it. Designed to slot into
/// either the section feedback bar or the hero hover overlay.
class FeedbackButtons extends StatelessWidget {
  const FeedbackButtons({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final FeedbackPolarity? value;
  final ValueChanged<FeedbackPolarity> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 28 : 32;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PolarityButton(
          icon: Icons.thumb_up_outlined,
          activeIcon: Icons.thumb_up_rounded,
          isActive: value == FeedbackPolarity.like,
          tooltip: 'Looks good',
          buttonSize: size,
          onPressed: () => onChanged(FeedbackPolarity.like),
        ),
        const SizedBox(width: kSpace4),
        _PolarityButton(
          icon: Icons.thumb_down_outlined,
          activeIcon: Icons.thumb_down_rounded,
          isActive: value == FeedbackPolarity.dislike,
          tooltip: 'Needs work',
          buttonSize: size,
          onPressed: () => onChanged(FeedbackPolarity.dislike),
        ),
      ],
    );
  }
}

class _PolarityButton extends StatefulWidget {
  const _PolarityButton({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.tooltip,
    required this.buttonSize,
    required this.onPressed,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final String tooltip;
  final double buttonSize;
  final VoidCallback onPressed;

  @override
  State<_PolarityButton> createState() => _PolarityButtonState();
}

class _PolarityButtonState extends State<_PolarityButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final Color baseFg = widget.isActive
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final Color hoverFg = widget.isActive ? scheme.primary : scheme.onSurface;
    final Color background = widget.isActive
        ? scheme.primaryContainer
        : (_isHovered ? scheme.primaryContainer.withValues(alpha: 0.6) : Colors.transparent);
    final double scale = _isPressed ? 0.92 : (_isHovered ? 1.04 : 1.0);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() {
          _isHovered = false;
          _isPressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.buttonSize,
              height: widget.buttonSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(kRadius - 2),
              ),
              child: Icon(
                widget.isActive ? widget.activeIcon : widget.icon,
                size: 16,
                color: _isHovered ? hoverFg : baseFg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
