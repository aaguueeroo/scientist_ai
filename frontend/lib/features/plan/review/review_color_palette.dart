import 'dart:math';

import 'package:flutter/material.dart';

/// Curated palette tuned to read on the project's dark surface
/// (`AppColors.surface == 0xFF222628`). Values use HSL with
/// `s ~ 0.55` and `l ~ 0.68` so they stay vivid without competing
/// with the muted accent.
const List<Color> _kBatchPalette = <Color>[
  Color(0xFFE6B56B), // amber
  Color(0xFFE6789F), // rose
  Color(0xFF6FCBE6), // cyan
  Color(0xFFB7D86A), // lime
  Color(0xFFB58CE6), // violet
  Color(0xFFE68A78), // coral
  Color(0xFF7FD4C2), // teal
  Color(0xFFE6C28A), // peach
];

/// A single shared comment marker color, distinct from the batch
/// palette so commented spans never look like a suggestion.
const Color kCommentMarkerColor = Color(0xFFD0BCFF);

/// Picks a stable color for the [index]-th batch in the current session.
/// A random session offset keeps successive runs from always opening with
/// the same hue without compromising determinism within a session.
class BatchColorPalette {
  BatchColorPalette({int? sessionSeed})
      : _offset = (sessionSeed ?? Random().nextInt(_kBatchPalette.length));

  final int _offset;

  Color colorAt(int index) {
    final int len = _kBatchPalette.length;
    final int wrapped = ((index + _offset) % len + len) % len;
    final Color base = _kBatchPalette[wrapped];
    if (index < len) {
      return base;
    }
    return _rotateHue(base, ((index ~/ len) * 31).toDouble());
  }

  Color _rotateHue(Color base, double degrees) {
    final HSLColor hsl = HSLColor.fromColor(base);
    final double nextHue = (hsl.hue + degrees) % 360;
    return hsl.withHue(nextHue).toColor();
  }
}
