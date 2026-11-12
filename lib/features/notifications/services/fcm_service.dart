import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/supabase_service.dart';
import 'smart_reminder_service.dart';

/// Top-level background handler required by Firebase Messaging.
@pragma('vm:entry-point')
Future<void> medsinaFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  debugPrint('FCM background message: ${message.messageId}');
}

/// Manages Firebase Cloud Messaging (FCM) push notifications with safe fallback
/// when google-services.json / FirebaseOptions are not yet configured.
class FcmService {
  static final FcmService instance = FcmService._();
  FcmService._();

  static const String _keyCachedToken = 'medsina_fcm_token';
  static const List<String> defaultTopics = [
    'medsina_all',
    'medsina_updates',
    'medsina_residanat_blida',
    'medsina_urgent',
  ];

  bool _isInitialized = false;
  bool _isAvailable = false;
  String? _currentToken;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;

  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;
  String? get currentToken => _currentToken;

  Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Desktop Windows / Linux do not support Firebase Messaging natively
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      debugPrint('FCM skipped on unsupported desktop platform.');
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isAvailable = true;
    } catch (e) {
      debugPrint(
        'FCM non configuré (google-services.json manquant ou web sans options): $e',
      );
      _isAvailable = false;
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(medsinaFirebaseBackgroundHandler);
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM permission denied by user.');
        return;
      }

      _currentToken = await messaging.getToken();
      if (_currentToken != null) {
        await _persistAndSyncToken(_currentToken!, userId: userId);
      }

      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) async {
        _currentToken = newToken;
        await _persistAndSyncToken(newToken, userId: userId);
      });

      if (!kIsWeb) {
        for (final topic in defaultTopics) {
          try {
            await messaging.subscribeToTopic(topic);
          } catch (_) {}
        }
      }

      _foregroundSub =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final notif = message.notification;
        if (notif != null) {
          await SmartReminderService.instance.showInstantNotification(
            id: message.hashCode,
            title: notif.title ?? 'Medsina',
            body: notif.body ?? '',
            payload: message.data['route']?.toString(),
          );
        }
      });
    } catch (e) {
      debugPrint('FCM setup notice: $e');
    }
  }

  Future<void> _persistAndSyncToken(String token, {String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCachedToken, token);
    } catch (_) {}

    try {
      final uid = userId ?? SupabaseService.currentSession?.user.id;
      if (uid == null || uid.isEmpty) return;
      await SupabaseService.client.from('fcm_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'topics': defaultTopics,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (e) {
      debugPrint('FCM token Supabase sync notice: $e');
    }
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _tokenRefreshSub?.cancel();
  }
}
