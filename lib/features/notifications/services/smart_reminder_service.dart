import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/user_study_progress_service.dart';
import '../../revision/models/flashcard_fsrs_model.dart';

class SmartReminderStatus {
  final bool shouldWarnStreak;
  final int currentStreak;
  final int dueFsrsCards;
  final int daysUntilExam;
  final String examTitle;

  const SmartReminderStatus({
    required this.shouldWarnStreak,
    required this.currentStreak,
    required this.dueFsrsCards,
    required this.daysUntilExam,
    required this.examTitle,
  });

  String get countdownBadgeText =>
      daysUntilExam >= 0 ? 'J-$daysUntilExam' : 'J+${daysUntilExam.abs()}';
}

/// Manages local smart reminders (evening streak protection, FSRS due cards)
/// and the dynamic J-xxx countdown for Résidanat Blida 2027.
class SmartReminderService {
  static final SmartReminderService instance = SmartReminderService._();
  SmartReminderService._();

  static const String _keyExamDateIso = 'medsina_exam_target_date_iso';
  static const String _keyExamTitle = 'medsina_exam_target_title';
  static const String _keyRemindersEnabled = 'medsina_smart_reminders_enabled';

  static final DateTime defaultExamDate = DateTime(2027, 10, 15);
  static const String defaultExamTitle = 'Résidanat Blida 2027';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  Future<void> initialize() async {
    if (_notificationsInitialized || kIsWeb) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(settings: initSettings);
      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('LocalNotifications init notice: $e');
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await initialize();
    if (!_notificationsInitialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'medsina_smart_reminders',
        'Rappels & Alertes Medsina',
        channelDescription:
            'Rappels de série (Streak), cartes FSRS dues et notifications push',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('showInstantNotification notice: $e');
    }
  }

  Future<DateTime> getTargetExamDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(_keyExamDateIso);
      if (iso != null) {
        final parsed = DateTime.tryParse(iso);
        if (parsed != null) return parsed;
      }
    } catch (_) {}
    return defaultExamDate;
  }

  Future<String> getTargetExamTitle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyExamTitle) ?? defaultExamTitle;
    } catch (_) {
      return defaultExamTitle;
    }
  }

  Future<void> setTargetExam({
    required DateTime date,
    required String title,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExamDateIso, date.toIso8601String());
    await prefs.setString(_keyExamTitle, title);
  }

  Future<bool> isRemindersEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRemindersEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemindersEnabled, enabled);
  }

  /// Pure calculation for deterministic unit testing.
  static int computeDaysUntil(DateTime targetDate, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final startOfTarget =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    return startOfTarget.difference(startOfToday).inDays;
  }

  /// Pure evaluation of whether evening streak protection should trigger.
  static bool shouldTriggerEveningStreakAlert({
    required bool isTodayAccomplished,
    required int currentStreak,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    return !isTodayAccomplished && currentStreak > 0 && current.hour >= 19;
  }

  Future<SmartReminderStatus> evaluateStatus() async {
    final progress = await UserStudyProgressService.instance.initialize();
    await FlashcardFsrsService.instance.ensureInitialized();
    final cards = FlashcardFsrsService.instance.cards;
    final dueCount = cards.where((c) => c.isDueNow).length;
    final targetDate = await getTargetExamDate();
    final examTitle = await getTargetExamTitle();

    final warnStreak = shouldTriggerEveningStreakAlert(
      isTodayAccomplished: progress.isTodayAccomplished,
      currentStreak: progress.currentStreak,
    );

    if (await isRemindersEnabled()) {
      if (warnStreak) {
        await showInstantNotification(
          id: 1001,
          title: 'Protégez votre série de ${progress.currentStreak} jours 🔥',
          body:
              'Il ne reste que quelques heures pour valider votre objectif QCM du jour.',
        );
      } else if (dueCount >= 10) {
        await showInstantNotification(
          id: 1002,
          title: '$dueCount flashcards FSRS à réviser 🧠',
          body:
              'Maintenez votre rétention optimale avec une session rapide de 5 minutes.',
        );
      }
    }

    return SmartReminderStatus(
      shouldWarnStreak: warnStreak,
      currentStreak: progress.currentStreak,
      dueFsrsCards: dueCount,
      daysUntilExam: computeDaysUntil(targetDate),
      examTitle: examTitle,
    );
  }
}
