import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/teacher_space/models/teacher_earnings_model.dart';

void main() {
  group('formatDzd', () {
    test('sépare les milliers par espace insécable simple', () {
      expect(formatDzd(65000), '65 000 DZD');
      expect(formatDzd(1000), '1 000 DZD');
      expect(formatDzd(100), '100 DZD');
      expect(formatDzd(0), '0 DZD');
      expect(formatDzd(1234567), '1 234 567 DZD');
    });

    test('arrondit les décimales', () {
      expect(formatDzd(2999.6), '3 000 DZD');
    });
  });

  group('validatePayoutAmount', () {
    test('refuse un montant nul ou négatif', () {
      expect(validatePayoutAmount(amount: 0, availableBalance: 10000, minAmount: 3000), isNotNull);
      expect(validatePayoutAmount(amount: -5, availableBalance: 10000, minAmount: 3000), isNotNull);
    });

    test('refuse sous le minimum', () {
      expect(validatePayoutAmount(amount: 2999, availableBalance: 10000, minAmount: 3000), contains('minimum'));
    });

    test('refuse au-dessus du solde', () {
      expect(validatePayoutAmount(amount: 10001, availableBalance: 10000, minAmount: 3000), isNotNull);
    });

    test('accepte un montant valide', () {
      expect(validatePayoutAmount(amount: 5000, availableBalance: 10000, minAmount: 3000), isNull);
    });
  });

  group('TeacherEarningsSummary', () {
    final ledger = [
      TeacherLedgerEntry(
        periodMonth: DateTime(2026, 9),
        units: 10,
        grossAttributed: 4000,
        earnings: 4000,
        status: 'accrued',
        availableAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      TeacherLedgerEntry(
        periodMonth: DateTime(2026, 10),
        units: 20,
        grossAttributed: 6000,
        earnings: 6000,
        status: 'accrued',
        availableAt: DateTime.now().add(const Duration(days: 10)),
      ),
      TeacherLedgerEntry(
        periodMonth: DateTime(2026, 8),
        units: 5,
        grossAttributed: 2000,
        earnings: 2000,
        status: 'clawed_back',
      ),
    ];

    final payouts = [
      TeacherPayoutItem(
        id: 'p1',
        amount: 3000,
        method: 'ccp',
        status: 'paid',
        requestedAt: DateTime(2026, 10, 1),
      ),
      TeacherPayoutItem(
        id: 'p2',
        amount: 1500,
        method: 'baridimob',
        status: 'rejected',
        requestedAt: DateTime(2026, 10, 5),
      ),
    ];

    final summary = TeacherEarningsSummary(
      availableBalance: 4000,
      ledger: ledger,
      payouts: payouts,
      settings: const TeacherRevenueSettings(),
    );

    test('calcule les gains en rétention', () {
      expect(summary.pendingBalance, 6000);
    });

    test('calcule le cumul en excluant les reprises', () {
      expect(summary.lifetimeEarnings, 10000);
    });

    test('ne réserve que les retraits non refusés', () {
      expect(summary.reservedPayouts, 3000);
    });
  });

  group('TeacherRevenueSettings', () {
    test('applique 65/35 par défaut', () {
      const settings = TeacherRevenueSettings();
      expect(settings.authorSharePct, 65);
      expect(settings.platformSharePct, 35);
      expect(settings.minPayoutAmount, 3000);
    });

    test('lit la ligne Supabase', () {
      final settings = TeacherRevenueSettings.fromJson({
        'author_share_pct': 70,
        'min_payout_amount': 5000,
        'holdback_days': 14,
        'min_unique_readers': 8,
        'max_author_pool_pct': 25,
        'min_authors_for_cap': 4,
        'is_enabled': true,
      });
      expect(settings.authorSharePct, 70);
      expect(settings.platformSharePct, 30);
      expect(settings.minPayoutAmount, 5000);
      expect(settings.holdbackDays, 14);
    });
  });

  group('TeacherPayoutItem', () {
    test('traduit les libellés', () {
      final payout = TeacherPayoutItem.fromJson({
        'id': 'x',
        'amount': 3000,
        'method': 'baridimob',
        'status': 'requested',
        'requested_at': '2026-10-01T10:00:00Z',
      });
      expect(payout.methodLabel, 'BaridiMob');
      expect(payout.statusLabel, 'En attente');
    });
  });
}
