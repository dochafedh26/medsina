import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Check if notification contains an AI prompt for Facebook
    final fullPrompt = notification.metadata?['full_prompt']?.toString();
    if (fullPrompt != null && fullPrompt.isNotEmpty) {
      await showFacebookPromptDialog(context, notification);
      return;
    }

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
    } else if (notif.isAdminOnly) {
      dialogIcon = Icons.admin_panel_settings_rounded;
      dialogColor = const Color(0xFF6366F1);
      actionLabel = 'J\'ai compris';
      onAction = () => Navigator.pop(context);
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
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  notif.message,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 14),
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
          ),
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
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} à ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> showFacebookPromptDialog(
    BuildContext context,
    MedicalNotification notif,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullPrompt = notif.metadata?['full_prompt']?.toString() ?? notif.message;
    final topic = notif.metadata?['topic']?.toString() ?? notif.title;
    final postType = notif.metadata?['post_type']?.toString() ?? 'auto';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign_rounded, color: Color(0xFF1877F2), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prompt IA pour Post Facebook',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'À copier dans Gemini, Claude ou ChatGPT',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1877F2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'THÈME : $topic',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1877F2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      postType.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.purple),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 340),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    fullPrompt,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.45,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copier le Prompt IA 📋', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullPrompt));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF16A34A),
                    content: Text('✅ Prompt IA complet copié dans le presse-papiers ! Collez-le dans Gemini, Claude ou ChatGPT.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
