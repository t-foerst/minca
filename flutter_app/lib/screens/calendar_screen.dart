import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/calendar_provider.dart';
import '../services/update_service.dart';
import 'event_form_screen.dart';
import 'settings_screen.dart';

// ── Root screen ───────────────────────────────────────────────────────────────

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Enough pages for ~50 years in each direction.
  static const _initialPage = 600;
  final _now = DateTime.now();
  late final PageController _pageController =
      PageController(initialPage: _initialPage);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _pageToMonth(int page) =>
      DateTime(_now.year, _now.month + (page - _initialPage));

  int get _currentPage =>
      _pageController.hasClients
          ? (_pageController.page?.round() ?? _initialPage)
          : _initialPage;

  void _animateTo(int page) => _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );

  void _goToPrev() {
    final page = _currentPage;
    // Update header immediately so the label doesn't lag behind the animation.
    context.read<CalendarProvider>().setViewMonth(_pageToMonth(page - 1));
    _animateTo(page - 1);
  }

  void _goToNext() {
    final page = _currentPage;
    context.read<CalendarProvider>().setViewMonth(_pageToMonth(page + 1));
    _animateTo(page + 1);
  }

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
              context.read<CalendarProvider>().selectDate(now);
              // Jump without animation when potentially far away.
              _pageController.jumpToPage(_initialPage);
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
      body: Column(
        children: [
          if (Platform.isWindows || Platform.isLinux) const _UpdateBanner(),
          _MonthHeader(onPrev: _goToPrev, onNext: _goToNext),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              // onPageChanged fires when the integer page index crosses 0.5 during
              // a swipe, so the header label updates fluidly mid-gesture.
              onPageChanged: (page) => context
                  .read<CalendarProvider>()
                  .setViewMonth(_pageToMonth(page)),
              itemBuilder: (context, page) =>
                  _MonthGrid(month: _pageToMonth(page)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month navigation header ───────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        final label = DateFormat('MMMM yyyy', 'de').format(provider.viewMonth);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrev,
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
                    // Always reserve this fixed space so the text position
                    // never shifts when the loading indicator appears/disappears.
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: provider.isLoading
                          ? CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: cs.onSurfaceVariant,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNext,
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
  final DateTime month;

  const _MonthGrid({super.key, required this.month});

  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cells = _buildCells(month);
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

        // ── Day rows
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
                      viewMonth: month,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
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

class _DayCell extends StatefulWidget {
  final DateTime? date;
  final DateTime today;
  final DateTime viewMonth;

  const _DayCell({
    required this.date,
    required this.today,
    required this.viewMonth,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.date == null) return const SizedBox.expand();

    final provider = context.watch<CalendarProvider>();
    final cs = Theme.of(context).colorScheme;

    final isSelected = DateUtils.isSameDay(widget.date, provider.selectedDate);
    final isToday = DateUtils.isSameDay(widget.date, widget.today);
    final isCurrentMonth = widget.date!.month == widget.viewMonth.month &&
        widget.date!.year == widget.viewMonth.year;

    final events = provider.events
        .where((e) => e.occursOn(widget.date!))
        .toList()
      ..sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return a.start.compareTo(b.start);
      });

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          provider.selectDate(widget.date!);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventFormScreen(initialDate: widget.date!),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _hovered
              ? cs.surfaceContainerHighest.withValues(alpha: 0.55)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              border:
                                  Border.all(color: cs.onSurface, width: 1.5),
                              shape: BoxShape.circle,
                            )
                          : null,
                  child: Center(
                    child: Text(
                      '${widget.date!.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.normal,
                        color: isSelected
                            ? cs.surface
                            : isCurrentMonth
                                ? cs.onSurface
                                : cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _CellEvents(events: events)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Event list inside a cell (dynamic overflow) ───────────────────────────────

class _CellEvents extends StatelessWidget {
  final List<CalendarEvent> events;

  const _CellEvents({required this.events});

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

// ── Auto-update banner ────────────────────────────────────────────────────────

class _UpdateBanner extends StatefulWidget {
  const _UpdateBanner();

  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner> {
  UpdateInfo? _update;
  bool _dismissed = false;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final info = await UpdateService.checkForUpdate();
    if (mounted && info != null) setState(() => _update = info);
  }

  Future<void> _applyUpdate() async {
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      await UpdateService.downloadAndApply(_update!, (p) {
        if (mounted) setState(() => _progress = p);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Update fehlgeschlagen: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_update == null || _dismissed) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _downloading
            ? Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Update wird heruntergeladen…',
                        style: TextStyle(
                            fontSize: 13, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        backgroundColor:
                            cs.onPrimaryContainer.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                ),
              ])
            : Row(children: [
                Icon(Icons.system_update_outlined,
                    size: 18, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Version ${_update!.version} verfügbar',
                    style: TextStyle(
                        fontSize: 13, color: cs.onPrimaryContainer),
                  ),
                ),
                TextButton(
                  onPressed: _applyUpdate,
                  style: TextButton.styleFrom(
                      foregroundColor: cs.onPrimaryContainer),
                  child: const Text('Jetzt aktualisieren',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 16, color: cs.onPrimaryContainer),
                  onPressed: () => setState(() => _dismissed = true),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
      ),
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
          builder: (_) =>
              EventFormScreen(event: event, initialDate: event.start),
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
