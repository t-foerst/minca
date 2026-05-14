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
        title: const Text('Minca', style: TextStyle(fontWeight: FontWeight.w300, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: const [
          _MonthHeader(),
          _CalendarGrid(),
          Divider(height: 1),
          Expanded(child: _EventList()),
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

class _MonthHeader extends StatelessWidget {
  const _MonthHeader();

  @override
  Widget build(BuildContext context) {
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
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid();

  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  static const _rowHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        final cells = _buildCells(provider.viewMonth);
        final today = DateTime.now();
        final rowCount = (cells.length / 7).ceil();

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Weekday header
              SizedBox(
                height: 28,
                child: Row(
                  children: _weekdays
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              // Day rows
              ...List.generate(rowCount, (row) {
                return SizedBox(
                  height: _rowHeight,
                  child: Row(
                    children: List.generate(7, (col) {
                      final idx = row * 7 + col;
                      if (idx >= cells.length) return const Expanded(child: SizedBox());
                      return Expanded(
                        child: _DayCell(date: cells[idx], today: today),
                      );
                    }),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  List<DateTime?> _buildCells(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = (firstDay.weekday - 1) % 7;

    final cells = <DateTime?>[];
    for (int i = 0; i < offset; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    return cells;
  }
}

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
    final hasEvents = provider.hasEventsOn(date!);
    final isCurrentMonth = date!.month == provider.viewMonth.month;

    return GestureDetector(
      onTap: () => provider.selectDate(date!),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: isSelected
            ? BoxDecoration(color: cs.onSurface, shape: BoxShape.circle)
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date!.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? cs.surface
                    : isCurrentMonth
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha:0.3),
              ),
            ),
            SizedBox(
              height: 6,
              child: hasEvents
                  ? Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.surface.withValues(alpha:0.7)
                              : cs.onSurface.withValues(alpha:0.45),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        final selectedDate = provider.selectedDate;
        final events = provider.eventsForSelectedDate;
        final dateLabel = DateFormat('EEEE, d. MMMM', 'de').format(selectedDate);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (provider.isLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (provider.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  provider.error!,
                  style: TextStyle(fontSize: 12, color: cs.error),
                ),
              ),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        'Keine Termine',
                        style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha:0.3)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: events.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, i) => _EventTile(event: events[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('HH:mm');
    final timeLabel = event.allDay
        ? 'Ganztägig'
        : '${timeFormat.format(event.start)} – ${timeFormat.format(event.end)}';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventFormScreen(event: event, initialDate: event.start),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 36,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: cs.onSurface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.summary,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(
                          event.location!,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
