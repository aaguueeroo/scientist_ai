import 'package:flutter/material.dart';

import '../../../../core/app_constants.dart';
import '../../../../core/theme/theme_context.dart';

const Duration _kHoverFadeDuration = Duration(milliseconds: 150);
const double _kStepperButtonSize = 26;
const double _kStepperIconSize = 16;

class HoverStepper extends StatefulWidget {
  const HoverStepper({
    super.key,
    required this.child,
    required this.onIncrement,
    required this.onDecrement,
    this.tooltipIncrement,
    this.tooltipDecrement,
  });

  final Widget child;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final String? tooltipIncrement;
  final String? tooltipDecrement;

  @override
  State<HoverStepper> createState() => _HoverStepperState();
}

class _HoverStepperState extends State<HoverStepper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          widget.child,
          const SizedBox(width: kSpace8),
          AnimatedOpacity(
            duration: _kHoverFadeDuration,
            opacity: _isHovered ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_isHovered,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _StepperButton(
                    icon: Icons.remove,
                    tooltip: widget.tooltipDecrement,
                    onPressed: widget.onDecrement,
                  ),
                  const SizedBox(width: kSpace4),
                  _StepperButton(
                    icon: Icons.add,
                    tooltip: widget.tooltipIncrement,
                    onPressed: widget.onIncrement,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatefulWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.appColorScheme;
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: _kHoverFadeDuration,
          width: _kStepperButtonSize,
          height: _kStepperButtonSize,
          decoration: BoxDecoration(
            color:
                _isHovered ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(kRadius - 2),
          ),
          child: Icon(
            widget.icon,
            size: _kStepperIconSize,
            color: _isHovered ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
    if (widget.tooltip == null) {
      return button;
    }
    return Tooltip(
      message: widget.tooltip!,
      waitDuration: const Duration(milliseconds: 400),
      child: button,
    );
  }
}
