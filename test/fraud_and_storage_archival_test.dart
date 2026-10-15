import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/core/constants/app_constants.dart';
import 'package:medsina/features/auth/models/user_model.dart';
import 'package:medsina/features/admin/models/admin_models.dart';

void main() {
  group('Fraud Protection & User Ban Tests', () {
    test('UserModel marks subscription inactive and daysRemaining 0 when banned', () {
      final activeUser = UserModel(
        id: 'user_1',
        fullName: 'Dr. Test',
        email: 'test@medsina.com',
        medicalRole: 'Candidat Résidanat',
        faculty: 'Faculté de Blida',
        tier: SubscriptionTier.residentElite,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 90)),
        token: 'token_123',
        isBanned: false,
        rejectedPaymentsCount: 0,
      );

      expect(activeUser.isSubscriptionActive, isTrue);
      expect(activeUser.daysRemaining, greaterThan(80));

      final bannedUser = activeUser.copyWith(
        isBanned: true,
        banReason: '3 tentatives de paiement avec reçus rejetés.',
        rejectedPaymentsCount: 3,
      );

      expect(bannedUser.isBanned, isTrue);
      expect(bannedUser.isSubscriptionActive, isFalse);
      expect(bannedUser.daysRemaining, equals(0));
      expect(bannedUser.rejectedPaymentsCount, equals(3));
      expect(bannedUser.banReason, contains('3 tentatives'));
    });

    test('UserModel JSON serialization preserves ban and fraud attributes', () {
      final user = UserModel(
        id: 'usr_fraud_1',
        fullName: 'Dr. Suspect',
        email: 'suspect@gmail.com',
        medicalRole: 'Médecin Généraliste',
        faculty: 'Alger',
        tier: SubscriptionTier.free,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 10)),
        token: 'tok_abc',
        isBanned: true,
        banReason: 'Fraude récidiviste',
        rejectedPaymentsCount: 3,
      );

      final jsonMap = user.toJson();
      expect(jsonMap['is_banned'], isTrue);
      expect(jsonMap['ban_reason'], equals('Fraude récidiviste'));
      expect(jsonMap['rejected_payments_count'], equals(3));

      final restored = UserModel.fromJson(jsonMap);
      expect(restored.isBanned, isTrue);
      expect(restored.banReason, equals('Fraude récidiviste'));
      expect(restored.rejectedPaymentsCount, equals(3));
      expect(restored.isSubscriptionActive, isFalse);
    });

    test('AdminUserItem deserializes ban and strike counter fields', () {
      final raw = {
        'id': 'uuid_admin_usr_1',
        'email': 'candidat@test.dz',
        'full_name': 'Dr. Candidat',
        'medical_role': 'Interne',
        'faculty': 'Oran',
        'tier': 'free',
        'status': 'suspended',
        'expires_at': null,
        'is_admin': false,
        'is_banned': true,
        'ban_reason': '3 reçus rejetés consécutifs',
        'rejected_payments_count': 3,
        'created_at': DateTime.now().toIso8601String(),
      };

      final adminUser = AdminUserItem.fromJson(raw);
      expect(adminUser.isBanned, isTrue);
      expect(adminUser.status, equals('suspended'));
      expect(adminUser.rejectedPaymentsCount, equals(3));
      expect(adminUser.banReason, equals('3 reçus rejetés consécutifs'));
    });
  });

  group('Google Drive Archival & Storage Model Tests', () {
    test('PaymentItem deserializes Google Drive archive attributes', () {
      final now = DateTime.now();
      final raw = {
        'id': 'pay_archived_1',
        'user_id': 'user_1',
        'user_email': 'doc@gmail.com',
        'user_name': 'Dr. Hafedh',
        'tier': 'all_access',
        'duration_days': 365,
        'amount': 6500.0,
        'currency': 'DZD',
        'payment_method': 'baridimob',
        'receipt_reference': 'RIP123456789',
        'receipt_url': 'https://qzfssrhhuorljftpdvjm.supabase.co/storage/v1/object/public/receipts/user_1/recu.pdf',
        'receipt_file_name': 'recu.pdf',
        'status': 'approved',
        'admin_notes': 'Validé et archivé',
        'is_archived': true,
        'archive_drive_url': 'https://drive.google.com/file/d/1A2B3C4D5E/view',
        'archive_drive_folder': 'Medsina - Reçus Validés (Archives 30j)',
        'archived_at': now.toIso8601String(),
        'created_at': now.subtract(const Duration(days: 35)).toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final payment = PaymentItem.fromJson(raw);
      expect(payment.isArchived, isTrue);
      expect(payment.archiveDriveUrl, contains('drive.google.com'));
      expect(payment.archiveDriveFolder, equals('Medsina - Reçus Validés (Archives 30j)'));
      expect(payment.archivedAt, isNotNull);
    });

    test('30-Day retention filtering correctly isolates receipts older than 30 days', () {
      final now = DateTime.now();
      final paymentRecent = {
        'id': 'p1',
        'status': 'approved',
        'is_archived': false,
        'created_at': now.subtract(const Duration(days: 15)),
      };
      final paymentEligible = {
        'id': 'p2',
        'status': 'approved',
        'is_archived': false,
        'created_at': now.subtract(const Duration(days: 32)),
      };
      final paymentAlreadyArchived = {
        'id': 'p3',
        'status': 'approved',
        'is_archived': true,
        'created_at': now.subtract(const Duration(days: 40)),
      };

      final allPayments = [paymentRecent, paymentEligible, paymentAlreadyArchived];
      final cutoff = now.subtract(const Duration(days: 30));

      final eligible = allPayments.where((p) {
        final isApproved = p['status'] == 'approved';
        final notArchived = p['is_archived'] == false;
        final createdAt = p['created_at'] as DateTime;
        final isOlderThan30Days = createdAt.isBefore(cutoff);
        return isApproved && notArchived && isOlderThan30Days;
      }).toList();

      expect(eligible.length, equals(1));
      expect(eligible.first['id'], equals('p2'));
    });
  });
}

