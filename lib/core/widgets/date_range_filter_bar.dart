import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawzii/core/l10n/app_localizations.dart';
import 'package:tawzii/core/providers/date_range_provider.dart';

enum _DatePreset { today, thisWeek, thisMonth, all }

class DateRangeFilterBar extends ConsumerStatefulWidget {
  const DateRangeFilterBar({super.key});

  @override
  ConsumerState<DateRangeFilterBar> createState() => _DateRangeFilterBarState();
}

class _DateRangeFilterBarState extends ConsumerState<DateRangeFilterBar> {
  _DatePreset _selected = _DatePreset.today;

  void _onSelected(_DatePreset preset) {
    setState(() => _selected = preset);
    final DateTimeRange? range;
    switch (preset) {
      case _DatePreset.today:
        range = todayRange();
      case _DatePreset.thisWeek:
        range = thisWeekRange();
      case _DatePreset.thisMonth:
        range = thisMonthRange();
      case _DatePreset.all:
        range = null;
    }
    ref.read(dateRangeProvider.notifier).state = range;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final presets = {
      _DatePreset.today: l10n.today,
      _DatePreset.thisWeek: l10n.thisWeek,
      _DatePreset.thisMonth: l10n.thisMonth,
      _DatePreset.all: l10n.allTime,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: presets.entries.map((entry) {
            final isSelected = _selected == entry.key;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (_) => _onSelected(entry.key),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
