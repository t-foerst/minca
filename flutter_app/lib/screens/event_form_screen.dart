import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/calendar_provider.dart';

class EventFormScreen extends StatefulWidget {
  final CalendarEvent? event;
  final DateTime initialDate;

  const EventFormScreen({super.key, this.event, required this.initialDate});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  late bool _allDay;

  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _titleController = TextEditingController(text: event.summary);
      _descriptionController = TextEditingController(text: event.description ?? '');
      _locationController = TextEditingController(text: event.location ?? '');
      _startDate = event.start;
      _startTime = TimeOfDay.fromDateTime(event.start);
      _endDate = event.end;
      _endTime = TimeOfDay.fromDateTime(event.end);
      _allDay = event.allDay;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _locationController = TextEditingController();
      _startDate = widget.initialDate;
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endDate = widget.initialDate;
      _endTime = const TimeOfDay(hour: 10, minute: 0);
      _allDay = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  DateTime _combined(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);

    final provider = context.read<CalendarProvider>();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    try {
      if (_isEditing) {
        final updated = widget.event!.copyWith(
          summary: _titleController.text.trim(),
          start: _allDay ? _startDate : _combined(_startDate, _startTime),
          end: _allDay
              ? _endDate.add(const Duration(days: 1))
              : _combined(_endDate, _endTime),
          allDay: _allDay,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
        );
        await provider.updateEvent(updated);
      } else {
        await provider.createEvent(
          summary: _titleController.text.trim(),
          start: _allDay ? _startDate : _combined(_startDate, _startTime),
          end: _allDay
              ? _endDate.add(const Duration(days: 1))
              : _combined(_endDate, _endTime),
          allDay: _allDay,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final provider = context.read<CalendarProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Termin löschen'),
        content: const Text('Diesen Termin wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Builder(builder: (ctx) => Text('Löschen', style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await provider.deleteEvent(widget.event!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, d. MMM yyyy', 'de');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Termin bearbeiten' : 'Neuer Termin'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isSaving ? null : _delete,
              tooltip: 'Löschen',
            ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Speichern', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          TextField(
            controller: _titleController,
            autofocus: !_isEditing,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              hintText: 'Titel',
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ganztägig'),
            value: _allDay,
            onChanged: (v) => setState(() => _allDay = v),
          ),
          const SizedBox(height: 8),
          _buildDateTimeRow(
            context: context,
            label: 'Beginn',
            date: _startDate,
            time: _startTime,
            dateFormat: dateFormat,
            timeFormat: timeFormat,
            onDateTap: () => _pickDate(true),
            onTimeTap: () => _pickTime(true),
          ),
          const SizedBox(height: 8),
          _buildDateTimeRow(
            context: context,
            label: 'Ende',
            date: _endDate,
            time: _endTime,
            dateFormat: dateFormat,
            timeFormat: timeFormat,
            onDateTap: () => _pickDate(false),
            onTimeTap: () => _pickTime(false),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Beschreibung',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.notes_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'Ort',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow({
    required BuildContext context,
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required DateFormat dateFormat,
    required DateFormat timeFormat,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final dt = _combined(date, time);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
        ),
        GestureDetector(
          onTap: onDateTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(dateFormat.format(date), style: const TextStyle(fontSize: 14)),
          ),
        ),
        if (!_allDay) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTimeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(timeFormat.format(dt), style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ],
    );
  }
}
