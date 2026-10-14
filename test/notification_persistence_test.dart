import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
