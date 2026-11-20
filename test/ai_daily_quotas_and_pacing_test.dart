import 'package:flutter_test/flutter_test.dart';
import 'package:medsina/features/subscription/models/ai_quota_pack.dart';
import 'package:medsina/core/services/ai_quota_service.dart';

void main() {
  group('AI Quota Packs & Monetization Tests', () {
    test('All 3 AI Quota Booster packs exist with correct credit and price tiers', () {
      final packs = AiQuotaPack.availablePacks;
      expect(packs.length, equals(3));

      final eco = packs.firstWhere((p) => p.id == 'pack_50');
      expect(eco.credits, equals(50));
      expect(eco.priceDzd, equals(500.0));

      final pro = packs.firstWhere((p) => p.id == 'pack_150');
      expect(pro.credits, equals(150));
      expect(pro.priceDzd, equals(1200.0));
      expect(pro.isPopular, isTrue);

      final max = packs.firstWhere((p) => p.id == 'pack_500');
      expect(max.credits, equals(500));
      expect(max.priceDzd, equals(3000.0));
      expect(max.discountBadge, contains('-40%'));
    });

    test('AiQuotaConsumeResult holds accurate remaining metrics', () {
      const res = AiQuotaConsumeResult(
        allowed: true,
        dailyRemaining: 34,
        dailyLimit: 35,
        dailyUsed: 1,
        bonusRemaining: 150,
        consumedFrom: 'daily',
      );

      expect(res.allowed, isTrue);
      expect(res.dailyRemaining, equals(34));
      expect(res.bonusRemaining, equals(150));
      expect(res.consumedFrom, equals('daily'));
    });
  });
}

