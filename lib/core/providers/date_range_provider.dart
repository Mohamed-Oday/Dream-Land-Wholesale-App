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

/// Today: midnight Algeria onwards (no end bound — always includes latest).
DateTimeRange todayRange() {
  final now = _algiersNow();
  final start = _algeriaStartOfDay(now);
  // end = far future so DateTimeRange is valid, but query ignores endDate
  return DateTimeRange(start: start, end: start.add(const Duration(days: 1)));
}

/// This week: Monday midnight Algeria onwards.
DateTimeRange thisWeekRange() {
  final now = _algiersNow();
  final weekday = now.weekday; // 1=Monday
  final monday = now.subtract(Duration(days: weekday - 1));
  final start = _algeriaStartOfDay(monday);
  return DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
}

/// This month: 1st of month midnight Algeria onwards.
DateTimeRange thisMonthRange() {
  final now = _algiersNow();
  final firstOfMonth = DateTime(now.year, now.month, 1);
  final start = _algeriaStartOfDay(firstOfMonth);
  return DateTimeRange(start: start, end: start.add(const Duration(days: 31)));
}
