import 'package:flutter/material.dart';
import '../../clinical/presentation/clinical_screen.dart';
import '../../dashboard/presentation/daily_pearls_archive_screen.dart';
import '../../practical_tools/presentation/practical_tools_screen.dart';
import '../../revision/data/residency_repository.dart';
import '../../revision/models/module_model.dart';
import '../../revision/presentation/course_summary_screen.dart';
import '../../revision/presentation/revision_catalog_screen.dart';
import '../../subscription/presentation/ai_pack_purchase_modal.dart';
import '../../subscription/presentation/subscription_paywall_screen.dart';
import '../models/medical_notification.dart';
import 'realtime_notification_service.dart';

class NotificationNavigationService {
  /// Handles tapping a notification across the app (ModalSheet, SnackBar, etc.)
  static Future<void> handleNotificationTap(
    BuildContext context,
    MedicalNotification notification, {
    bool closeCurrentModal = false,
  }) async {
    // 1. Mark as read immediately
    RealtimeNotificationService.instance.markAsRead(notification.id);

    // 2. Dismiss modal bottom sheet if opened
    if (closeCurrentModal && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (!context.mounted) return;

    // 3. If notification is an Alert / Subscription / Quota / Announcement -> Open Alert Dialog
    if (notification.isAlert) {
      await _showAlertNotificationDialog(context, notification);
      return;
    }

    // 4. Route according to medical content type
    switch (notification.type) {
      case NotificationType.course:
        await _navigateToCourse(context, notification);
        break;
      case NotificationType.cat:
        await _navigateToCat(context, notification);
        break;
      case NotificationType.pearl:
        await _showPearlDialog(context, notification);
        break;
      case NotificationType.memento:
        await _navigateToMemento(context, notification);
        break;
      case NotificationType.drug:
        await _navigateToDrug(context, notification);
        break;
      case NotificationType.qcm:
        await _navigateToQcm(context, notification);
        break;
      case NotificationType.quota:
      case NotificationType.subscription:
      case NotificationType.announcement:
        await _showAlertNotificationDialog(context, notification);
        break;
    }
  }

  // --- CONTENT NAVIGATION HANDLERS ---

  static Future<void> _navigateToCourse(
    BuildContext context,
    MedicalNotification notif,
  ) async {
    CourseModel? course;
    if (notif.targetId != null && notif.targetId!.isNotEmpty) {
      course = await ResidencyRepository.findCourseById(notif.targetId!);
    }
    if (course == null) {
      final cleanName = notif.title
          .replaceAll(RegExp(r'^(nouveau\s*cours|résumé|cours)\s*:?\s*', caseSensitive: false), '')
          .trim();
      course = await ResidencyRepository.findCourseByNameOrId(cleanName);
    }

    // Fallback if course not found in catalog, construct minimal model so CourseSummaryScreen can fetch summary
    course ??= CourseModel(
      id: notif.targetId ?? 'notif_course_${DateTime.now().millisecondsSinceEpoch}',
      moduleId: notif.metadata?['module_id']?.toString() ?? 'general',
      name: notif.title.replaceAll(RegExp(r'^(nouveau\s*cours|résumé)\s*:?\s*', caseSensitive: false), '').trim(),
      questionsCount: 0,
    );

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourseSummaryScreen(course: course!),
        ),
      );
    }
  }

  static Future<void> _navigateToCat(
    BuildContext context,
    MedicalNotification notif,
  ) async {
    final target = notif.targetId ??
        notif.title.replaceAll(RegExp(r'^(nouvelle\s*cat|cat|urgence)\s*:?\s*', caseSensitive: false), '').trim();
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClinicalScreen(
            initialTabIndex: 0,
            targetProtocolId: target,
          ),
        ),
      );
    }
  }

  static Future<void> _navigateToMemento(
    BuildContext context,
    MedicalNotification notif,
  ) async {
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PracticalToolsScreen(initialTabIndex: 2),
        ),
      );
    }
  }

  static Future<void> _navigateToDrug(
    BuildContext context,
    MedicalNotification notif,
  ) async {
    final target = notif.targetId ??
        notif.title.replaceAll(RegExp(r'^(médicament|urgence)\s*:?\s*', caseSensitive: false), '').trim();
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClinicalScreen(
            initialTabIndex: 1,
            targetDrugQuery: target,
          ),
        ),
      );
    }
  }

  static Future<void> _navigateToQcm(
    BuildContext context,
    MedicalNotification notif,
  ) async {
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const RevisionCatalogScreen(),
        ),
      );
    }
  }

  // --- DIALOGS FOR ALERTS, PEARLS & ANNOUNCEMENTS ---

  static Future<void> _showAlertNotificationDialog(
    BuildContext context,
    MedicalNotification notif,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isQuota = notif.type == NotificationType.quota ||
        notif.title.toLowerCase().contains('quota') ||
        notif.message.toLowerCase().contains('quota');
    final isSub = notif.type == NotificationType.subscription ||
        notif.title.toLowerCase().contains('abonnement') ||
        notif.title.toLowerCase().contains('expiration') ||
        notif.message.toLowerCase().contains('abonnement');

    IconData dialogIcon;
    Color dialogColor;
    String actionLabel;
    VoidCallback? onAction;

    if (isQuota) {
      dialogIcon = Icons.bolt_rounded;
      dialogColor = const Color(0xFFF97316);
      actionLabel = 'Recharger Quotas 🚀';
      onAction = () {
        Navigator.pop(context);
        AiPackPurchaseModal.show(context);
      };
    } else if (isSub) {
      dialogIcon = Icons.workspace_premium_rounded;
      dialogColor = const Color(0xFF6366F1);
      actionLabel = 'Renouveler mon Abonnement 💎';
      onAction = () {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
        );
      };
    } else {
      dialogIcon = Icons.campaign_rounded;
      dialogColor = const Color(0xFF14B8A6);
      actionLabel = 'J\'ai compris';
      onAction = () => Navigator.pop(context);
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: dialogColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(dialogIcon, color: dialogColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notif.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notif.message,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  _formatDateTime(notif.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          if (onAction != null && actionLabel != 'J\'ai compris')
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onAction,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  static Future<void> _showPearlDialog(
    BuildContext context,
    MedicalNotification notif,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notif.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
              ),
              child: Text(
                notif.message,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.archive_rounded, size: 16),
            label: const Text('Toutes les Perles 📚'),
            onPressed: () {
              Navigator.pop(ctx);
              DailyPearlsArchiveScreen.navigateTo(context);
            },
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
