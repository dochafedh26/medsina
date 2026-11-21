import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/supabase_service.dart';

/// Offline-first deduplicated funnel telemetry service.
/// Queues events locally on device with a stable UUID v4 `event_id` and
/// `device_timestamp`, then flushes idempotently to `public.funnel_events`.
class FunnelAnalyticsService {
  FunnelAnalyticsService._();
  static final FunnelAnalyticsService instance = FunnelAnalyticsService._();

  static const String _queuePrefsKey = 'medsina_funnel_events_queue_v1';
  static const int _maxQueuedEvents = 500;
  static const Duration _flushCooldown = Duration(seconds: 45);

  final Random _rng = Random.secure();
  bool _isFlushing = false;
  DateTime? _lastFlushAttempt;

  String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic> properties = const {},
    bool flushImmediately = false,
  }) async {
    final cleanName = eventName.trim();
    if (cleanName.isEmpty) return;

    final eventPayload = <String, dynamic>{
      'event_id': _generateUuidV4(),
      'event_name': cleanName,
      'properties': properties,
      'device_timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getString(_queuePrefsKey);
      final List<dynamic> queue = existingRaw != null && existingRaw.isNotEmpty
          ? List<dynamic>.from(jsonDecode(existingRaw) as List<dynamic>)
          : <dynamic>[];

      queue.add(eventPayload);
      if (queue.length > _maxQueuedEvents) {
        queue.removeRange(0, queue.length - _maxQueuedEvents);
      }
      await prefs.setString(_queuePrefsKey, jsonEncode(queue));
    } catch (e) {
      debugPrint('[FunnelAnalytics] Queue write notice: $e');
    }

    await flushPendingEvents(force: flushImmediately);
  }

  Future<void> flushPendingEvents({bool force = false}) async {
    if (_isFlushing) return;
    final user = SupabaseService.currentUser;
    if (user == null || user.id.isEmpty) return;

    final now = DateTime.now();
    if (!force &&
        _lastFlushAttempt != null &&
        now.difference(_lastFlushAttempt!) < _flushCooldown) {
      return;
    }

    _isFlushing = true;
    _lastFlushAttempt = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getString(_queuePrefsKey);
      if (existingRaw == null || existingRaw.isEmpty) return;

      final List<dynamic> queue = List<dynamic>.from(jsonDecode(existingRaw) as List<dynamic>);
      if (queue.isEmpty) return;

      final res = await SupabaseService.client.rpc(
        'insert_funnel_events_batch',
        params: {'p_events': queue},
      );

      if (res is Map && res['success'] == true) {
        await prefs.remove(_queuePrefsKey);
      }
    } catch (e) {
      debugPrint('[FunnelAnalytics] Flush deferred: $e');
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> trackSignupCompleted({
    required String method,
    required String role,
    required String faculty,
    int? studyYear,
    String? examYear,
    String source = 'app',
  }) {
    return trackEvent(
      'signup_completed',
      flushImmediately: true,
      properties: {
        'method': method,
        'role': role,
        'faculty': faculty,
        'year': ?studyYear,
        'exam_year': ?examYear,
        'source': source,
      },
    );
  }

  Future<void> trackOnboardingCompleted({
    required String role,
    required String faculty,
    required int studyYear,
    required String targetYear,
    required int dailyGoal,
  }) {
    return trackEvent(
      'onboarding_completed',
      flushImmediately: true,
      properties: {
        'role': role,
        'faculty': faculty,
        'year': studyYear,
        'exam_date': targetYear,
        'daily_goal': dailyGoal,
      },
    );
  }

  Future<void> trackPlanCreated({
    required List<String> modules,
    required int days,
    required String source,
  }) {
    return trackEvent(
      'plan_created',
      properties: {
        'modules': modules,
        'days': days,
        'source': source,
      },
    );
  }

  Future<void> trackQcmCompleted({
    required String moduleId,
    required bool correct,
    required String questionType,
    bool isCustomSession = false,
    bool offline = false,
  }) {
    return trackEvent(
      'qcm_completed',
      properties: {
        'module': moduleId,
        'correct': correct,
        'question_type': questionType,
        'custom_session': isCustomSession,
        'offline': offline,
      },
    );
  }

  Future<void> trackClinicalToolUsed({
    required String toolName,
    bool offline = false,
  }) {
    return trackEvent(
      'clinical_tool_used',
      properties: {
        'tool_name': toolName,
        'offline': offline,
      },
    );
  }

  Future<void> trackCheckoutStarted({
    required String plan,
    required String method,
    required double amount,
    String source = 'paywall',
  }) {
    return trackEvent(
      'checkout_started',
      flushImmediately: true,
      properties: {
        'plan': plan,
        'method': method,
        'amount': amount,
        'source': source,
      },
    );
  }

  Future<void> trackPaymentSucceeded({
    required String plan,
    required String method,
    required double amount,
    String? code,
  }) {
    return trackEvent(
      'payment_succeeded',
      flushImmediately: true,
      properties: {
        'plan': plan,
        'method': method,
        'amount': amount,
        'currency': 'DZD',
        if (code != null && code.isNotEmpty) 'code': code,
      },
    );
  }

  Future<void> trackReferralSent({
    required String channel,
    required String code,
  }) {
    return trackEvent(
      'referral_sent',
      properties: {
        'channel': channel,
        'code': code,
      },
    );
  }
}
