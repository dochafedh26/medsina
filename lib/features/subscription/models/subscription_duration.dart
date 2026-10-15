import '../../admin/models/admin_models.dart';

/// Available subscription durations for Medsina plans.
enum SubscriptionDuration {
  oneMonth(days: 30, label: '1 Mois', shortLabel: '1 mois', discountPercent: 0),
  threeMonths(days: 90, label: '3 Mois', shortLabel: '3 mois', discountPercent: 10),
  sixMonths(days: 180, label: '6 Mois', shortLabel: '6 mois', discountPercent: 25),
  oneYear(days: 365, label: '1 An', shortLabel: '1 an', discountPercent: 0, badge: 'POPULAIRE'),
  twoYears(days: 730, label: '2 Ans', shortLabel: '2 ans', discountPercent: 20, badge: '-20% RÉDUCTION');

  final int days;
  final String label;
  final String shortLabel;
  final int discountPercent;
  final String? badge;

  const SubscriptionDuration({
    required this.days,
    required this.label,
    required this.shortLabel,
    required this.discountPercent,
    this.badge,
  });

  /// Computes the exact price in DZD based on the plan's configuration in Supabase.
  double calculatePrice(SubscriptionPlanItem plan) {
    if (plan.id == 'free') return 0;

    switch (this) {
      case SubscriptionDuration.oneMonth:
        return plan.priceMonthly > 0 ? plan.priceMonthly : (plan.priceYearly / 12).roundToDouble();
      case SubscriptionDuration.threeMonths:
        final base = plan.priceMonthly > 0 ? plan.priceMonthly * 3 : plan.priceYearly * 0.35;
        return ((base * 0.90) / 50).round() * 50.0;
      case SubscriptionDuration.sixMonths:
        final base = plan.priceYearly > 0 ? plan.priceYearly * 0.70 : plan.priceMonthly * 6 * 0.75;
        return ((base) / 50).round() * 50.0;
      case SubscriptionDuration.oneYear:
        return plan.priceYearly;
      case SubscriptionDuration.twoYears:
        // 20% discount on 2 full years
        final baseTwoYears = plan.priceYearly * 2;
        return (baseTwoYears * 0.80).roundToDouble();
    }
  }

  /// Calculates the savings in DZD for user awareness.
  double calculateSavings(SubscriptionPlanItem plan) {
    if (plan.id == 'free') return 0;
    switch (this) {
      case SubscriptionDuration.oneMonth:
        return 0;
      case SubscriptionDuration.threeMonths:
        final normal = (plan.priceMonthly > 0 ? plan.priceMonthly : plan.priceYearly / 12) * 3;
        final current = calculatePrice(plan);
        final diff = normal - current;
        return diff > 0 ? diff : 0;
      case SubscriptionDuration.sixMonths:
        final normal = (plan.priceMonthly > 0 ? plan.priceMonthly : plan.priceYearly / 12) * 6;
        final current = calculatePrice(plan);
        final diff = normal - current;
        return diff > 0 ? diff : 0;
      case SubscriptionDuration.oneYear:
        final normal = (plan.priceMonthly > 0 ? plan.priceMonthly : plan.priceYearly / 12) * 12;
        final current = calculatePrice(plan);
        final diff = normal - current;
        return diff > 0 ? diff : 0;
      case SubscriptionDuration.twoYears:
        // Compare with 2 separate 1-year renewals
        final normal = plan.priceYearly * 2;
        final current = calculatePrice(plan);
        final diff = normal - current;
        return diff > 0 ? diff : 0;
    }
  }

  /// Formatted duration label with human-readable string.
  static String formatDays(int days) {
    if (days <= 45) return '1 mois (30 jours)';
    if (days <= 120) return '3 mois (90 jours)';
    if (days <= 240) return '6 mois (180 jours)';
    if (days <= 500) return '1 an (365 jours)';
    if (days <= 900) return '2 ans (730 jours - Réduction -20%)';
    return '$days jours';
  }

  static SubscriptionDuration fromDays(int days) {
    if (days <= 45) return SubscriptionDuration.oneMonth;
    if (days <= 120) return SubscriptionDuration.threeMonths;
    if (days <= 240) return SubscriptionDuration.sixMonths;
    if (days <= 500) return SubscriptionDuration.oneYear;
    return SubscriptionDuration.twoYears;
  }
}

