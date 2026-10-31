import 'package:flutter/material.dart';
import '../../../../core/services/user_loyalty_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../dialogs/loyalty_rewards_dialog.dart';

class LoyaltyStreakCard extends StatelessWidget {
  const LoyaltyStreakCard({super.key});

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Chef de Clinique Élite':
        return const Color(0xFFEAB308);
      case 'Résident Major':
        return const Color(0xFF8B5CF6);
      case 'Interne Assidu':
        return const Color(0xFF0EA5E9);
      default:
        return AppTheme.primaryTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<UserLoyaltyStats>(
      valueListenable: UserLoyaltyService.instance.statsNotifier,
      builder: (context, stats, _) {
        final levelColor = _getLevelColor(stats.loyaltyLevel);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                levelColor.withValues(alpha: isDark ? 0.18 : 0.08),
                const Color(0xFFF97316).withValues(alpha: isDark ? 0.12 : 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: levelColor.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => LoyaltyRewardsDialog.show(context, stats),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 420;

                    final progressRatio = stats.nextLevelThreshold > 0
                        ? (stats.loyaltyPoints / stats.nextLevelThreshold).clamp(0.0, 1.0)
                        : 1.0;

                    final streakBadge = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF97316).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.streakDays}j d\'affilée',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                    );

                    final ctaButton = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Paliers 🎁',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: levelColor,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: levelColor),
                        ],
                      ),
                    );

                    final levelHeader = Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            stats.loyaltyLevel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: levelColor,
                            ),
                          ),
                        ),
                        Text(
                          '• ${stats.connectionCount}e session',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );

                    final xpProgressSection = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${stats.loyaltyPoints} XP',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Prochain rang: ${stats.nextLevelThreshold} XP',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            minHeight: 5,
                            backgroundColor: levelColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                          ),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              streakBadge,
                              ctaButton,
                            ],
                          ),
                          const SizedBox(height: 8),
                          levelHeader,
                          const SizedBox(height: 8),
                          xpProgressSection,
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            streakBadge,
                            const SizedBox(width: 10),
                            Expanded(child: levelHeader),
                            const SizedBox(width: 8),
                            ctaButton,
                          ],
                        ),
                        const SizedBox(height: 10),
                        xpProgressSection,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

