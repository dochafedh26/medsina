import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/user_loyalty_service.dart';

enum FocusPreset {
  classic25_5(
    label: 'Classique 25/5',
    focusMinutes: 25,
    breakMinutes: 5,
    description: 'Idéal pour les séries de QCM',
  ),
  deepWork50_10(
    label: 'Deep Work 50/10',
    focusMinutes: 50,
    breakMinutes: 10,
    description: 'Immersion cours & fiches lourdes',
  ),
  sprint15_3(
    label: 'Sprint 15/3',
    focusMinutes: 15,
    breakMinutes: 3,
    description: 'Révision rapide flashcards FSRS',
  );

  final String label;
  final int focusMinutes;
  final int breakMinutes;
  final String description;

  const FocusPreset({
    required this.label,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.description,
  });
}

enum FocusPhase { focus, shortBreak }

class FocusTimerService extends ChangeNotifier {
  static final FocusTimerService instance = FocusTimerService._();
  FocusTimerService._();

  static const String _keySessionsTotal = 'medsina_focus_sessions_total';
  static const String _keyMinutesToday = 'medsina_focus_minutes_today';
  static const String _keyMinutesDate = 'medsina_focus_minutes_date';

  FocusPreset _preset = FocusPreset.classic25_5;
  FocusPhase _phase = FocusPhase.focus;
  int _remainingSeconds = FocusPreset.classic25_5.focusMinutes * 60;
  bool _isRunning = false;
  int _completedSessionsTotal = 0;
  int _minutesToday = 0;
  Timer? _ticker;

  FocusPreset get preset => _preset;
  FocusPhase get phase => _phase;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  int get completedSessionsTotal => _completedSessionsTotal;
  int get minutesToday => _minutesToday;

  int get totalPhaseSeconds => (_phase == FocusPhase.focus
          ? _preset.focusMinutes
          : _preset.breakMinutes) *
      60;

  double get progress {
    final total = totalPhaseSeconds;
    if (total <= 0) return 0.0;
    return (1.0 - (_remainingSeconds / total)).clamp(0.0, 1.0);
  }

  String get formattedRemaining {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _completedSessionsTotal = prefs.getInt(_keySessionsTotal) ?? 0;
      final savedDate = prefs.getString(_keyMinutesDate);
      final today = _todayStr();
      if (savedDate == today) {
        _minutesToday = prefs.getInt(_keyMinutesToday) ?? 0;
      } else {
        _minutesToday = 0;
        await prefs.setString(_keyMinutesDate, today);
        await prefs.setInt(_keyMinutesToday, 0);
      }
      notifyListeners();
    } catch (_) {}
  }

  void selectPreset(FocusPreset newPreset) {
    pause();
    _preset = newPreset;
    _phase = FocusPhase.focus;
    _remainingSeconds = newPreset.focusMinutes * 60;
    notifyListeners();
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  void pause() {
    _isRunning = false;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void reset() {
    pause();
    _remainingSeconds = totalPhaseSeconds;
    notifyListeners();
  }

  /// Advances the timer by 1 second (exposed for deterministic unit tests).
  Future<bool> tick() async {
    if (_remainingSeconds > 1) {
      _remainingSeconds--;
      notifyListeners();
      return false;
    }

    _remainingSeconds = 0;
    pause();
    await _onPhaseCompleted();
    return true;
  }

  Future<void> skipPhase() async {
    pause();
    await _onPhaseCompleted(creditFocus: false);
  }

  Future<void> _onPhaseCompleted({bool creditFocus = true}) async {
    if (_phase == FocusPhase.focus) {
      if (creditFocus) {
        await recordCompletedFocusSession(_preset.focusMinutes);
      }
      _phase = FocusPhase.shortBreak;
      _remainingSeconds = _preset.breakMinutes * 60;
    } else {
      _phase = FocusPhase.focus;
      _remainingSeconds = _preset.focusMinutes * 60;
    }
    notifyListeners();
  }

  Future<void> recordCompletedFocusSession(int minutes) async {
    _completedSessionsTotal++;
    _minutesToday += minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySessionsTotal, _completedSessionsTotal);
      await prefs.setString(_keyMinutesDate, _todayStr());
      await prefs.setInt(_keyMinutesToday, _minutesToday);
      await UserLoyaltyService.instance.addPoints(
        15,
        reason: 'Session Focus Pomodoro (${minutes}min)',
      );
    } catch (_) {}
    notifyListeners();
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
