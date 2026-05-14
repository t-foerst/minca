class CalendarEvent {
  final String uid;
  final String summary;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? description;
  final String? location;
  final String href;
  final String? etag;

  const CalendarEvent({
    required this.uid,
    required this.summary,
    required this.start,
    required this.end,
    this.allDay = false,
    this.description,
    this.location,
    required this.href,
    this.etag,
  });

  bool occursOn(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final DateTime e;
    if (allDay) {
      // iCal all-day DTEND is exclusive (day after last day)
      e = DateTime(end.year, end.month, end.day).subtract(const Duration(days: 1));
    } else {
      e = DateTime(end.year, end.month, end.day);
    }
    return !d.isBefore(s) && !d.isAfter(e);
  }

  CalendarEvent copyWith({
    String? uid,
    String? summary,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    String? description,
    String? location,
    String? href,
    String? etag,
  }) {
    return CalendarEvent(
      uid: uid ?? this.uid,
      summary: summary ?? this.summary,
      start: start ?? this.start,
      end: end ?? this.end,
      allDay: allDay ?? this.allDay,
      description: description ?? this.description,
      location: location ?? this.location,
      href: href ?? this.href,
      etag: etag ?? this.etag,
    );
  }
}
