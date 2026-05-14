import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../services/caldav_service.dart';

const _keyUrl = 'caldav_url';
const _keyUsername = 'caldav_username';
const _keyPassword = 'caldav_password';
const _keyPath = 'caldav_path';

const _uuid = Uuid();

class CalendarProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  CalendarProvider(this._prefs);

  CalDavService? _service;
  DateTime _selectedDate = DateTime.now();
  DateTime _viewMonth = DateTime.now();
  List<CalendarEvent> _events = [];
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

  String get savedUrl => _prefs.getString(_keyUrl) ?? '';
  String get savedUsername => _prefs.getString(_keyUsername) ?? '';
  String get savedPassword => _prefs.getString(_keyPassword) ?? '';
  String get savedPath => _prefs.getString(_keyPath) ?? '';

  Future<void> initialize() async {
    final url = _prefs.getString(_keyUrl);
    final username = _prefs.getString(_keyUsername);
    final password = _prefs.getString(_keyPassword);
    final path = _prefs.getString(_keyPath);

    if (url != null && username != null && password != null && path != null) {
      _service = CalDavService(
        baseUrl: url,
        username: username,
        password: password,
        calendarPath: path,
      );
      notifyListeners();
      await loadEvents();
    }
  }

  Future<void> configure(
    String url,
    String username,
    String password,
    String path,
  ) async {
    final service = CalDavService(
      baseUrl: url,
      username: username,
      password: password,
      calendarPath: path,
    );

    await service.testConnection();

    await _prefs.setString(_keyUrl, url);
    await _prefs.setString(_keyUsername, username);
    await _prefs.setString(_keyPassword, password);
    await _prefs.setString(_keyPath, path);

    _service = service;
    notifyListeners();
    await loadEvents();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> setViewMonth(DateTime month) async {
    _viewMonth = DateTime(month.year, month.month, 1);
    notifyListeners();
    await loadEvents();
  }

  Future<void> loadEvents() async {
    if (_service == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final start = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
      final end = DateTime(_viewMonth.year, _viewMonth.month + 2, 1);
      _events = await _service!.fetchEvents(start, end);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createEvent({
    required String summary,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String? description,
    String? location,
  }) async {
    final uid = _uuid.v4();
    final path = savedPath.endsWith('/') ? savedPath : '$savedPath/';
    final event = CalendarEvent(
      uid: uid,
      summary: summary,
      start: start,
      end: end,
      allDay: allDay,
      description: description,
      location: location,
      href: '$path$uid.ics',
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
}
