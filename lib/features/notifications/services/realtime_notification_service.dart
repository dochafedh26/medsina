import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/medical_notification.dart';

class RealtimeNotificationService {
  static final RealtimeNotificationService instance = RealtimeNotificationService._internal();
  RealtimeNotificationService._internal();

  final ValueNotifier<List<MedicalNotification>> notificationsNotifier =
      ValueNotifier<List<MedicalNotification>>([]);
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  List<MedicalNotification> get notifications => notificationsNotifier.value;
  int get unreadCount => unreadCountNotifier.value;

  // Broadcast stream controller for in-app alert toasts / snackbars
  final StreamController<MedicalNotification> _newNotificationController =
      StreamController<MedicalNotification>.broadcast();
  Stream<MedicalNotification> get onNewNotification => _newNotificationController.stream;

  RealtimeChannel? _pearlChannel;
  RealtimeChannel? _protocolChannel;
  RealtimeChannel? _courseChannel;
  RealtimeChannel? _summaryChannel;
  RealtimeChannel? _qcmChannel;
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _readsChannel;

  bool _initialized = false;
  String? _currentUserId;
  Set<String> _readIds = {};

  String _getStorageKey(String? userId) => 'medsina_read_notifs_${userId ?? 'anonymous'}';

  Future<void> initialize({String? userId}) async {
    _currentUserId = userId;
    await _loadUserReadIds();

    if (_initialized) {
      _applyReadIds();
      return;
    }
    _initialized = true;

    // Load initial seed notifications (including recent daily pearl, CATs, etc.)
    await _loadInitialNotifications();

    // Subscribe to Supabase Realtime channels
    _subscribeToRealtime();
  }

  /// Changes the active user context and re-applies their specific read status
  Future<void> setCurrentUser(String? userId) async {
    _currentUserId = userId;
    await _loadUserReadIds();
    _applyReadIds();
  }

  Future<void> _loadUserReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = _getStorageKey(_currentUserId);
      final userList = prefs.getStringList(userKey) ?? [];
      
      // If current user has a specific account, merge any read IDs marked during anonymous session
      if (_currentUserId != null && _currentUserId != 'anonymous') {
        final anonymousList = prefs.getStringList(_getStorageKey(null)) ?? [];
        _readIds = {...userList, ...anonymousList};
        if (anonymousList.isNotEmpty) {
          // Persist the combined set for the user
          await prefs.setStringList(userKey, _readIds.toList());
        }
      } else {
        final lastActive = prefs.getStringList('medsina_last_active_read_notifs') ?? [];
        _readIds = {...userList, ...lastActive};
      }
    } catch (e) {
      debugPrint('Error loading user read notification IDs: $e');
      _readIds = {};
    }

    // Cloud Reconciliation: Asynchronously fetch read notification IDs from Supabase
    if (_currentUserId != null && !_currentUserId!.startsWith('usr_demo_') && _currentUserId != 'anonymous') {
      try {
        final cloudReads = await SupabaseService.fetchCloudReadNotificationIds(_currentUserId);
        if (cloudReads.isNotEmpty) {
          _readIds.addAll(cloudReads);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_getStorageKey(_currentUserId), _readIds.toList());
          _applyReadIds();
        }
      } catch (e) {
        debugPrint('Cloud read notification reconciliation notice: $e');
      }
    }
  }

  Future<void> _saveUserReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = _getStorageKey(_currentUserId);
      final list = _readIds.toList();
      await prefs.setStringList(userKey, list);
      // If logged in, also mirror to last active read cache so hot-restart before auth always stays read
      await prefs.setStringList('medsina_last_active_read_notifs', list);
      if (_currentUserId == null || _currentUserId == 'anonymous') {
        await prefs.setStringList(_getStorageKey(null), list);
      }
    } catch (e) {
      debugPrint('Error saving user read notification IDs: $e');
    }
  }

  void _applyReadIds() {
    final currentList = notificationsNotifier.value;
    if (currentList.isEmpty) return;

    final updated = currentList.map((n) {
      final isRead = _readIds.contains(n.id);
      return n.copyWith(isRead: isRead);
    }).toList();

    _setNotifications(updated);
  }

  Future<void> _loadInitialNotifications() async {
    final List<MedicalNotification> items = [];
    try {
      final client = SupabaseService.client;

      // 0. Fetch centralized broadcast notifications from Supabase Cloud
      try {
        final cloudNotifs = await SupabaseService.fetchCloudMedicalNotifications();
        for (final row in cloudNotifs) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            final notif = MedicalNotification.fromJson(row).copyWith(
              isRead: _readIds.contains(id),
            );
            items.add(notif);
          }
        }
      } catch (e) {
        debugPrint('Supabase cloud medical_notifications load notice: $e');
      }

      // 1. Fetch recent daily pearls (last 3)
      try {
        final pearls = await client
            .from('daily_pearls')
            .select()
            .order('created_at', ascending: false)
            .limit(3);

        for (final p in pearls) {
          final id = 'pearl_${p['id']}';
          if (!items.any((n) => n.id == id)) {
            items.add(MedicalNotification(
              id: id,
              title: '💡 ${p['title'] ?? 'Nouvelle Perle du Jour'}',
              message: '${p['course_name']} • ${p['module_name']}',
              type: NotificationType.pearl,
              createdAt: DateTime.tryParse(p['created_at'].toString()) ?? DateTime.now(),
              targetId: p['id']?.toString(),
              metadata: p,
              isRead: _readIds.contains(id),
            ));
          }
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
          final id = 'course_${c['id']}';
          if (!items.any((n) => n.id == id)) {
            items.add(MedicalNotification(
              id: id,
              title: '📖 Nouveau Cours Disponible',
              message: '${c['name']}',
              type: NotificationType.course,
              createdAt: c['created_at'] != null
                  ? DateTime.tryParse(c['created_at'].toString()) ?? DateTime.now()
                  : DateTime.now().subtract(const Duration(hours: 4)),
              targetId: c['id']?.toString(),
              isRead: _readIds.contains(id),
            ));
          }
        }
      } catch (e) {
        debugPrint('Supabase courses init load notice: $e');
      }

      // 3. Fetch recent course summaries (last 3)
      try {
        final summaries = await client
            .from('course_summaries')
            .select('course_id, course_name, module_name, updated_at')
            .order('updated_at', ascending: false)
            .limit(3);

        for (final s in summaries) {
          final id = 'notif_summary_${s['course_id']}';
          if (!items.any((n) => n.id == id)) {
            items.add(MedicalNotification(
              id: id,
              title: '📖 Fiche Synthèse : ${s['course_name'] ?? 'Résumé de cours'}',
              message: '${s['course_name']} (${s['module_name'] ?? 'Programme Résidanat'})',
              type: NotificationType.course,
              createdAt: s['updated_at'] != null
                  ? DateTime.tryParse(s['updated_at'].toString()) ?? DateTime.now()
                  : DateTime.now().subtract(const Duration(hours: 1)),
              targetId: s['course_id']?.toString(),
              metadata: s,
              isRead: _readIds.contains(id),
            ));
          }
        }
      } catch (e) {
        debugPrint('Supabase course_summaries init load notice: $e');
      }
    } catch (e) {
      debugPrint('Supabase initial load notice: $e');
    }

    // Always ensure at least 1 Daily Pearl notification is available
    final hasPearl = items.any((n) => n.type == NotificationType.pearl);
    if (!hasPearl) {
      try {
        final latest = await SupabaseService.fetchLatestDailyPearl();
        if (latest != null) {
          final id = 'pearl_${latest['id'] ?? 'seed_pearl_1'}';
          items.add(MedicalNotification(
            id: id,
            title: '💡 ${latest['title'] ?? 'Perle du Jour'}',
            message: '${latest['course_name'] ?? 'Clinique'} • ${latest['module_name'] ?? 'Résidanat'}',
            type: NotificationType.pearl,
            createdAt: latest['created_at'] != null
                ? DateTime.tryParse(latest['created_at'].toString()) ?? DateTime.now()
                : DateTime.now().subtract(const Duration(minutes: 30)),
            targetId: latest['id']?.toString(),
            metadata: latest,
            isRead: _readIds.contains(id),
          ));
        }
      } catch (_) {}
    }

    // Always ensure at least 1 Urgent CAT protocol notification is available
    final hasCat = items.any((n) => n.type == NotificationType.cat);
    if (!hasCat) {
      const catId = 'seed_cat_1';
      items.add(MedicalNotification(
        id: catId,
        title: '🚨 Nouvelle CAT : Prise en charge SCA ST+ (IDM)',
        message: 'Consensus national UMC & SFMU mis à jour',
        type: NotificationType.cat,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: _readIds.contains(catId),
      ));
    }

    // Always ensure at least 1 QCM bank notification is available
    final hasQcm = items.any((n) => n.type == NotificationType.qcm);
    if (!hasQcm) {
      const qcmId = 'seed_qcm_1';
      items.add(MedicalNotification(
        id: qcmId,
        title: '🎯 Nouvelle Banque QCM : Cardiologie Blida 2024',
        message: '340 QCMs classés avec corrections détaillées ajoutés',
        type: NotificationType.qcm,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        isRead: _readIds.contains(qcmId),
      ));
    }

    _setNotifications(items);
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
              final id = 'pearl_${newRecord['id'] ?? DateTime.now().millisecondsSinceEpoch}';
              final notif = MedicalNotification(
                id: id,
                title: '💡 Nouvelle Perle du Jour publiée !',
                message: '${newRecord['title'] ?? 'Perle Clinique'} • ${newRecord['module_name'] ?? ''}',
                type: NotificationType.pearl,
                createdAt: DateTime.now(),
                targetId: newRecord['id']?.toString(),
                metadata: newRecord,
                isRead: _readIds.contains(id),
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
              final id = 'cat_${newRecord['id'] ?? DateTime.now().millisecondsSinceEpoch}';
              final notif = MedicalNotification(
                id: id,
                title: '🚨 Nouvelle CAT Urgence Ajoutée !',
                message: '${newRecord['title'] ?? 'Protocole d\'Urgence'} (${newRecord['urgency_level'] ?? 'Clinique'})',
                type: NotificationType.cat,
                createdAt: DateTime.now(),
                targetId: newRecord['id']?.toString(),
                metadata: newRecord,
                isRead: _readIds.contains(id),
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
              final id = 'course_${newRecord['id'] ?? DateTime.now().millisecondsSinceEpoch}';
              final notif = MedicalNotification(
                id: id,
                title: '📚 Nouveau Cours Officiel Ajouté !',
                message: '${newRecord['name'] ?? 'Nouveau cours'} • Consultez le catalogue',
                type: NotificationType.course,
                createdAt: DateTime.now(),
                targetId: newRecord['id']?.toString(),
                metadata: newRecord,
                isRead: _readIds.contains(id),
              );
              _pushNewNotification(notif);
            },
          )
          .subscribe();

      // 3b. Realtime on course_summaries (INSERT / UPDATE)
      _summaryChannel = client
          .channel('public:course_summaries')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'course_summaries',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isEmpty) return;
              final courseId = newRecord['course_id']?.toString() ?? '${DateTime.now().millisecondsSinceEpoch}';
              final id = 'notif_summary_$courseId';
              final courseName = newRecord['course_name'] ?? 'Nouveau cours';
              final moduleName = newRecord['module_name'] ?? 'Résidanat';
              final notif = MedicalNotification(
                id: id,
                title: '📖 Nouvelle Fiche Synthèse : $courseName',
                message: 'La fiche de révision officielle pour "$courseName" ($moduleName) est disponible avec points clés et pièges de concours !',
                type: NotificationType.course,
                createdAt: DateTime.now(),
                targetId: courseId,
                metadata: newRecord,
                isRead: _readIds.contains(id),
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
              final id = 'qcm_${newRecord['id'] ?? DateTime.now().millisecondsSinceEpoch}';
              final notif = MedicalNotification(
                id: id,
                title: '🎯 Nouveaux QCMs de Concours Ajoutés !',
                message: 'Nouvelle série de questions d\'entraînement disponible dans la banque.',
                type: NotificationType.qcm,
                createdAt: DateTime.now(),
                targetId: newRecord['id']?.toString(),
                metadata: newRecord,
                isRead: _readIds.contains(id),
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
              final withReadStatus = notif.copyWith(isRead: _readIds.contains(notif.id));
              _pushNewNotification(withReadStatus);
            },
          )
          .subscribe();

      // 6. Realtime sync on user_notification_reads (cross-device read sync)
      _readsChannel = client
          .channel('public:user_notification_reads')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'user_notification_reads',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final notifId = newRecord['notification_id']?.toString();
              final readUserId = newRecord['user_id']?.toString();
              if (notifId != null && readUserId == _currentUserId && !_readIds.contains(notifId)) {
                _readIds.add(notifId);
                _saveUserReadIds();
                _applyReadIds();
              }
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
      final effectiveNotif = notification.copyWith(isRead: _readIds.contains(notification.id));
      currentList.insert(0, effectiveNotif);
      _setNotifications(currentList);
      if (!effectiveNotif.isRead) {
        _newNotificationController.add(effectiveNotif);
      }
    }
  }

  void _setNotifications(List<MedicalNotification> list) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notificationsNotifier.value = list;
    unreadCountNotifier.value = list.where((n) => !n.isRead).length;
  }

  Future<void> markAllAsRead() async {
    final allIds = <String>[];
    for (final n in notificationsNotifier.value) {
      _readIds.add(n.id);
      allIds.add(n.id);
    }
    await _saveUserReadIds();
    final updated = notificationsNotifier.value
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _setNotifications(updated);

    // Persist to Supabase Cloud asynchronously
    if (_currentUserId != null && !_currentUserId!.startsWith('usr_demo_') && _currentUserId != 'anonymous') {
      unawaited(SupabaseService.markAllNotificationsReadOnCloud(allIds, userId: _currentUserId));
    }
  }

  Future<void> markAsRead(String id) async {
    _readIds.add(id);
    await _saveUserReadIds();
    final updated = notificationsNotifier.value
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    _setNotifications(updated);

    // Persist to Supabase Cloud asynchronously
    if (_currentUserId != null && !_currentUserId!.startsWith('usr_demo_') && _currentUserId != 'anonymous') {
      unawaited(SupabaseService.markNotificationReadOnCloud(id, userId: _currentUserId));
    }
  }

  void addSimulatedNotification(MedicalNotification notif) {
    _pushNewNotification(notif);
  }

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _currentUserId = null;
    _readIds = {};
    notificationsNotifier.value = [];
    unreadCountNotifier.value = 0;
  }

  void dispose() {
    _pearlChannel?.unsubscribe();
    _protocolChannel?.unsubscribe();
    _courseChannel?.unsubscribe();
    _summaryChannel?.unsubscribe();
    _qcmChannel?.unsubscribe();
    _notificationChannel?.unsubscribe();
    _readsChannel?.unsubscribe();
    _newNotificationController.close();
  }
}
