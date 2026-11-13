import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeChoice {
  system,
  light,
  dark,
  nightShift,
}

/// Manages the active theme mode including "Garde de Nuit" (AMOLED + Amber).
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  ThemeController._();

  static const String _keyThemeChoice = 'medsina_theme_choice';
  static const String _keyAutoNightShift = 'medsina_auto_night_shift_22h';

  AppThemeChoice _choice = AppThemeChoice.system;
  bool _autoNightShiftAfter22h = false;

  AppThemeChoice get choice => _choice;
  bool get autoNightShiftAfter22h => _autoNightShiftAfter22h;

  /// Returns true if Night Shift (AMOLED + Amber) should be active right now.
  bool isNightShiftActiveAt([DateTime? now]) {
    if (_choice == AppThemeChoice.nightShift) return true;
    if (_autoNightShiftAfter22h && _choice == AppThemeChoice.system) {
      final hour = (now ?? DateTime.now()).hour;
      return hour >= 22 || hour < 6;
    }
    return false;
  }

  bool get isNightShiftActive => isNightShiftActiveAt();

  ThemeMode get themeMode {
    if (isNightShiftActive) return ThemeMode.dark;
    switch (_choice) {
      case AppThemeChoice.light:
        return ThemeMode.light;
      case AppThemeChoice.dark:
      case AppThemeChoice.nightShift:
        return ThemeMode.dark;
      case AppThemeChoice.system:
        return ThemeMode.system;
    }
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyThemeChoice);
      if (saved != null) {
        _choice = AppThemeChoice.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => AppThemeChoice.system,
        );
      }
      _autoNightShiftAfter22h = prefs.getBool(_keyAutoNightShift) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setChoice(AppThemeChoice newChoice) async {
    if (_choice == newChoice) return;
    _choice = newChoice;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyThemeChoice, newChoice.name);
    } catch (_) {}
  }

  Future<void> toggleNightShift() async {
    if (isNightShiftActive) {
      await setChoice(AppThemeChoice.system);
    } else {
      await setChoice(AppThemeChoice.nightShift);
    }
  }

  Future<void> setAutoNightShiftAfter22h(bool enabled) async {
    if (_autoNightShiftAfter22h == enabled) return;
    _autoNightShiftAfter22h = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoNightShift, enabled);
    } catch (_) {}
  }
}
