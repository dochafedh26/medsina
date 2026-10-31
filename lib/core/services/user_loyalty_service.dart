import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/supabase_service.dart';

class UserLoyaltyStats {
  final int connectionCount;
  final int streakDays;
  final int maxStreakDays;
  final int loyaltyPoints;
  final String loyaltyLevel;
  final String lastActiveDate; // YYYY-MM-DD
  final String firstActiveDate; // YYYY-MM-DD
  final List<String> activeDaysHistory; // list of YYYY-MM-DD
  final int totalUsageSeconds;

  const UserLoyaltyStats({
    required this.connectionCount,
    required this.streakDays,
    required this.maxStreakDays,
    required this.loyaltyPoints,
    required this.loyaltyLevel,
    required this.lastActiveDate,
    required this.firstActiveDate,
    required this.activeDaysHistory,
    required this.totalUsageSeconds,
  });

  factory UserLoyaltyStats.initial() {
    final today = _dateToString(DateTime.now());
    return UserLoyaltyStats(
      connectionCount: 1,
      streakDays: 1,
      maxStreakDays: 1,
      loyaltyPoints: 10,
      loyaltyLevel: 'Externe Studieux',
      lastActiveDate: today,
      firstActiveDate: today,
      activeDaysHistory: [today],
      totalUsageSeconds: 0,
    );
  }

  /// Calculates rank progression
  int get nextLevelThreshold {
    if (loyaltyPoints < 100) return 100;
    if (loyaltyPoints < 300) return 300;
    if (loyaltyPoints < 700) return 700;
    return 1500;
  }

  int get previousLevelThreshold {
    if (loyaltyPoints < 100) return 0;
    if (loyaltyPoints < 300) return 100;
    if (loyaltyPoints < 700) return 300;
    return 700;
  }

  double get progressToNextLevel {
    if (loyaltyPoints >= 1500) return 1.0;
    final range = nextLevelThreshold - previousLevelThreshold;
    if (range <= 0) return 1.0;
    final current = loyaltyPoints - previousLevelThreshold;
    return (current / range).clamp(0.0, 1.0);
  }

  String get nextLevelName {
    if (loyaltyPoints < 100) return 'Interne Assidu';
    if (loyaltyPoints < 300) return 'Résident Major';
    if (loyaltyPoints < 700) return 'Chef de Clinique Élite';
    return 'Légende Médicale';
  }

  bool isDayActive(DateTime day) {
    final str = _dateToString(day);
    return activeDaysHistory.contains(str);
  }

  static String _dateToString(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class UserLoyaltyService {
  static final UserLoyaltyService instance = UserLoyaltyService._();
  UserLoyaltyService._();

  static const String _keyConnectionCount = 'medsina_loyalty_connection_count';
  static const String _keyStreakDays = 'medsina_loyalty_streak_days';
  static const String _keyMaxStreakDays = 'medsina_loyalty_max_streak_days';
  static const String _keyLoyaltyPoints = 'medsina_loyalty_points';
  static const String _keyLastActiveDate = 'medsina_loyalty_last_active_date';
  static const String _keyFirstActiveDate = 'medsina_loyalty_first_active_date';
  static const String _keyHistoryDays = 'medsina_loyalty_history_days';
  static const String _keyUsageSeconds = 'medsina_loyalty_usage_seconds';

  final ValueNotifier<UserLoyaltyStats> statsNotifier =
      ValueNotifier<UserLoyaltyStats>(UserLoyaltyStats.initial());

  Timer? _sessionTimer;
  bool _isInitialized = false;

  UserLoyaltyStats get stats => statsNotifier.value;

  /// Initializes the service and tracks the current app session
  Future<UserLoyaltyStats> initializeAndTrack() async {
    if (_isInitialized) return statsNotifier.value;
    _isInitialized = true;

    final currentStats = await _loadLocalStats();
    final updated = await _computeSessionAndStreak(currentStats);
    statsNotifier.value = updated;
    await _saveLocalStats(updated);

    // Sync cloud asynchronously in background
    _syncWithCloud(updated);

    // Start discrete session heartbeat (records revision minutes)
    _startSessionHeartbeat();

    return updated;
  }

  /// Adds loyalty points for completing an action (e.g. QCM session, course read)
  Future<void> addPoints(int points, {String reason = ''}) async {
    if (points <= 0) return;
    final cur = statsNotifier.value;
    final newPoints = cur.loyaltyPoints + points;
    final newLevel = _calculateLevel(newPoints);

    final updated = UserLoyaltyStats(
      connectionCount: cur.connectionCount,
      streakDays: cur.streakDays,
      maxStreakDays: cur.maxStreakDays,
      loyaltyPoints: newPoints,
      loyaltyLevel: newLevel,
      lastActiveDate: cur.lastActiveDate,
      firstActiveDate: cur.firstActiveDate,
      activeDaysHistory: cur.activeDaysHistory,
      totalUsageSeconds: cur.totalUsageSeconds,
    );

    statsNotifier.value = updated;
    await _saveLocalStats(updated);
    _syncWithCloud(updated);
  }

  // --- INTERNAL COMPUTATIONS ---

  String _calculateLevel(int points) {
    if (points < 100) return 'Externe Studieux';
    if (points < 300) return 'Interne Assidu';
    if (points < 700) return 'Résident Major';
    return 'Chef de Clinique Élite';
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<UserLoyaltyStats> _loadLocalStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _formatDate(DateTime.now());

      final connectionCount = prefs.getInt(_keyConnectionCount) ?? 0;
      final streakDays = prefs.getInt(_keyStreakDays) ?? 0;
      final maxStreakDays = prefs.getInt(_keyMaxStreakDays) ?? 0;
      final loyaltyPoints = prefs.getInt(_keyLoyaltyPoints) ?? 0;
      final lastActiveDate = prefs.getString(_keyLastActiveDate) ?? '';
      final firstActiveDate = prefs.getString(_keyFirstActiveDate) ?? today;
      final rawHistory = prefs.getStringList(_keyHistoryDays) ?? [];
      final usageSeconds = prefs.getInt(_keyUsageSeconds) ?? 0;

      return UserLoyaltyStats(
        connectionCount: connectionCount,
        streakDays: streakDays,
        maxStreakDays: maxStreakDays,
        loyaltyPoints: loyaltyPoints,
        loyaltyLevel: _calculateLevel(loyaltyPoints),
        lastActiveDate: lastActiveDate,
        firstActiveDate: firstActiveDate,
        activeDaysHistory: rawHistory,
        totalUsageSeconds: usageSeconds,
      );
    } catch (_) {
      return UserLoyaltyStats.initial();
    }
  }

  Future<void> _saveLocalStats(UserLoyaltyStats s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyConnectionCount, s.connectionCount);
      await prefs.setInt(_keyStreakDays, s.streakDays);
      await prefs.setInt(_keyMaxStreakDays, s.maxStreakDays);
      await prefs.setInt(_keyLoyaltyPoints, s.loyaltyPoints);
      await prefs.setString(_keyLastActiveDate, s.lastActiveDate);
      await prefs.setString(_keyFirstActiveDate, s.firstActiveDate);
      await prefs.setStringList(_keyHistoryDays, s.activeDaysHistory);
      await prefs.setInt(_keyUsageSeconds, s.totalUsageSeconds);
    } catch (_) {}
  }

  Future<UserLoyaltyStats> _computeSessionAndStreak(UserLoyaltyStats current) async {
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));

    int newConnections = current.connectionCount + 1;
    int newStreak = current.streakDays;
    int newMaxStreak = current.maxStreakDays;
    int newPoints = current.loyaltyPoints;
    final List<String> history = List<String>.from(current.activeDaysHistory);

    if (!history.contains(todayStr)) {
      history.add(todayStr);
      // Keep only last 60 days of history
      if (history.length > 60) {
        history.removeRange(0, history.length - 60);
      }
    }

    if (current.lastActiveDate.isEmpty) {
      // First ever session!
      newStreak = 1;
      newMaxStreak = 1;
      newPoints = (newPoints == 0) ? 10 : newPoints;
    } else if (current.lastActiveDate == todayStr) {
      // Already logged in today -> streak remains the same
      newStreak = (newStreak <= 0) ? 1 : newStreak;
    } else if (current.lastActiveDate == yesterdayStr) {
      // Consecutive day login!
      newStreak += 1;
      newPoints += 10; // Daily check-in XP

      // Streak milestones bonuses
      if (newStreak == 3) newPoints += 25;
      if (newStreak == 7) newPoints += 70;
      if (newStreak == 14) newPoints += 150;
      if (newStreak == 30) newPoints += 350;
    } else {
      // More than 1 day missed -> reset streak to 1
      newStreak = 1;
      newPoints += 10; // Welcome back XP
    }

    if (newStreak > newMaxStreak) {
      newMaxStreak = newStreak;
    }

    final newLevel = _calculateLevel(newPoints);

    return UserLoyaltyStats(
      connectionCount: newConnections,
      streakDays: newStreak,
      maxStreakDays: newMaxStreak,
      loyaltyPoints: newPoints,
      loyaltyLevel: newLevel,
      lastActiveDate: todayStr,
      firstActiveDate: current.firstActiveDate.isEmpty ? todayStr : current.firstActiveDate,
      activeDaysHistory: history,
      totalUsageSeconds: current.totalUsageSeconds,
    );
  }

  void _startSessionHeartbeat() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final cur = statsNotifier.value;
      final updated = UserLoyaltyStats(
        connectionCount: cur.connectionCount,
        streakDays: cur.streakDays,
        maxStreakDays: cur.maxStreakDays,
        loyaltyPoints: cur.loyaltyPoints,
        loyaltyLevel: cur.loyaltyLevel,
        lastActiveDate: cur.lastActiveDate,
        firstActiveDate: cur.firstActiveDate,
        activeDaysHistory: cur.activeDaysHistory,
        totalUsageSeconds: cur.totalUsageSeconds + 60,
      );
      statsNotifier.value = updated;
      await _saveLocalStats(updated);
    });
  }

  Future<void> _syncWithCloud(UserLoyaltyStats s) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return;

      // 1. Update public.profiles columns if available
      try {
        await SupabaseService.client.from('profiles').update({
          'connection_count': s.connectionCount,
          'streak_days': s.streakDays,
          'max_streak_days': s.maxStreakDays,
          'last_connection_at': DateTime.now().toIso8601String(),
          'loyalty_points': s.loyaltyPoints,
          'loyalty_level': s.loyaltyLevel,
          'total_usage_seconds': s.totalUsageSeconds,
        }).eq('id', user.id);
      } catch (_) {}

      // 2. Also persist to user_cloud_sync (data_type = 'loyalty_tracker')
      try {
        await SupabaseService.client.from('user_cloud_sync').upsert({
          'id': '${user.id}_loyalty_tracker',
          'user_id': user.id,
          'data_type': 'loyalty_tracker',
          'payload': {
            'connection_count': s.connectionCount,
            'streak_days': s.streakDays,
            'max_streak_days': s.maxStreakDays,
            'loyalty_points': s.loyaltyPoints,
            'loyalty_level': s.loyaltyLevel,
            'last_active_date': s.lastActiveDate,
            'first_active_date': s.firstActiveDate,
            'active_days_history': s.activeDaysHistory,
            'total_usage_seconds': s.totalUsageSeconds,
          },
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('Loyalty cloud sync note: $e');
    }
  }

  void dispose() {
    _sessionTimer?.cancel();
  }
}
