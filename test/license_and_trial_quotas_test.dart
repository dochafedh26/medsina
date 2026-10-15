import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/core/constants/app_constants.dart';
import 'package:medsina/core/services/free_trial_quota_service.dart';
import 'package:medsina/core/utils/license_key_formatter.dart';
import 'package:medsina/features/auth/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VIP License Key Formatter Tests', () {
    test('generateKey creates valid MSN27 Windows-style license keys', () {
      final key = LicenseKeyFormatter.generateKey();
      expect(key.startsWith('MSN27-'), isTrue);
      expect(key.length, equals(29)); // 5 blocks of 5 chars + 4 hyphens = 29 chars

      final regex = RegExp(r'^MSN27-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$');
      expect(regex.hasMatch(key), isTrue);

      // Verify no ambiguous characters (0, O, 1, I)
      expect(key.contains('0'), isFalse);
      expect(key.contains('O'), isFalse);
      expect(key.contains('1'), isFalse);
      expect(key.contains('I'), isFalse);
    });

    test('generateKey generates distinct keys', () {
      final key1 = LicenseKeyFormatter.generateKey();
      final key2 = LicenseKeyFormatter.generateKey();
      expect(key1, isNot(equals(key2)));
    });

    test('format formats unhyphenated string cleanly', () {
      final formatted = LicenseKeyFormatter.format('msn27abcde12345');
      expect(formatted.startsWith('MSN27-ABCDE-'), isTrue);
    });
  });

  group('Free Trial Pass Découverte Quota & Gating Tests', () {
    late UserModel freeUser;
    late UserModel vipUser;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      freeUser = UserModel(
        id: 'test_free_user_1',
        fullName: 'Dr. Test Découverte',
        email: 'test@decouverte.dz',
        medicalRole: 'Médecin Généraliste',
        faculty: 'Faculté de Blida',
        tier: SubscriptionTier.free,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 30)),
        token: 'token_free',
      );

      vipUser = UserModel(
        id: 'test_vip_user_1',
        fullName: 'Dr. Test VIP',
        email: 'vip@medsina.dz',
        medicalRole: 'Médecin Résident',
        faculty: 'Faculté d\'Alger',
        tier: SubscriptionTier.allAccess,
        subscriptionExpiry: DateTime.now().add(const Duration(days: 365)),
        token: 'token_vip',
      );
    });

    test('Pass Découverte course unlocking allows only first 2 courses of 2 chosen modules', () async {
      final quotaService = FreeTrialQuotaService.instance;
      await quotaService.selectFreeModules('test_free_user_1', ['Cardiologie', 'Pédiatrie']);

      expect(quotaService.selectedFreeModules.length, equals(2));
      expect(quotaService.selectedFreeModules, contains('Cardiologie'));
      expect(quotaService.selectedFreeModules, contains('Pédiatrie'));

      // In chosen modules: courses index 0 and 1 are unlocked
      expect(quotaService.isCourseUnlocked(freeUser, 'Cardiologie', 0), isTrue);
      expect(quotaService.isCourseUnlocked(freeUser, 'Cardiologie', 1), isTrue);
      // Course index >= 2 in chosen module is LOCKED
      expect(quotaService.isCourseUnlocked(freeUser, 'Cardiologie', 2), isFalse);
      expect(quotaService.isCourseUnlocked(freeUser, 'Cardiologie', 5), isFalse);

      // In non-chosen modules: ALL courses are LOCKED for free user
      expect(quotaService.isCourseUnlocked(freeUser, 'Neurologie', 0), isFalse);
      expect(quotaService.isCourseUnlocked(freeUser, 'Pneumologie', 1), isFalse);

      // VIP user has ALL courses unlocked everywhere
      expect(quotaService.isCourseUnlocked(vipUser, 'Neurologie', 15), isTrue);
      expect(quotaService.isCourseUnlocked(vipUser, 'Cardiologie', 99), isTrue);
    });

    test('Quota limits: Exactly 1 QCM session, 1 prescription audit, 1 lab analysis, 1 copilot query', () async {
      final quotaService = FreeTrialQuotaService.instance;
      await quotaService.loadQuotas('test_free_user_quotas');

      // 1. QCM Revision Session Quota (1 allowed)
      expect(quotaService.canStartQcmSession(freeUser), isTrue);
      await quotaService.consumeQcmSession(freeUser);
      expect(quotaService.canStartQcmSession(freeUser), isFalse);
      // VIP is never blocked
      expect(quotaService.canStartQcmSession(vipUser), isTrue);

      // 2. Prescription Analysis Quota (1 allowed)
      expect(quotaService.canAnalyzePrescription(freeUser), isTrue);
      await quotaService.consumePrescriptionAnalysis(freeUser);
      expect(quotaService.canAnalyzePrescription(freeUser), isFalse);
      expect(quotaService.canAnalyzePrescription(vipUser), isTrue);

      // 3. Lab Analysis Quota (1 allowed)
      expect(quotaService.canAnalyzeLab(freeUser), isTrue);
      await quotaService.consumeLabAnalysis(freeUser);
      expect(quotaService.canAnalyzeLab(freeUser), isFalse);
      expect(quotaService.canAnalyzeLab(vipUser), isTrue);

      // 4. MedsinaPilot Copilot Quota (1 allowed)
      expect(quotaService.canUseCopilot(freeUser), isTrue);
      await quotaService.consumeCopilotQuery(freeUser);
      expect(quotaService.canUseCopilot(freeUser), isFalse);
      expect(quotaService.canUseCopilot(vipUser), isTrue);
    });
  });
}
