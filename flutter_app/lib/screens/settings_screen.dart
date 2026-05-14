import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  late final TextEditingController _pathController;

  bool _obscurePassword = true;
  bool _isConnecting = false;
  String? _connectionError;

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
    _pathController = TextEditingController(text: provider.savedPath);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final path = _pathController.text.trim();

    if (url.isEmpty || username.isEmpty || path.isEmpty) {
      setState(
        () =>
            _connectionError = 'URL, Benutzername und Pfad sind erforderlich.',
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      await context.read<CalendarProvider>().configure(
        url,
        username,
        password,
        path,
      );
      if (mounted && !widget.isInitialSetup) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _connectionError = e.toString());
    } finally {
      if (mounted) setState(() => _isConnecting = false);
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
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verbinde die App mit deinem CalDAV-Server.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: _pathController,
            label: 'Kalender-Pfad',
            hint: '/username/calendar/',
          ),
          const SizedBox(height: 8),
          Text(
            'Pfad zum Kalender, z.B. /username/calendar/',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          if (_connectionError != null) ...[
            Builder(
              builder: (ctx) {
                final cs = Theme.of(ctx).colorScheme;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.error.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _connectionError!,
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                  ),
                );
              },
            ),
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
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Text('Verbinden'),
            ),
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
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }
}
