import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart'; // Importamos la pantalla principal

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_VE', null);
  
  await dotenv.load(fileName: ".env"); 
  
  runApp(const VeneConverterApp());
}

class VeneConverterApp extends StatefulWidget {
  const VeneConverterApp({super.key});

  @override
  State<VeneConverterApp> createState() => _VeneConverterAppState();
}

class _VeneConverterAppState extends State<VeneConverterApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.system
          ? ThemeMode.light
          : (_themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.system);
    });
  }

  IconData getThemeIcon() {
    if (_themeMode == ThemeMode.system) return Icons.brightness_auto;
    if (_themeMode == ThemeMode.light) return Icons.light_mode;
    return Icons.dark_mode;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VeneConverter',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
      ),
      home: MainScreen(
        toggleTheme: toggleTheme,
        currentThemeIcon: getThemeIcon(),
      ),
    );
  }
}