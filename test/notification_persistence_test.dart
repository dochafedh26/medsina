import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medsina/features/notifications/models/medical_notification.dart';
import 'package:medsina/features/notifications/services/realtime_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('User-dependent notification persistence across multiple accounts', () async {
    final service = RealtimeNotificationService.instance;

    // 1. Initialize for User A ('dr_amine')
    await service.initialize(userId: 'user_amine_123');

    expect(service.notifications.isNotEmpty, true);
    final firstNotifId = service.notifications.first.id;

    // User A has unread notifications
    final initialUnread = service.unreadCount;
    expect(initialUnread > 0, true);

    // User A marks the first notification as read
    await service.markAsRead(firstNotifId);
    expect(service.unreadCount, equals(initialUnread - 1));
    expect(service.notifications.firstWhere((n) => n.id == firstNotifId).isRead, true);

    // Verify SharedPreferences contains the persisted key for User A
    final prefs = await SharedPreferences.getInstance();
    final amineReadList = prefs.getStringList('medsina_read_notifs_user_amine_123');
    expect(amineReadList, contains(firstNotifId));

    // 2. Switch to User B ('dr_yasmine')
    await service.setCurrentUser('user_yasmine_456');

    // For User B, that notification must NOT be marked as read
    final yasmineFirstNotif = service.notifications.firstWhere((n) => n.id == firstNotifId);
    expect(yasmineFirstNotif.isRead, false);
    expect(service.unreadCount, equals(initialUnread));

    // User B marks all as read
    await service.markAllAsRead();
    expect(service.unreadCount, equals(0));

    // Verify SharedPreferences for User B
    final yasmineReadList = prefs.getStringList('medsina_read_notifs_user_yasmine_456');
    expect(yasmineReadList!.length, equals(service.notifications.length));

    // 3. Switch back to User A
    await service.setCurrentUser('user_amine_123');

    // User A should still only have firstNotifId marked as read!
    final amineRestoredFirstNotif = service.notifications.firstWhere((n) => n.id == firstNotifId);
    expect(amineRestoredFirstNotif.isRead, true);
    expect(service.unreadCount, equals(initialUnread - 1));
  });

  test('Notifications remain marked as read across simulated Hot-Restart', () async {
    final service = RealtimeNotificationService.instance;
    service.resetForTesting();

    // 1. App starts for Dr. Hafedh
    await service.initialize(userId: 'usr_demo_all_access');
    expect(service.notifications.isNotEmpty, true);
    final initialUnread = service.unreadCount;
    expect(initialUnread > 0, true);

    // 2. Doctor marks all notifications as read
    await service.markAllAsRead();
    expect(service.unreadCount, 0);
    expect(service.notifications.every((n) => n.isRead), true);

    // 3. User performs a HOT-RESTART:
    // Reset service state (simulates Dart VM reload)
    service.resetForTesting();

    // In main(), initialize is called (e.g. before auth resolves or with cached user)
    await service.initialize();

    // All notifications must REMAIN MARKED AS READ!
    expect(service.unreadCount, 0);
    expect(service.notifications.every((n) => n.isRead), true);

    // Once MainScaffold mounts and passes the user ID, it must still remain read!
    await service.setCurrentUser('usr_demo_all_access');
    expect(service.unreadCount, 0);
    expect(service.notifications.every((n) => n.isRead), true);
  });

  test('Course Summary and automated content notifications parse and broadcast correctly', () {
    final rawSummaryJson = {
      'id': 'notif_summary_cardio_sca_01',
      'title': '📖 Nouvelle Fiche Synthèse : SCA ST+ (IDM)',
      'message': 'La fiche de révision officielle du cours SCA ST+ est disponible avec points clés et pièges de concours !',
      'type': 'course',
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
      'target_id': 'cardio_sca_01',
      'metadata': {
        'course_id': 'cardio_sca_01',
        'course_name': 'SCA ST+ (IDM)',
        'module_name': 'Cardiologie',
      },
    };

    final notif = MedicalNotification.fromJson(rawSummaryJson);
    expect(notif.id, 'notif_summary_cardio_sca_01');
    expect(notif.type, NotificationType.course);
    expect(notif.targetId, 'cardio_sca_01');
    expect(notif.metadata?['module_name'], 'Cardiologie');

    // Test addition to RealtimeNotificationService
    final service = RealtimeNotificationService.instance;
    service.resetForTesting();
    service.addSimulatedNotification(notif);

    expect(service.notifications.length, 1);
    expect(service.unreadCount, 1);
    expect(service.notifications.first.title, contains('SCA ST+'));
  });

  test('Notification alert detection and extended types classify properly', () {
    final alertQuota = MedicalNotification(
      id: 'q1',
      title: 'Quota Journalier Épuisé (5/5)',
      message: 'Vous avez utilisé toutes vos requêtes IA gratuites du jour.',
      type: NotificationType.quota,
      createdAt: DateTime.now(),
    );
    expect(alertQuota.isAlert, true);
    expect(alertQuota.type.label, contains('Quota'));

    final alertSub = MedicalNotification(
      id: 's1',
      title: 'Votre abonnement Medsina expire dans 3 jours',
      message: 'Pensez à renouveler pour conserver votre accès illimité.',
      type: NotificationType.subscription,
      createdAt: DateTime.now(),
    );
    expect(alertSub.isAlert, true);
    expect(alertSub.type.label, contains('Abonnement'));

    final contentCat = MedicalNotification(
      id: 'c1',
      title: 'Nouvelle CAT Urgence : État de mal épileptique',
      message: 'Protocole complet révisé.',
      type: NotificationType.cat,
      createdAt: DateTime.now(),
    );
    expect(contentCat.isAlert, false);

    final contentDrug = MedicalNotification(
      id: 'd1',
      title: 'Médicament : Adrénaline injectable',
      message: 'Fiche urgence mise à jour.',
      type: NotificationType.drug,
      createdAt: DateTime.now(),
    );
    expect(contentDrug.isAlert, false);
    expect(contentDrug.type.label, contains('Médicament'));

    final contentMemento = MedicalNotification(
      id: 'm1',
      title: 'Mémento de Garde : Score de Glasgow',
      message: 'Fiche réflexe ajoutée.',
      type: NotificationType.memento,
      createdAt: DateTime.now(),
    );
    expect(contentMemento.isAlert, false);
    expect(contentMemento.type.label, contains('Mémento'));

    final announcement = MedicalNotification(
      id: 'announcement_4a8d8f5e',
      title: '📢 Accès gratuit',
      message: 'Un accès gratuit est offert aux 20 premiers abonnés.',
      type: NotificationType.announcement,
      createdAt: DateTime.now(),
      metadata: const {'type': 'success', 'is_active': true},
    );
    expect(announcement.isAlert, true);
    expect(announcement.type.label, contains('Annonce Système'));
  });
}
