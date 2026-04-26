// Presentation helpers for experiment plan [Material] values on the plan UI.

/// Renders [qty] + [qtyUnit] so bare counts do not get a fake unit like "each".
String formatMaterialQuantityString(int? qty, String? qtyUnit) {
  if (qty == null) {
    return '—';
  }
  final String u = (qtyUnit ?? '').trim().toLowerCase();
  if (u.isEmpty || u == 'each' || u == 'ea' || u == 'ct' || u == 'count') {
    return '$qty';
  }
  return '$qty $qtyUnit';
}

/// Normalizes material notes: strips leading "unknown supplier 'X'".
/// When [vendor] already equals X, returns null or any remaining text.
/// When the only content is that phrase, returns just X.
String? displayMaterialNotes(String? rawNotes, {String? vendor}) {
  final String? t = rawNotes?.trim();
  if (t == null || t.isEmpty) return null;

  final RegExp singleQuoted = RegExp(
    r"^unknown supplier\s*'([^']*)'(.*)$",
    caseSensitive: false,
  );
  final RegExp doubleQuoted = RegExp(
    r'^unknown supplier\s*"([^"]*)"(.*)$',
    caseSensitive: false,
  );
  Match? m = singleQuoted.firstMatch(t) ?? doubleQuoted.firstMatch(t);
  if (m == null) return t;
  final String name = m.group(1)!.trim();
  if (name.isEmpty) return t;
  final String rest = (m.group(2) ?? '').trim();
  final String? v = vendor?.trim();
  if (v != null && v.toLowerCase() == name.toLowerCase()) {
    return rest.isEmpty ? null : rest;
  }
  if (rest.isEmpty) return name;
  return '$name $rest';
}
