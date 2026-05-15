import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/calendar_collection.dart';
import '../models/event.dart';
import '../services/caldav_service.dart';

const _keyUrl = 'caldav_url';
const _keyUsername = 'caldav_username';
const _keyPassword = 'caldav_password';
const _keyActivePaths = 'caldav_active_paths';

const _uuid = Uuid();

class CalendarProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  CalendarProvider(this._prefs);

  CalDavService? _service;
  DateTime _selectedDate = DateTime.now();
  DateTime _viewMonth = DateTime.now();
  List<CalendarEvent> _events = [];
  // Normalized paths (no leading/trailing slashes), e.g. "thorben/uuid"
  Set<String> _activePaths = {};
  bool _isLoading = false;
  String? _error;

  bool get isConfigured => _service != null;
  DateTime get selectedDate => _selectedDate;
  DateTime get viewMonth => _viewMonth;
  List<CalendarEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<CalendarEvent> get eventsForSelectedDate =>
      _events.where((e) => e.occursOn(_selectedDate)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  bool hasEventsOn(DateTime date) => _events.any((e) => e.occursOn(date));

  bool isCalendarActive(CalendarCollection cal) =>
      _activePaths.contains(_normalize(cal.path));

  String get savedUrl => _prefs.getString(_keyUrl) ?? '';
  String get savedUsername => _prefs.getString(_keyUsername) ?? '';
  String get savedPassword => _prefs.getString(_keyPassword) ?? '';

  Future<void> initialize() async {
    final url = _prefs.getString(_keyUrl);
    final username = _prefs.getString(_keyUsername);
    final password = _prefs.getString(_keyPassword);

    if (url != null && username != null && password != null) {
      _service = CalDavService(baseUrl: url, username: username, password: password);

      final pathsJson = _prefs.getString(_keyActivePaths);
      if (pathsJson != null) {
        final List<dynamic> paths = jsonDecode(pathsJson);
        _activePaths = paths.cast<String>().toSet();
      }

      notifyListeners();
      await loadEvents();
    }
  }

  Future<void> configure(String url, String username, String password) async {
    final service = CalDavService(baseUrl: url, username: username, password: password);
    await service.testConnection();

    await _prefs.setString(_keyUrl, url);
    await _prefs.setString(_keyUsername, username);
    await _prefs.setString(_keyPassword, password);

    _service = service;
    notifyListeners();
    await loadEvents();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> setViewMonth(DateTime month) async {
    final normalized = DateTime(month.year, month.month, 1);
    if (_viewMonth.year == normalized.year && _viewMonth.month == normalized.month) return;
    _viewMonth = normalized;
    notifyListeners();
    await loadEvents();
  }

  Future<void> loadEvents() async {
    if (_service == null || _activePaths.isEmpty) {
      _events = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final start = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
      final end = DateTime(_viewMonth.year, _viewMonth.month + 2, 1);
      final allEvents = <CalendarEvent>[];
      for (final normalizedPath in _activePaths) {
        final events = await _service!.fetchEvents('/$normalizedPath/', start, end);
        allEvents.addAll(events);
      }
      _events = allEvents;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<CalendarCollection>> loadCalendars() async {
    if (_service == null) throw Exception('Nicht verbunden');
    return _service!.listCalendars();
  }

  Future<void> toggleCalendar(CalendarCollection calendar) async {
    final normalized = _normalize(calendar.path);
    if (_activePaths.contains(normalized)) {
      _activePaths.remove(normalized);
    } else {
      _activePaths.add(normalized);
    }
    await _saveActivePaths();
    notifyListeners();
    await loadEvents();
  }

  Future<void> addCalendar(String name) async {
    if (_service == null) throw Exception('Nicht verbunden');
    final cal = await _service!.createCalendar(name);
    await toggleCalendar(cal);
  }

  Future<void> removeCalendar(CalendarCollection calendar) async {
    if (_service == null) throw Exception('Nicht verbunden');
    await _service!.deleteCalendar(calendar.path);
    _activePaths.remove(_normalize(calendar.path));
    await _saveActivePaths();
    await loadEvents();
  }

  Future<void> createEvent({
    required String summary,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? description,
    String? location,
  }) async {
    if (_activePaths.isEmpty) throw Exception('Kein Kalender ausgewählt');
    final calPath = '/${_activePaths.first}/';
    final uid = _uuid.v4();
    final event = CalendarEvent(
      uid: uid,
      summary: summary,
      start: start,
      end: end,
      allDay: allDay,
      description: description,
      location: location,
      href: '$calPath$uid.ics',
    );
    await _service!.createEvent(event);
    await loadEvents();
  }

  Future<void> updateEvent(CalendarEvent event) async {
    await _service!.updateEvent(event);
    await loadEvents();
  }

  Future<void> deleteEvent(CalendarEvent event) async {
    await _service!.deleteEvent(event);
    await loadEvents();
  }

  Future<void> _saveActivePaths() async {
    await _prefs.setString(_keyActivePaths, jsonEncode(_activePaths.toList()));
  }

  static String _normalize(String path) => path.replaceAll(RegExp(r'^/|/$'), '');
}
