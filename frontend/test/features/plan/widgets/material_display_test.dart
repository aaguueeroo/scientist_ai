import 'package:flutter_test/flutter_test.dart';
import 'package:scientist_ai/features/plan/widgets/material_display.dart';

void main() {
  group('formatMaterialQuantityString', () {
    test('omits placeholder unit each', () {
      expect(formatMaterialQuantityString(2, 'each'), '2');
    });

    test('omits each case-insensitively', () {
      expect(formatMaterialQuantityString(1, 'Each'), '1');
    });

    test('keeps real units', () {
      expect(formatMaterialQuantityString(2, 'g'), '2 g');
    });

    test('null qty is em dash', () {
      expect(formatMaterialQuantityString(null, 'g'), '—');
    });
  });

  group('displayMaterialNotes', () {
    test('drops unknown supplier prefix when name matches vendor', () {
      expect(
        displayMaterialNotes(
          "unknown supplier 'Goodfellow'",
          vendor: 'Goodfellow',
        ),
        isNull,
      );
    });

    test('shows only supplier name when different from vendor', () {
      expect(
        displayMaterialNotes(
          "unknown supplier 'United Nuclear Scientific'",
          vendor: 'Acme',
        ),
        'United Nuclear Scientific',
      );
    });

    test('leaves other notes unchanged', () {
      expect(
        displayMaterialNotes('Re-check stock before run'),
        'Re-check stock before run',
      );
    });
  });
}
