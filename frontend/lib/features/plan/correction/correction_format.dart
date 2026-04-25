import 'package:flutter/foundation.dart';

import '../../../core/app_constants.dart';

Duration computeTimeIncrement(Duration current) {
  if (current.inDays >= 1) {
    return const Duration(days: 1);
  }
  return const Duration(hours: 1);
}

double computeBudgetIncrement(double current) {
  if (current < kBudgetIncrementThreshold) {
    return kBudgetIncrementLow;
  }
  return kBudgetIncrementHigh;
}

String formatDurationLabel(Duration value) {
  final int days = value.inDays;
  final int hours = value.inHours.remainder(24);
  if (days > 0 && hours == 0) {
    return '$days d';
  }
  if (days > 0) {
    return '$days d $hours h';
  }
  return '${value.inHours} h';
}

String formatBudgetLabel(double value) {
  return '\$${value.toStringAsFixed(2)}';
}

Duration? parseDurationLabel(String input) {
  final String trimmed = input.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    final RegExp combined =
        RegExp(r'^\s*(\d+)\s*d(?:ays?)?(?:\s+(\d+)\s*h(?:ours?)?)?\s*$');
    final RegExpMatch? combinedMatch = combined.firstMatch(trimmed);
    if (combinedMatch != null) {
      final int days = int.parse(combinedMatch.group(1)!);
      final int hours = int.tryParse(combinedMatch.group(2) ?? '0') ?? 0;
      return Duration(days: days, hours: hours);
    }
    final RegExp daysOnly = RegExp(r'^\s*(\d+)\s*d(?:ays?)?\s*$');
    final RegExpMatch? daysMatch = daysOnly.firstMatch(trimmed);
    if (daysMatch != null) {
      return Duration(days: int.parse(daysMatch.group(1)!));
    }
    final RegExp hoursOnly = RegExp(r'^\s*(\d+)\s*h(?:ours?)?\s*$');
    final RegExpMatch? hoursMatch = hoursOnly.firstMatch(trimmed);
    if (hoursMatch != null) {
      return Duration(hours: int.parse(hoursMatch.group(1)!));
    }
    final int? bareNumber = int.tryParse(trimmed);
    if (bareNumber != null) {
      return Duration(hours: bareNumber);
    }
  } catch (err) {
    debugPrint('parseDurationLabel error for "$input": $err');
  }
  return null;
}

double? parseBudgetLabel(String input) {
  final String trimmed = input.trim().replaceAll('\$', '').replaceAll(',', '');
  if (trimmed.isEmpty) {
    return null;
  }
  final double? parsed = double.tryParse(trimmed);
  if (parsed == null) {
    debugPrint('parseBudgetLabel could not parse "$input"');
    return null;
  }
  return parsed;
}
