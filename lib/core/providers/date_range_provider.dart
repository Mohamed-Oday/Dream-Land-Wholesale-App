import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared date range state for all list screens.
/// null = no filter (show all records).
final dateRangeProvider = StateProvider<DateTimeRange?>((ref) => todayRange());

/// Algeria is UTC+1 (no DST). Returns midnight Algeria time as UTC.
DateTime _algeriaStartOfDay(DateTime algiersLocal) {
  final startAlgeria = DateTime(algiersLocal.year, algiersLocal.month, algiersLocal.day);
  // Convert Algeria local (UTC+1) back to UTC by subtracting 1 hour
  return startAlgeria.subtract(const Duration(hours: 1));
}

/// Current time in Algeria local (UTC+1).
DateTime _algiersNow() {
  return DateTime.now().toUtc().add(const Duration(hours: 1));
}

/// Today: midnight Algeria to now (UTC).
DateTimeRange todayRange() {
  final now = _algiersNow();
  return DateTimeRange(
    start: _algeriaStartOfDay(now),
    end: DateTime.now().toUtc(),
  );
}

/// This week: Monday midnight Algeria to now (UTC).
DateTimeRange thisWeekRange() {
  final now = _algiersNow();
  final weekday = now.weekday; // 1=Monday
  final monday = now.subtract(Duration(days: weekday - 1));
  return DateTimeRange(
    start: _algeriaStartOfDay(monday),
    end: DateTime.now().toUtc(),
  );
}

/// This month: 1st of month midnight Algeria to now (UTC).
DateTimeRange thisMonthRange() {
  final now = _algiersNow();
  final firstOfMonth = DateTime(now.year, now.month, 1);
  return DateTimeRange(
    start: _algeriaStartOfDay(firstOfMonth),
    end: DateTime.now().toUtc(),
  );
}
