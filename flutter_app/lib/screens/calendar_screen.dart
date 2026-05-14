import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/calendar_provider.dart';
import 'event_form_screen.dart';
import 'settings_screen.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minca',
          style: TextStyle(fontWeight: FontWeight.w300, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Heute',
            onPressed: () {
              final now = DateTime.now();
              final p = context.read<CalendarProvider>();
              p.selectDate(now);
              p.setViewMonth(now);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: const Column(
        children: [
          _MonthHeader(),
          Expanded(child: _MonthGrid()),
        ],
      ),
      floatingActionButton: Consumer<CalendarProvider>(
        builder: (context, provider, _) => FloatingActionButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventFormScreen(initialDate: provider.selectedDate),
            ),
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ── Month navigation header ───────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  const _MonthHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        final month = provider.viewMonth;
        final label = DateFormat('MMMM yyyy', 'de').format(month);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => provider.setViewMonth(
                  DateTime(month.year, month.month - 1),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (provider.isLoading) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => provider.setViewMonth(
                  DateTime(month.year, month.month + 1),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Full-screen month grid ────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid();

  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        final cells = _buildCells(provider.viewMonth);
        final today = DateTime.now();
        final rowCount = (cells.length / 7).ceil();

        return Column(
          children: [
            // ── Weekday header row
            SizedBox(
              height: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int col = 0; col < 7; col++) ...[
                    if (col > 0)
                      VerticalDivider(width: 1, thickness: 1, color: cs.outline),
                    Expanded(
                      child: Center(
                        child: Text(
                          _weekdays[col],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: cs.outline),

            // ── Day rows (each takes equal vertical space)
            for (int row = 0; row < rowCount; row++) ...[
              if (row > 0) Divider(height: 1, thickness: 1, color: cs.outline),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int col = 0; col < 7; col++) ...[
                      if (col > 0)
                        VerticalDivider(width: 1, thickness: 1, color: cs.outline),
                      Expanded(
                        child: _DayCell(
                          date: row * 7 + col < cells.length
                              ? cells[row * 7 + col]
                              : null,
                          today: today,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  List<DateTime?> _buildCells(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = (firstDay.weekday - 1) % 7; // Mon = 0

    return [
      for (int i = 0; i < offset; i++) null,
      for (int d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
    ];
  }
}

// ── Single day cell ───────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime? date;
  final DateTime today;

  const _DayCell({required this.date, required this.today});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.expand();

    final provider = context.watch<CalendarProvider>();
    final cs = Theme.of(context).colorScheme;

    final isSelected = DateUtils.isSameDay(date, provider.selectedDate);
    final isToday = DateUtils.isSameDay(date, today);
    final isCurrentMonth = date!.month == provider.viewMonth.month;

    // Sort: all-day first, then by start time
    final events = provider.events
        .where((e) => e.occursOn(date!))
        .toList()
      ..sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return a.start.compareTo(b.start);
      });

    return GestureDetector(
      onTap: () => provider.selectDate(date!),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day number with today/selected indicator
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(left: 2, top: 2, bottom: 2),
              decoration: isSelected
                  ? BoxDecoration(
                      color: cs.onSurface,
                      shape: BoxShape.circle,
                    )
                  : isToday
                      ? BoxDecoration(
                          border: Border.all(color: cs.onSurface, width: 1.5),
                          shape: BoxShape.circle,
                        )
                      : null,
              child: Center(
                child: Text(
                  '${date!.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                    color: isSelected
                        ? cs.surface
                        : isCurrentMonth
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            // Event chips (fill remaining cell height)
            Expanded(child: _CellEvents(events: events)),
          ],
        ),
      ),
    );
  }
}

// ── Event list inside a cell (dynamic overflow) ───────────────────────────────

class _CellEvents extends StatelessWidget {
  final List<CalendarEvent> events;

  const _CellEvents({required this.events});

  // Each chip: 16px height + 2px top + 2px bottom margin
  static const _chipSlot = 20.0;
  static const _overflowSlot = 16.0;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;

        final int maxVisible;
        if (events.length * _chipSlot <= available) {
          maxVisible = events.length;
        } else {
          maxVisible = ((available - _overflowSlot) / _chipSlot)
              .floor()
              .clamp(0, events.length);
        }

        final overflow = events.length - maxVisible;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in events.take(maxVisible)) _EventChip(event: e),
            if (overflow > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 1),
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Single event chip ─────────────────────────────────────────────────────────

class _EventChip extends StatelessWidget {
  final CalendarEvent event;

  const _EventChip({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeStr =
        event.allDay ? null : DateFormat('HH:mm').format(event.start);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventFormScreen(event: event, initialDate: event.start),
        ),
      ),
      child: Container(
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            if (timeStr != null)
              Text(
                '$timeStr ',
                style: TextStyle(
                  fontSize: 9,
                  color: cs.onPrimary.withValues(alpha: 0.7),
                ),
              ),
            Expanded(
              child: Text(
                event.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
