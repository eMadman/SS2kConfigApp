import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_theme/json_theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themePreferenceKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;

  ThemeMode get themeMode => _themeMode;
  ThemeData? get lightTheme => _lightTheme;
  ThemeData? get darkTheme => _darkTheme;

  ThemeProvider() {
    _loadThemePreference();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    // Load light theme
    final lightThemeStr = await rootBundle.loadString('assets/appainter_theme.json');
    final lightThemeJson = jsonDecode(lightThemeStr);
    _lightTheme = ThemeDecoder.decodeThemeData(lightThemeJson)!;

    // Load dark theme
    final darkThemeStr = await rootBundle.loadString('assets/appainter_theme_dark.json');
    final darkThemeJson = jsonDecode(darkThemeStr);
    _darkTheme = ThemeDecoder.decodeThemeData(darkThemeJson)!;

    notifyListeners();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePreferenceKey);
    if (savedTheme != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedTheme,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, mode.toString());
    notifyListeners();
  }
}