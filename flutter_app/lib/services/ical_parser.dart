import '../models/event.dart';

class ICalParser {
  static CalendarEvent? parseVEvent(String icalData, String href, String? etag) {
    final lines = _unfold(icalData);
    bool inVEvent = false;
    final props = <String, _Property>{};

    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        inVEvent = true;
        continue;
      }
      if (line == 'END:VEVENT') {
        inVEvent = false;
        continue;
      }
      if (!inVEvent) continue;

      final prop = _parseLine(line);
      if (prop != null) {
        props[prop.name] = prop;
      }
    }

    final uid = props['UID']?.value;
    final summary = props['SUMMARY']?.value;
    final dtstart = props['DTSTART'];
    final dtend = props['DTEND'];

    if (uid == null || summary == null || dtstart == null) return null;

    final isAllDay = dtstart.params['VALUE'] == 'DATE' || dtstart.value.length == 8;
    final start = _parseICalDate(dtstart.value, dtstart.params);
    DateTime end;
    if (dtend != null) {
      end = _parseICalDate(dtend.value, dtend.params);
    } else {
      end = isAllDay ? start.add(const Duration(days: 1)) : start.add(const Duration(hours: 1));
    }

    return CalendarEvent(
      uid: uid,
      summary: _unescapeText(summary),
      start: start,
      end: end,
      allDay: isAllDay,
      description: props['DESCRIPTION'] != null ? _unescapeText(props['DESCRIPTION']!.value) : null,
      location: props['LOCATION'] != null ? _unescapeText(props['LOCATION']!.value) : null,
      href: href,
      etag: etag,
    );
  }

  static String serialize(CalendarEvent event) {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//Minca//Minca//EN');
    buf.writeln('BEGIN:VEVENT');
    buf.writeln('UID:${event.uid}');
    buf.writeln('DTSTAMP:${_formatDateTime(DateTime.now().toUtc(), utc: true)}');

    if (event.allDay) {
      buf.writeln('DTSTART;VALUE=DATE:${_formatDate(event.start)}');
      buf.writeln('DTEND;VALUE=DATE:${_formatDate(event.end)}');
    } else {
      buf.writeln('DTSTART:${_formatDateTime(event.start.toUtc(), utc: true)}');
      buf.writeln('DTEND:${_formatDateTime(event.end.toUtc(), utc: true)}');
    }

    buf.writeln('SUMMARY:${_escapeText(event.summary)}');
    if (event.description != null && event.description!.isNotEmpty) {
      buf.writeln('DESCRIPTION:${_escapeText(event.description!)}');
    }
    if (event.location != null && event.location!.isNotEmpty) {
      buf.writeln('LOCATION:${_escapeText(event.location!)}');
    }
    buf.writeln('END:VEVENT');
    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  static List<String> _unfold(String data) {
    return data
        .replaceAll('\r\n ', '')
        .replaceAll('\r\n\t', '')
        .replaceAll('\n ', '')
        .replaceAll('\n\t', '')
        .split(RegExp(r'\r?\n'));
  }

  static _Property? _parseLine(String line) {
    final colonIdx = line.indexOf(':');
    if (colonIdx == -1) return null;

    final nameAndParams = line.substring(0, colonIdx);
    final value = line.substring(colonIdx + 1);

    final semicolonIdx = nameAndParams.indexOf(';');
    final name = semicolonIdx == -1
        ? nameAndParams.toUpperCase()
        : nameAndParams.substring(0, semicolonIdx).toUpperCase();

    final paramsStr = semicolonIdx == -1 ? '' : nameAndParams.substring(semicolonIdx + 1);
    final params = <String, String>{};
    for (final param in paramsStr.split(';')) {
      final eqIdx = param.indexOf('=');
      if (eqIdx != -1) {
        params[param.substring(0, eqIdx).toUpperCase()] = param.substring(eqIdx + 1);
      }
    }

    return _Property(name, value, params);
  }

  static DateTime _parseICalDate(String value, Map<String, String> params) {
    final isAllDay = value.length == 8 || params['VALUE'] == 'DATE';

    if (isAllDay) {
      return DateTime(
        int.parse(value.substring(0, 4)),
        int.parse(value.substring(4, 6)),
        int.parse(value.substring(6, 8)),
      );
    }

    final isUtc = value.endsWith('Z');
    final clean = isUtc ? value.substring(0, value.length - 1) : value;

    final year = int.parse(clean.substring(0, 4));
    final month = int.parse(clean.substring(4, 6));
    final day = int.parse(clean.substring(6, 8));
    final hour = int.parse(clean.substring(9, 11));
    final minute = int.parse(clean.substring(11, 13));
    final second = int.parse(clean.substring(13, 15));

    if (isUtc) {
      return DateTime.utc(year, month, day, hour, minute, second).toLocal();
    }
    return DateTime(year, month, day, hour, minute, second);
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime dt, {bool utc = false}) {
    final d = utc ? dt.toUtc() : dt;
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}T'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}'
        '${d.second.toString().padLeft(2, '0')}'
        '${utc ? 'Z' : ''}';
  }

  static String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  static String _unescapeText(String text) {
    return text
        .replaceAll('\\n', '\n')
        .replaceAll('\\,', ',')
        .replaceAll('\\;', ';')
        .replaceAll('\\\\', '\\');
  }
}

class _Property {
  final String name;
  final String value;
  final Map<String, String> params;

  _Property(this.name, this.value, this.params);
}
