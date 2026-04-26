import 'dart:math';

const int _kIdRandomBits = 1 << 32;

int _counter = 0;
final Random _random = Random();

/// Generates a short, locally-unique id with an optional prefix.
///
/// Format: `<prefix>_<base36 timestamp>_<base36 counter>_<base36 random>`.
/// Suitable for tagging UI-only entities (steps, materials, comments, batches)
/// that never need to round-trip to the backend.
String generateLocalId(String prefix) {
  _counter += 1;
  final int timestamp = DateTime.now().microsecondsSinceEpoch;
  final int random = _random.nextInt(_kIdRandomBits);
  return '${prefix}_${timestamp.toRadixString(36)}_'
      '${_counter.toRadixString(36)}_${random.toRadixString(36)}';
}
