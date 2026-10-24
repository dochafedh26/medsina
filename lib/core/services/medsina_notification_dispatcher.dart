import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/supabase_service.dart';

/// Centralized service for Google Drive Archival & Automated Email Notifications.
class MedsinaNotificationDispatcher {
  static const String _webhookPrefKey = 'medsina_gdrive_email_webhook_url';
  static const String defaultSecret = 'MSN27_STORAGE_SECURE_TOKEN_2026';
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Get configured Webhook URL from SharedPreferences or Cloud Settings
  static Future<String?> getWebhookUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_webhookPrefKey);
      if (cached != null && cached.isNotEmpty) return cached;

      // Cloud fallback from admin_system_settings
      final cloudUrl = await SupabaseService.getAdminSetting('medsina_gdrive_email_webhook_url') ??
          await SupabaseService.getAdminSetting('gdrive_webhook_url');
      if (cloudUrl != null && cloudUrl.isNotEmpty) {
        await prefs.setString(_webhookPrefKey, cloudUrl);
        return cloudUrl;
      }
    } catch (e) {
      debugPrint('Notice getting webhook URL: $e');
    }
    return null;
  }

  /// Save configured Webhook URL
  static Future<void> setWebhookUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webhookPrefKey, url.trim());
    try {
      await SupabaseService.saveAdminSetting(
        'medsina_gdrive_email_webhook_url',
        url.trim(),
        description: 'Google Apps Script Webhook URL for emails & Google Drive archival',
      );
    } catch (_) {}
  }

  /// 0a. NOTIFY CANDIDATE: Send Welcome Email when a new account is created
  static Future<void> sendWelcomeEmail({
    required String userEmail,
    required String userName,
    String? medicalRole,
    String? faculty,
    int? studyYear,
  }) async {
    final webhook = await getWebhookUrl();
    if (webhook == null || webhook.isEmpty) {
      debugPrint('MedsinaNotificationDispatcher: No webhook configured, skipping welcome email.');
      return;
    }

    try {
      await _dio.post(
        webhook,
        data: {
          'secret': defaultSecret,
          'action': 'send_email',
          'email_type': 'welcome',
          'recipient': userEmail,
          'user_name': userName,
          'medical_role': medicalRole ?? 'Médecin',
          'faculty': faculty ?? 'Faculté de Médecine de Blida',
          'study_year': studyYear,
        },
      );
    } catch (e) {
      debugPrint('Error sending welcome email via webhook: $e');
    }
  }

  /// 0b. NOTIFY ADMIN: Send Alert Email when a new user registers on Medsina
  static Future<void> notifyAdminNewSubscriber({
    required String userEmail,
    required String userName,
    String? medicalRole,
    String? faculty,
    int? studyYear,
  }) async {
    final webhook = await getWebhookUrl();
    if (webhook == null || webhook.isEmpty) {
      debugPrint('MedsinaNotificationDispatcher: No webhook configured, skipping admin new subscriber email.');
      return;
    }

    try {
      await _dio.post(
        webhook,
        data: {
          'secret': defaultSecret,
          'action': 'send_email',
          'email_type': 'admin_new_subscriber',
          'user_name': userName,
          'user_email': userEmail,
          'medical_role': medicalRole ?? 'Médecin',
          'faculty': faculty ?? 'Faculté de Médecine de Blida',
          'study_year': studyYear,
          'registered_at': DateTime.now().toLocal().toString().split('.').first,
        },
      );
    } catch (e) {
      debugPrint('Error notifying admin of new subscriber via webhook: $e');
    }
  }

  /// 1. NOTIFY ADMIN: Send Admin Alert email when a new payment request is submitted
  static Future<void> notifyAdminNewPayment({
    required String userName,
    required String userEmail,
    required String tier,
    required double amount,
    required String paymentMethod,
    required String receiptReference,
  }) async {
    final webhook = await getWebhookUrl();
    if (webhook == null || webhook.isEmpty) {
      debugPrint('MedsinaNotificationDispatcher: No webhook configured, skipping email alert.');
      return;
    }

    try {
      await _dio.post(
        webhook,
        data: {
          'secret': defaultSecret,
          'action': 'send_email',
          'email_type': 'admin_new_payment',
          'user_name': userName,
          'user_email': userEmail,
          'tier': tier,
          'amount': amount.toStringAsFixed(0),
          'payment_method': paymentMethod,
          'receipt_reference': receiptReference,
        },
      );
    } catch (e) {
      debugPrint('Error notifying admin via webhook: $e');
    }
  }

  /// 2. NOTIFY CANDIDATE: Send Payment Approved & Subscription Activated email
  static Future<void> sendCandidatePaymentApprovedEmail({
    required String userEmail,
    required String userName,
    required String tierName,
    required int durationDays,
    required DateTime expiryDate,
    required double amount,
  }) async {
    final webhook = await getWebhookUrl();
    if (webhook == null || webhook.isEmpty) return;

    try {
      await _dio.post(
        webhook,
        data: {
          'secret': defaultSecret,
          'action': 'send_email',
          'email_type': 'approved',
          'recipient': userEmail,
          'user_name': userName,
          'tier_name': tierName,
          'duration_days': durationDays,
          'expiry_date': '${expiryDate.day}/${expiryDate.month}/${expiryDate.year}',
          'amount': amount.toStringAsFixed(0),
        },
      );
    } catch (e) {
      debugPrint('Error sending approved email: $e');
    }
  }

  /// 3. NOTIFY CANDIDATE: Send Payment Rejected warning email
  static Future<void> sendCandidatePaymentRejectedEmail({
    required String userEmail,
    required String userName,
    required String reason,
    required int rejectedCount,
  }) async {
    final webhook = await getWebhookUrl();
    if (webhook == null || webhook.isEmpty) return;

    try {
      await _dio.post(
        webhook,
        data: {
          'secret': defaultSecret,
          'action': 'send_email',
          'email_type': 'rejected',
          'recipient': userEmail,
          'user_name': userName,
          'reason': reason,
          'rejected_count': rejectedCount,
        },
      );
    } catch (e) {
      debugPrint('Error sending rejected email: $e');
    }
  }

  /// 4. NOTIFY CANDIDATE: Send Account Suspended email (3 strikes reached)
  static Future<void> sendCandidateAccountBannedEmail({
    required String userEmail,
    required String userName,
    required String reason,
  }) async {
    final webhook = await getWebhookUrl();
    if (webhook == null || webhook.isEmpty) return;

    try {
      await _dio.post(
        webhook,
        data: {
          'secret': defaultSecret,
          'action': 'send_email',
          'email_type': 'banned',
          'recipient': userEmail,
          'user_name': userName,
          'reason': reason,
        },
      );
    } catch (e) {
      debugPrint('Error sending banned email: $e');
    }
  }

  /// 5. ARCHIVE REJECTED RECEIPT IMMEDIATELY TO GOOGLE DRIVE
  /// Uploads to 'Medsina - Reçus Rejetés' on Google Drive and deletes from Supabase Storage
  static Future<String?> archiveRejectedReceiptImmediately({
    required String paymentId,
    required String? receiptUrl,
    required String? receiptFileName,
    required String userName,
  }) async {
    if (receiptUrl == null || receiptUrl.isEmpty) return null;

    final webhook = await getWebhookUrl();
    String? driveUrl;

    if (webhook != null && webhook.isNotEmpty) {
      try {
        final cleanName = receiptFileName ?? 'recu_rejete.pdf';
        final resp = await _dio.post(
          webhook,
          data: {
            'secret': defaultSecret,
            'action': 'archive_receipt',
            'folder_type': 'rejected',
            'file_name': '[REJETE]_${DateTime.now().millisecondsSinceEpoch}_$cleanName',
            'file_url': receiptUrl.startsWith('http') ? receiptUrl : null,
            'file_base64': receiptUrl.startsWith('data:') ? receiptUrl.split(',').last : null,
          },
        );

        if (resp.statusCode == 200 && resp.data is Map) {
          final data = resp.data as Map<String, dynamic>;
          if (data['success'] == true) {
            driveUrl = data['file_url'];
          }
        }
      } catch (e) {
        debugPrint('Error archiving rejected receipt to Google Drive: $e');
      }
    }

    // Fallback or Drive URL registered in database
    final finalDriveUrl = driveUrl ?? receiptUrl;
    await SupabaseService.markReceiptArchived(
      paymentId: paymentId,
      driveUrl: finalDriveUrl,
      folder: 'Medsina - Reçus Rejetés',
    );

    // Delete physically from Supabase Storage to keep quota free
    if (receiptUrl.contains('/receipts/')) {
      await SupabaseService.deleteReceiptFileFromStorage(receiptUrl);
    }

    return driveUrl;
  }

  /// 6. BATCH ARCHIVE APPROVED RECEIPTS OLDER THAN 30 DAYS
  /// Moves eligible receipts from Supabase Storage to Google Drive and cleans storage
  static Future<int> archiveApprovedReceiptsOlderThanDays({int retentionDays = 30}) async {
    final eligible = await SupabaseService.fetchReceiptsEligibleForArchival(retentionDays);
    if (eligible.isEmpty) return 0;

    final webhook = await getWebhookUrl();
    int archivedCount = 0;

    for (final p in eligible) {
      final paymentId = p['id']?.toString() ?? '';
      final receiptUrl = p['receipt_url']?.toString() ?? '';
      final fileName = p['receipt_file_name']?.toString() ?? 'recu_valide.pdf';

      if (paymentId.isEmpty || receiptUrl.isEmpty) continue;

      String? driveUrl;
      if (webhook != null && webhook.isNotEmpty) {
        try {
          final resp = await _dio.post(
            webhook,
            data: {
              'secret': defaultSecret,
              'action': 'archive_receipt',
              'folder_type': 'validated',
              'file_name': '[VALIDE]_${DateTime.now().millisecondsSinceEpoch}_$fileName',
              'file_url': receiptUrl.startsWith('http') ? receiptUrl : null,
              'file_base64': receiptUrl.startsWith('data:') ? receiptUrl.split(',').last : null,
            },
          );

          if (resp.statusCode == 200 && resp.data is Map) {
            final data = resp.data as Map<String, dynamic>;
            if (data['success'] == true) {
              driveUrl = data['file_url'];
            }
          }
        } catch (e) {
          debugPrint('Error archiving payment $paymentId: $e');
        }
      }

      final finalDriveUrl = driveUrl ?? receiptUrl;
      await SupabaseService.markReceiptArchived(
        paymentId: paymentId,
        driveUrl: finalDriveUrl,
        folder: 'Medsina - Reçus Validés (Archives 30j)',
      );

      // Delete from Supabase Storage bucket
      if (receiptUrl.contains('/receipts/')) {
        await SupabaseService.deleteReceiptFileFromStorage(receiptUrl);
      }

      archivedCount++;
    }

    return archivedCount;
  }
}
