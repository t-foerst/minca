import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calendar_collection.dart';
import '../providers/calendar_provider.dart';

class SettingsScreen extends StatefulWidget {
  final bool isInitialSetup;

  const SettingsScreen({super.key, this.isInitialSetup = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _obscurePassword = true;
  bool _isConnecting = false;
  String? _connectionError;

  List<CalendarCollection>? _calendars;
  bool _isLoadingCalendars = false;
  String? _calendarsError;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CalendarProvider>();
    _urlController = TextEditingController(
      text: provider.savedUrl.isEmpty
          ? 'https://radicale.foerst.haus'
          : provider.savedUrl,
    );
    _usernameController = TextEditingController(text: provider.savedUsername);
    _passwordController = TextEditingController(text: provider.savedPassword);

    if (provider.isConfigured) _loadCalendars();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendars() async {
    setState(() {
      _isLoadingCalendars = true;
      _calendarsError = null;
    });
    try {
      final cals = await context.read<CalendarProvider>().loadCalendars();
      if (mounted) setState(() { _calendars = cals; _isLoadingCalendars = false; });
    } catch (e) {
      if (mounted) setState(() { _calendarsError = e.toString(); _isLoadingCalendars = false; });
    }
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (url.isEmpty || username.isEmpty) {
      setState(() => _connectionError = 'URL und Benutzername sind erforderlich.');
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      await context.read<CalendarProvider>().configure(url, username, password);
      if (mounted) await _loadCalendars();
    } catch (e) {
      if (mounted) setState(() => _connectionError = e.toString());
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _createCalendar() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neuer Kalender'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      await context.read<CalendarProvider>().addCalendar(name);
      if (mounted) await _loadCalendars();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  Future<void> _deleteCalendar(CalendarCollection calendar) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kalender löschen'),
        content: Text(
            '„${calendar.displayName}" und alle Termine wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Builder(
              builder: (ctx) => Text('Löschen',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await context.read<CalendarProvider>().removeCalendar(calendar);
      if (mounted) await _loadCalendars();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isInitialSetup ? 'Verbindung einrichten' : 'Einstellungen',
        ),
        automaticallyImplyLeading: !widget.isInitialSetup,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.isInitialSetup) ...[
            const Text(
              'Radicale Server',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Verbinde die App mit deinem CalDAV-Server.',
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
          ],
          _buildField(
            controller: _urlController,
            label: 'Server-URL',
            hint: 'https://radicale.foerst.haus',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _usernameController,
            label: 'Benutzername',
            hint: 'username',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Passwort',
              border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8))),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_connectionError != null) ...[
            Builder(builder: (ctx) {
              final cs = Theme.of(ctx).colorScheme;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.error.withValues(alpha: 0.4)),
                ),
                child: Text(_connectionError!,
                    style:
                        TextStyle(color: cs.onErrorContainer, fontSize: 13)),
              );
            }),
            const SizedBox(height: 16),
          ],
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _isConnecting ? null : _connect,
              child: _isConnecting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary))
                  : const Text('Verbinden'),
            ),
          ),

          // ── Kalender-Abschnitt ─────────────────────────────────────────────
          Consumer<CalendarProvider>(
            builder: (context, provider, _) {
              if (!provider.isConfigured) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Kalender',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                      ),
                      if (_isLoadingCalendars)
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _loadCalendars,
                          tooltip: 'Neu laden',
                        ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _createCalendar,
                        tooltip: 'Neuer Kalender',
                      ),
                    ],
                  ),
                  if (_calendarsError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_calendarsError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13)),
                    )
                  else if (_calendars == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_calendars!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Keine Kalender gefunden.',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    )
                  else
                    for (final cal in _calendars!)
                      CheckboxListTile(
                        title: Text(cal.displayName),
                        value: provider.isCalendarActive(cal),
                        onChanged: (_) => provider.toggleCalendar(cal),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color:
                                  Theme.of(context).colorScheme.error,
                              size: 20),
                          onPressed: () => _deleteCalendar(cal),
                          tooltip: 'Löschen',
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
    );
  }
}
