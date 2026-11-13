import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/models/user_model.dart';
import '../network/supabase_service.dart';

class AiQuotaConsumeResult {
  final bool allowed;
  final bool isInfinite;
  final int dailyRemaining;
  final int dailyLimit;
  final int dailyUsed;
  final int bonusRemaining;
  final String? message;
  final String? consumedFrom; // 'daily', 'bonus', 'admin', 'fallback'

  const AiQuotaConsumeResult({
    required this.allowed,
    this.isInfinite = false,
    this.dailyRemaining = 0,
    this.dailyLimit = 35,
    this.dailyUsed = 0,
    this.bonusRemaining = 0,
    this.message,
    this.consumedFrom,
  });
}

class AiQuotaService {
  AiQuotaService._();
  static final AiQuotaService instance = AiQuotaService._();

  static const String _prefsKeyPrefix = 'medsina_ai_daily_quotas_';

  int _dailyRequestsUsed = 0;
  int _dailyLimit = 35;
  int _bonusCreditsBalance = 0;
  String _lastDate = '';

  int get dailyRequestsUsed => _dailyRequestsUsed;
  int get dailyLimit => _dailyLimit;
  int get dailyRemaining => (_dailyLimit - _dailyRequestsUsed).clamp(0, 999999);
  int get bonusCreditsBalance => _bonusCreditsBalance;
  int get totalAvailableQueries => dailyRemaining + _bonusCreditsBalance;

  /// Load and sync user AI quotas from Supabase database
  Future<void> loadQuotas(String? userId) async {
    if (userId == null || userId.isEmpty) return;

    final todayStr = DateTime.now().toIso8601String().split('T').first;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_prefsKeyPrefix$userId');
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        _applyData(map, todayStr);
      } catch (_) {}
    }

    try {
      final cloudData = await SupabaseService.fetchUserAiQuotas(userId);
      if (cloudData != null) {
        _applyData(cloudData, todayStr);
        await prefs.setString('$_prefsKeyPrefix$userId', jsonEncode(cloudData));
      }
    } catch (e) {
      debugPrint('Error syncing AI quotas from Cloud: $e');
    }
  }

  void _applyData(Map<String, dynamic> data, String todayStr) {
    _lastDate = data['last_request_date']?.toString() ?? todayStr;
    _dailyLimit = (data['daily_limit'] as num?)?.toInt() ?? _dailyLimit;
    _bonusCreditsBalance = (data['bonus_credits_balance'] as num?)?.toInt() ?? _bonusCreditsBalance;

    // Reset daily if cached date is earlier than today
    if (_lastDate.isNotEmpty && _lastDate != todayStr) {
      _dailyRequestsUsed = 0;
      _lastDate = todayStr;
    } else {
      _dailyRequestsUsed = (data['daily_used'] as num?)?.toInt() ??
          (data['daily_requests_used'] as num?)?.toInt() ??
          _dailyRequestsUsed;
    }
  }

  /// Check quota before executing a Gemini query and consume 1 credit
  Future<AiQuotaConsumeResult> checkAndConsume(UserModel? user) async {
    // 1. Admin bypass: unlimited
    if (user != null && user.isAdmin) {
      return const AiQuotaConsumeResult(
        allowed: true,
        isInfinite: true,
        dailyRemaining: 999999,
        bonusRemaining: 999999,
        consumedFrom: 'admin',
      );
    }

    if (user == null) {
      return const AiQuotaConsumeResult(
        allowed: false,
        message: 'Veuillez vous connecter pour utiliser MedsinaPilot.',
      );
    }

    // 2. Execute atomic consumption RPC on Supabase
    try {
      final res = await SupabaseService.consumeAiQuery(user.id);
      final bool isAllowed = res['allowed'] == true;
      final consumedFrom = res['consumed_from']?.toString();
      final dailyRemaining = (res['daily_remaining'] as num?)?.toInt() ?? 0;
      final dailyLimit = (res['daily_limit'] as num?)?.toInt() ?? _dailyLimit;
      final dailyUsed = (res['daily_used'] as num?)?.toInt() ?? _dailyRequestsUsed;
      final bonusRemaining = (res['bonus_remaining'] as num?)?.toInt() ?? _bonusCreditsBalance;

      // Update in-memory state
      _dailyRequestsUsed = dailyUsed;
      _dailyLimit = dailyLimit;
      _bonusCreditsBalance = bonusRemaining;

      // Update local storage cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefsKeyPrefix${user.id}',
        jsonEncode({
          'daily_used': _dailyRequestsUsed,
          'daily_limit': _dailyLimit,
          'bonus_credits_balance': _bonusCreditsBalance,
          'last_request_date': DateTime.now().toIso8601String().split('T').first,
        }),
      );

      return AiQuotaConsumeResult(
        allowed: isAllowed,
        dailyRemaining: dailyRemaining,
        dailyLimit: dailyLimit,
        dailyUsed: dailyUsed,
        bonusRemaining: bonusRemaining,
        consumedFrom: consumedFrom,
        message: res['message']?.toString(),
      );
    } catch (e) {
      debugPrint('AI quota consume fallback: $e');
      // Graceful offline fallback: allow request if local estimate is within limit
      if (dailyRemaining > 0 || _bonusCreditsBalance > 0) {
        if (dailyRemaining > 0) {
          _dailyRequestsUsed++;
        } else {
          _bonusCreditsBalance = (_bonusCreditsBalance - 1).clamp(0, 999999);
        }
        return AiQuotaConsumeResult(
          allowed: true,
          dailyRemaining: dailyRemaining,
          dailyLimit: _dailyLimit,
          dailyUsed: _dailyRequestsUsed,
          bonusRemaining: _bonusCreditsBalance,
          consumedFrom: 'offline_cache',
        );
      }

      return AiQuotaConsumeResult(
        allowed: false,
        dailyRemaining: 0,
        dailyLimit: _dailyLimit,
        dailyUsed: _dailyRequestsUsed,
        bonusRemaining: 0,
        message: 'Votre quota quotidien de requêtes est atteint. Revenez demain ou rechargez un pack bonus.',
      );
    }
  }
}

