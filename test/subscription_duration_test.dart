import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/admin/models/admin_models.dart';
import 'package:medsina/features/subscription/models/subscription_duration.dart';

void main() {
  group('SubscriptionDuration Tests', () {
    const allAccess = SubscriptionPlanItem(
      id: 'all_access',
      name: 'Medsina All-Access (VIP)',
      badge: 'RECOMMANDÉ',
      priceYearly: 6500,
      priceMonthly: 1200,
      discountPercent: 30,
    );

    const residentElite = SubscriptionPlanItem(
      id: 'resident_elite',
      name: 'Pass Résident Élite',
      badge: 'SPÉCIAL CONCOURS',
      priceYearly: 5600,
      priceMonthly: 750,
      discountPercent: 20,
    );

    const clinicalPro = SubscriptionPlanItem(
      id: 'clinical_pro',
      name: 'Pass Clinique Pro',
      badge: 'INTERNES & PRATICIENS',
      priceYearly: 5000,
      priceMonthly: 850,
      discountPercent: 15,
    );

    const freePlan = SubscriptionPlanItem(
      id: 'free',
      name: 'Pass Découverte',
      badge: 'GRATUIT',
      priceYearly: 0,
      priceMonthly: 0,
    );

    test('All 5 subscription durations exist with correct days', () {
      expect(SubscriptionDuration.values.length, 5);
      expect(SubscriptionDuration.oneMonth.days, 30);
      expect(SubscriptionDuration.threeMonths.days, 90);
      expect(SubscriptionDuration.sixMonths.days, 180);
      expect(SubscriptionDuration.oneYear.days, 365);
      expect(SubscriptionDuration.twoYears.days, 730);
    });

    test('2 years duration applies 20% discount on 2 years base price', () {
      // 2 * 6500 = 13000 -> -20% = 10400 DZD
      expect(SubscriptionDuration.twoYears.calculatePrice(allAccess), 10400.0);
      expect(SubscriptionDuration.twoYears.calculateSavings(allAccess), 2600.0);

      // 2 * 5600 = 11200 -> -20% = 8960 DZD
      expect(SubscriptionDuration.twoYears.calculatePrice(residentElite), 8960.0);
      expect(SubscriptionDuration.twoYears.calculateSavings(residentElite), 2240.0);

      // 2 * 5000 = 10000 -> -20% = 8000 DZD
      expect(SubscriptionDuration.twoYears.calculatePrice(clinicalPro), 8000.0);
      expect(SubscriptionDuration.twoYears.calculateSavings(clinicalPro), 2000.0);
    });

    test('1 year duration uses exact yearly price from database', () {
      expect(SubscriptionDuration.oneYear.calculatePrice(allAccess), 6500.0);
      expect(SubscriptionDuration.oneYear.calculatePrice(residentElite), 5600.0);
      expect(SubscriptionDuration.oneYear.calculatePrice(clinicalPro), 5000.0);
    });

    test('1 month duration uses exact monthly price from database', () {
      expect(SubscriptionDuration.oneMonth.calculatePrice(allAccess), 1200.0);
      expect(SubscriptionDuration.oneMonth.calculatePrice(residentElite), 750.0);
      expect(SubscriptionDuration.oneMonth.calculatePrice(clinicalPro), 850.0);
    });

    test('Free plan is always 0 DZD across all durations', () {
      for (final duration in SubscriptionDuration.values) {
        expect(duration.calculatePrice(freePlan), 0.0);
        expect(duration.calculateSavings(freePlan), 0.0);
      }
    });

    test('SubscriptionDuration fromDays and formatDays work correctly', () {
      expect(SubscriptionDuration.fromDays(30), SubscriptionDuration.oneMonth);
      expect(SubscriptionDuration.fromDays(90), SubscriptionDuration.threeMonths);
      expect(SubscriptionDuration.fromDays(180), SubscriptionDuration.sixMonths);
      expect(SubscriptionDuration.fromDays(365), SubscriptionDuration.oneYear);
      expect(SubscriptionDuration.fromDays(730), SubscriptionDuration.twoYears);

      expect(SubscriptionDuration.formatDays(30), '1 mois (30 jours)');
      expect(SubscriptionDuration.formatDays(90), '3 mois (90 jours)');
      expect(SubscriptionDuration.formatDays(180), '6 mois (180 jours)');
      expect(SubscriptionDuration.formatDays(365), '1 an (365 jours)');
      expect(SubscriptionDuration.formatDays(730), contains('-20%'));
    });
  });
}
