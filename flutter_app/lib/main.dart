import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/calendar_provider.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A1A1A),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF1A1A1A),
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFFF3F3F3),
      onSurfaceVariant: const Color(0xFF6E6E6E),
      outline: const Color(0xFFE0E0E0),
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A1A1A),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFE8E8E8),
      onPrimary: const Color(0xFF1A1A1A),
      surface: const Color(0xFF121212),
      onSurface: const Color(0xFFE8E8E8),
      surfaceContainerHighest: const Color(0xFF252525),
      onSurfaceVariant: const Color(0xFF9E9E9E),
      outline: const Color(0xFF383838),
    );

    return ChangeNotifierProvider(
      create: (_) => CalendarProvider(prefs),
      child: MaterialApp(
        title: 'Minca',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        theme: _buildTheme(lightScheme),
        darkTheme: _buildTheme(darkScheme),
        themeMode: ThemeMode.system,
        home: const _AppRoot(),
      ),
    );
  }

  ThemeData _buildTheme(ColorScheme cs) {
    return ThemeData(
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      dividerColor: cs.outline,
      dividerTheme: DividerThemeData(color: cs.outline, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
      ),
      useMaterial3: true,
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        if (!provider.isConfigured) {
          return const SettingsScreen(isInitialSetup: true);
        }
        return const CalendarScreen();
      },
    );
  }
}
