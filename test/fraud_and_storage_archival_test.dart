import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/core/constants/app_constants.dart';
import 'package:medsina/features/auth/models/user_model.dart';

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
  });

  group('Google Drive Archival & Storage Model Tests', () {
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

