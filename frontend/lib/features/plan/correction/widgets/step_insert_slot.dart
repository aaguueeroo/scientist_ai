import 'dart:ui' show PointMode;

import 'package:flutter/material.dart' hide Material, Step;

import '../../../../core/app_constants.dart';

const double _kInsertSlotHeight = kSpace12;
const double _kInsertChipDiameter = 22;
const double _kInsertChipIconSize = 14;
const double _kDottedLineStrokeWidth = 1.2;
const double _kDottedLineDotSpacing = 5;

class StepInsertSlot extends StatefulWidget {
  const StepInsertSlot({super.key, required this.onInsert});

  final VoidCallback onInsert;

  @override
  State<StepInsertSlot> createState() => _StepInsertSlotState();
}

class _StepInsertSlotState extends State<StepInsertSlot> {
  bool _isHovered = false;

  void _setHovered(bool value) {
    if (_isHovered == value) {
      return;
    }
    setState(() => _isHovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onInsert,
        child: SizedBox(
          width: double.infinity,
          height: _kInsertSlotHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  opacity: _isHovered ? 1 : 0,
                  child: CustomPaint(
                    painter: _DottedLinePainter(
                      color: scheme.primary.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                opacity: _isHovered ? 1 : 0,
                child: Container(
                  width: _kInsertChipDiameter,
                  height: _kInsertChipDiameter,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    size: _kInsertChipIconSize,
                    color: scheme.onPrimary,
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

class _DottedLinePainter extends CustomPainter {
  _DottedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = _kDottedLineStrokeWidth
      ..strokeCap = StrokeCap.round;
    final double y = size.height / 2;
    double x = _kDottedLineStrokeWidth / 2;
    while (x < size.width) {
      canvas.drawPoints(
        PointMode.points,
        <Offset>[Offset(x, y)],
        paint,
      );
      x += _kDottedLineDotSpacing;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
