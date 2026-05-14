import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';
import '../models/calendar_collection.dart';
import '../models/event.dart';
import 'ical_parser.dart';

class CalDavException implements Exception {
  final String message;
  final int? statusCode;
  CalDavException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null ? '$message (HTTP $statusCode)' : message;
}

class CalDavService {
  final String baseUrl;
  final String username;
  final String password;

  CalDavService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  String get _base =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  String get _userHomeUrl => '$_base/$username/';

  Map<String, String> get _authHeader => {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      };

  String _absoluteUrl(String href) {
    if (href.startsWith('http')) return href;
    return '$_base$href';
  }

  Future<http.Response> _send(
    String method,
    String url, {
    String? body,
    Map<String, String>? extraHeaders,
  }) async {
    final request = http.Request(method, Uri.parse(url));
    request.headers.addAll(_authHeader);
    if (extraHeaders != null) request.headers.addAll(extraHeaders);
    if (body != null) request.body = body;

    final streamed = await http.Client().send(request);
    return http.Response.fromStream(streamed);
  }

  Future<void> testConnection() async {
    final response = await _send(
      'PROPFIND',
      _userHomeUrl,
      body: '<D:propfind xmlns:D="DAV:"><D:prop><D:displayname/></D:prop></D:propfind>',
      extraHeaders: {'Depth': '0', 'Content-Type': 'application/xml; charset=utf-8'},
    );
    if (response.statusCode != 207 && response.statusCode != 200) {
      throw CalDavException('Verbindung fehlgeschlagen', statusCode: response.statusCode);
    }
  }

  Future<List<CalendarEvent>> fetchEvents(
    String calendarPath,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    final startStr = _formatUtc(rangeStart);
    final endStr = _formatUtc(rangeEnd);

    final body = '''<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <D:getetag/>
    <C:calendar-data/>
  </D:prop>
  <C:filter>
    <C:comp-filter name="VCALENDAR">
      <C:comp-filter name="VEVENT">
        <C:time-range start="$startStr" end="$endStr"/>
      </C:comp-filter>
    </C:comp-filter>
  </C:filter>
</C:calendar-query>''';

    final response = await _send(
      'REPORT',
      _absoluteUrl(calendarPath),
      body: body,
      extraHeaders: {'Depth': '1', 'Content-Type': 'application/xml; charset=utf-8'},
    );

    if (response.statusCode != 207) {
      throw CalDavException('Ereignisse konnten nicht geladen werden',
          statusCode: response.statusCode);
    }

    return _parseMultistatus(response.body);
  }

  List<CalendarEvent> _parseMultistatus(String xmlBody) {
    final events = <CalendarEvent>[];
    final doc = XmlDocument.parse(xmlBody);

    final responses = doc.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'response');

    for (final response in responses) {
      final href = response.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'href')
          .firstOrNull
          ?.innerText
          .trim();

      final calData = response.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'calendar-data')
          .firstOrNull
          ?.innerText
          .trim();

      final etag = response.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'getetag')
          .firstOrNull
          ?.innerText
          .trim();

      if (href == null || calData == null || calData.isEmpty) continue;

      final event = ICalParser.parseVEvent(calData, href, etag);
      if (event != null) events.add(event);
    }

    return events;
  }

  Future<void> createEvent(CalendarEvent event) async {
    final url = _absoluteUrl(event.href);
    final ical = ICalParser.serialize(event);

    final response = await _send(
      'PUT',
      url,
      body: ical,
      extraHeaders: {'Content-Type': 'text/calendar; charset=utf-8'},
    );

    if (response.statusCode != 201 && response.statusCode != 204) {
      throw CalDavException('Termin konnte nicht erstellt werden',
          statusCode: response.statusCode);
    }
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final url = _absoluteUrl(event.href);
    final ical = ICalParser.serialize(event);

    final headers = {'Content-Type': 'text/calendar; charset=utf-8'};
    if (event.etag != null) headers['If-Match'] = event.etag!;

    final response = await _send('PUT', url, body: ical, extraHeaders: headers);

    if (response.statusCode != 201 && response.statusCode != 204) {
      throw CalDavException('Termin konnte nicht aktualisiert werden',
          statusCode: response.statusCode);
    }
  }

  Future<void> deleteEvent(CalendarEvent event) async {
    final url = _absoluteUrl(event.href);
    final headers = <String, String>{};
    if (event.etag != null) headers['If-Match'] = event.etag!;

    final response = await _send('DELETE', url, extraHeaders: headers);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CalDavException('Termin konnte nicht gelöscht werden',
          statusCode: response.statusCode);
    }
  }

  Future<List<CalendarCollection>> listCalendars() async {
    const body =
        '<?xml version="1.0" encoding="utf-8" ?>'
        '<D:propfind xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">'
        '<D:prop><D:displayname/><D:resourcetype/></D:prop>'
        '</D:propfind>';

    final response = await _send(
      'PROPFIND',
      _userHomeUrl,
      body: body,
      extraHeaders: {'Depth': '1', 'Content-Type': 'application/xml; charset=utf-8'},
    );

    if (response.statusCode != 207) {
      throw CalDavException('Kalender konnten nicht geladen werden',
          statusCode: response.statusCode);
    }

    return _parseCalendarList(response.body);
  }

  List<CalendarCollection> _parseCalendarList(String xmlBody) {
    final calendars = <CalendarCollection>[];
    final doc = XmlDocument.parse(xmlBody);

    for (final response in doc.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'response')) {
      final href = response.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'href')
          .firstOrNull
          ?.innerText
          .trim();
      if (href == null) continue;

      final resourceType = response.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'resourcetype')
          .firstOrNull;
      if (resourceType == null) continue;

      if (!resourceType.descendants
          .whereType<XmlElement>()
          .any((e) => e.name.local == 'calendar')) continue;

      final displayName = response.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 'displayname')
              .firstOrNull
              ?.innerText
              .trim() ??
          '';

      calendars.add(CalendarCollection(
        path: href,
        displayName: displayName.isEmpty ? href : displayName,
      ));
    }

    return calendars;
  }

  Future<CalendarCollection> createCalendar(String displayName) async {
    const uuid = Uuid();
    final uid = uuid.v4();
    final calPath = '/$username/$uid/';
    final url = '$_base$calPath';

    final body =
        '<?xml version="1.0" encoding="utf-8" ?>'
        '<C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">'
        '<D:set><D:prop>'
        '<D:displayname>$displayName</D:displayname>'
        '</D:prop></D:set>'
        '</C:mkcalendar>';

    final response = await _send(
      'MKCALENDAR',
      url,
      body: body,
      extraHeaders: {'Content-Type': 'application/xml; charset=utf-8'},
    );

    if (response.statusCode != 201) {
      throw CalDavException('Kalender konnte nicht erstellt werden',
          statusCode: response.statusCode);
    }

    return CalendarCollection(path: calPath, displayName: displayName);
  }

  Future<void> deleteCalendar(String calPath) async {
    final response = await _send('DELETE', _absoluteUrl(calPath));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CalDavException('Kalender konnte nicht gelöscht werden',
          statusCode: response.statusCode);
    }
  }

  String _formatUtc(DateTime dt) {
    final d = dt.toUtc();
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}T'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}'
        '${d.second.toString().padLeft(2, '0')}Z';
  }
}
