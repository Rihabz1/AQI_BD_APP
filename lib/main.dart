import 'package:flutter/material.dart';
import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/forecast_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/about_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_logo.dart';

void main() => runApp(const AQIBDApp());

class AQIBDApp extends StatefulWidget {
  const AQIBDApp({super.key});
  @override
  State<AQIBDApp> createState() => _AQIBDAppState();
}

class _AQIBDAppState extends State<AQIBDApp> {
  bool _dark = false;

  ThemeData get _lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F7FB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D552E)), // Your green color
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF2D552E), // Your green color
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF2D552E), // Your green color
          unselectedItemColor: Color(0xFF9AA0A6),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 8, // makes bar visible
        ),
        dividerColor: const Color(0xFFE6E8EC),
      );

  ThemeData get _darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A7C59), // Brighter green for dark mode
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4A7C59), // Brighter green
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1F1F1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1F1F1F),
          selectedItemColor: Color(0xFF4A7C59), // Brighter green for dark mode
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        dividerColor: Colors.grey.shade800,
      );

  @override
  Widget build(BuildContext context) {
    return AppState(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AQI BD',
        theme: _dark ? _darkTheme : _lightTheme,
        home: SplashScreen(
          nextScreen: RootScreen(
            darkMode: _dark,
            onToggleDark: () => setState(() => _dark = !_dark),
          ),
        ),
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  final bool darkMode;
  final VoidCallback onToggleDark;
  const RootScreen({super.key, required this.darkMode, required this.onToggleDark});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    TrendsScreen(),
    ForecastScreen(),
    AlertsScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: 12),
            const Text('AQI-BD'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(widget.darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleDark,
            tooltip: 'Toggle Dark Mode',
          ),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart_rounded), label: 'Trends'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Forecast'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none_rounded), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline_rounded), label: 'About'),
        ],
      ),
    );
  }
}
