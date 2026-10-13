import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/medical_notification.dart';

class RealtimeNotificationService {
  static final RealtimeNotificationService instance = RealtimeNotificationService._internal();
  RealtimeNotificationService._internal();

  final ValueNotifier<List<MedicalNotification>> notificationsNotifier =
      ValueNotifier<List<MedicalNotification>>([]);
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  // Broadcast stream controller for in-app alert toasts / snackbars
  final StreamController<MedicalNotification> _newNotificationController =
      StreamController<MedicalNotification>.broadcast();
  Stream<MedicalNotification> get onNewNotification => _newNotificationController.stream;

  RealtimeChannel? _pearlChannel;
  RealtimeChannel? _protocolChannel;
  RealtimeChannel? _courseChannel;
  RealtimeChannel? _qcmChannel;
  RealtimeChannel? _notificationChannel;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Load initial seed notifications (including recent daily pearl, CATs, etc.)
    await _loadInitialNotifications();

    // Subscribe to Supabase Realtime channels
    _subscribeToRealtime();
  }

  Future<void> _loadInitialNotifications() async {
    try {
      final client = SupabaseService.client;
      final List<MedicalNotification> items = [];

      // 1. Fetch recent daily pearls (last 3)
      try {
        final pearls = await client
            .from('daily_pearls')
            .select()
            .order('created_at', ascending: false)
            .limit(3);

        for (final p in pearls) {
          items.add(MedicalNotification(
            id: 'pearl_${p['id']}',
            title: '💡 ${p['title'] ?? 'Nouvelle Perle du Jour'}',
            message: '${p['course_name']} • ${p['module_name']}',
            type: NotificationType.pearl,
            createdAt: DateTime.tryParse(p['created_at'].toString()) ?? DateTime.now(),
            targetId: p['id']?.toString(),
            metadata: p,
          ));
        }
      } catch (e) {
        debugPrint('Supabase daily_pearls init load notice: $e');
      }

      // 2. Fetch recent courses (last 3)
      try {
        final courses = await client
            .from('courses')
            .select('id, name, module_id, created_at')
            .order('created_at', ascending: false)
            .limit(3);

        for (final c in courses) {
          items.add(MedicalNotification(
            id: 'course_${c['id']}',
            title: '📖 Nouveau Cours Disponible',
            message: '${c['name']}',
            type: NotificationType.course,
            createdAt: c['created_at'] != null
                ? DateTime.tryParse(c['created_at'].toString()) ?? DateTime.now()
                : DateTime.now().subtract(const Duration(hours: 4)),
            targetId: c['id']?.toString(),
          ));
        }
      } catch (e) {
        debugPrint('Supabase courses init load notice: $e');
      }

      // Add local default fallback notifications if items list is short
      if (items.isEmpty) {
        items.addAll([
          MedicalNotification(
            id: 'seed_pearl_1',
            title: '💡 Perle du Jour : Hyponatrémie sévère',
            message: 'Règle vitale : Ne jamais dépasser 8-10 mmol/L de correction en 24h',
            type: NotificationType.pearl,
            createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
          MedicalNotification(
            id: 'seed_cat_1',
            title: '🚨 Nouvelle CAT : Prise en charge SCA ST+ (IDM)',
            message: 'Consensus national UMC & SFMU mis à jour',
            type: NotificationType.cat,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          MedicalNotification(
            id: 'seed_qcm_1',
            title: '🎯 Nouvelle Banque QCM : Cardiologie Blida 2024',
            message: '340 QCMs classés avec corrections détaillées ajoutés',
            type: NotificationType.qcm,
            createdAt: DateTime.now().subtract(const Duration(hours: 6)),
          ),
        ]);
      }

      _setNotifications(items);
    } catch (e) {
      debugPrint('Error loading initial notifications: $e');
    }
  }

  void _subscribeToRealtime() {
    try {
      final client = SupabaseService.client;

      // 1. Realtime on daily_pearls (INSERT)
      _pearlChannel = client
          .channel('public:daily_pearls')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'daily_pearls',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final notif = MedicalNotification(
                id: 'pearl_${newRecord['id'] ?? DateTime.now().millisecondsSinceEpoch}',
                title: '💡 Nouvelle Perle du Jour publiée !',
                message: '${newRecord['title'] ?? 'Perle Clinique'} • ${newRecord['module_name'] ?? ''}',
                type: NotificationType.pearl,
                createdAt: DateTime.now(),
                targetId: newRecord['id']?.toString(),
                metadata: newRecord,
              );
              _pushNewNotification(notif);
            },
          )
          .subscribe();

      // 2. Realtime on clinical_protocols (INSERT / UPDATE)
      _protocolChannel = client
          .channel('public:clinical_protocols')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'clinical_protocols',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final notif = MedicalNotification(
                id: 'cat_${newRecord['id'] ?? DateTime.now().millisecondsSinceEpoch}',
                title: '🚨 Nouvelle CAT Urgence Ajoutée !',
                message: '${newRecord['title'] ?? 'Protocole d\'Urgence'} (${newRecord['urgency_level'] ?? 'Clinique'})',
                type: NotificationType.cat,
                createdAt: DateTime.now(),
                targetId: newRecord['id']?.toString(),
                metadata: newRecord,
              );
              _pushNewNotification(notif);
            },
          )
          .subscribe();

      // 3. Realtime on courses (INSERT)
      _courseChannel = client
          .channel('public:courses')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'courses',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final notif = MedicalNotification(
                id: 'course_${newRecord['id'] ?? DateTime.now().millisecondsSinceEpoch}',
                title: '📚 Nouveau Cours Officiel Ajouté !',
                message: '${newRecord['name'] ?? 'Nouveau cours'} • Consultez le catalogue',
                type: NotificationType.course,
                createdAt: DateTime.now(),
                targetId: newRecord['id']?.toString(),
                metadata: newRecord,
              );
              _pushNewNotification(notif);
            },
          )
          .subscribe();

      // 4. Realtime on qcm_questions (INSERT)
      _qcmChannel = client
          .channel('public:qcm_questions')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'qcm_questions',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final notif = MedicalNotification(
                id: 'qcm_${newRecord['id'] ?? DateTime.now().millisecondsSinceEpoch}',
                title: '🎯 Nouveaux QCMs de Concours Ajoutés !',
                message: 'Nouvelle série de questions d\'entraînement disponible dans la banque.',
                type: NotificationType.qcm,
                createdAt: DateTime.now(),
                targetId: newRecord['id']?.toString(),
                metadata: newRecord,
              );
              _pushNewNotification(notif);
            },
          )
          .subscribe();

      // 5. General medical_notifications (INSERT) if created
      _notificationChannel = client
          .channel('public:medical_notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'medical_notifications',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final notif = MedicalNotification.fromJson(newRecord);
              _pushNewNotification(notif);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Supabase realtime subscription notice: $e');
    }
  }

  void _pushNewNotification(MedicalNotification notification) {
    final currentList = List<MedicalNotification>.from(notificationsNotifier.value);
    // Avoid duplicate IDs
    if (!currentList.any((n) => n.id == notification.id)) {
      currentList.insert(0, notification);
      _setNotifications(currentList);
      _newNotificationController.add(notification);
    }
  }

  void _setNotifications(List<MedicalNotification> list) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notificationsNotifier.value = list;
    unreadCountNotifier.value = list.where((n) => !n.isRead).length;
  }

  void markAllAsRead() {
    final updated = notificationsNotifier.value
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _setNotifications(updated);
  }

  void markAsRead(String id) {
    final updated = notificationsNotifier.value
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    _setNotifications(updated);
  }

  void addSimulatedNotification(MedicalNotification notif) {
    _pushNewNotification(notif);
  }

  void dispose() {
    _pearlChannel?.unsubscribe();
    _protocolChannel?.unsubscribe();
    _courseChannel?.unsubscribe();
    _qcmChannel?.unsubscribe();
    _notificationChannel?.unsubscribe();
    _newNotificationController.close();
  }
}

