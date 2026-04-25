import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/features/plan/review/review_color_palette.dart';

void main() {
  group('BatchColorPalette', () {
    test('produces stable colors across calls when seed is fixed', () {
      final BatchColorPalette inputPaletteA =
          BatchColorPalette(sessionSeed: 0);
      final BatchColorPalette inputPaletteB =
          BatchColorPalette(sessionSeed: 0);

      for (int i = 0; i < 8; i++) {
        expect(inputPaletteA.colorAt(i), inputPaletteB.colorAt(i));
      }
    });

    test('returns 8 distinct hues for the first batch indices', () {
      final BatchColorPalette inputPalette =
          BatchColorPalette(sessionSeed: 0);
      final Set<Color> actualColors = <Color>{
        for (int i = 0; i < 8; i++) inputPalette.colorAt(i),
      };
      expect(actualColors.length, 8);
    });

    test('different seeds rotate the starting hue', () {
      final BatchColorPalette inputPaletteA =
          BatchColorPalette(sessionSeed: 0);
      final BatchColorPalette inputPaletteB =
          BatchColorPalette(sessionSeed: 3);

      expect(inputPaletteA.colorAt(0), isNot(inputPaletteB.colorAt(0)));
      expect(inputPaletteA.colorAt(0), inputPaletteB.colorAt(8 - 3));
    });

    test('falls back to hue rotation past the curated palette length', () {
      final BatchColorPalette inputPalette =
          BatchColorPalette(sessionSeed: 0);
      final Color actualBaseColor = inputPalette.colorAt(0);
      final Color actualRotatedColor = inputPalette.colorAt(8);
      expect(actualRotatedColor, isNot(actualBaseColor));
    });
  });
}
